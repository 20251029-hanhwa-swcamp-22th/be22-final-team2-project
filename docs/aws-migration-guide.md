# SalesBoost AWS 마이그레이션 가이드

> **대상 독자**: 인프라 담당자(정진호)
> **전제**: 현재 k3s + ghcr.io + ArgoCD 기반 파이프라인을 유지하면서, 프로덕션을 AWS 로 이전.
> **원칙**: 무중단. 병행 운영 → 트래픽 컷오버 → 구 인프라 축소 순서.
> **도메인**: `salesboost-team2.site` (외부 등록업체 구매 → Route 53 위임).

---

## TL;DR — 최단 경로 (무중단 무시, 처음부터 AWS 만)

처음 한 번에 다 올리는 경우의 최소 순서. 세부는 각 Phase 참고.

```
1. 도메인 NS 를 Route 53 으로 위임         (§1-2)
2. ACM 인증서 2장 발급 (DNS 검증)          (§3-2a)
     - ap-northeast-2: api.salesboost-team2.site
     - us-east-1    : app.salesboost-team2.site, cdn.salesboost-team2.site
3. S3 버킷 2개 + CloudFront 2개 생성       (§2, §5)
     - team2-files-prod    (업로드)
     - team2-frontend-prod (SPA)
4. eksctl 로 EKS 부트스트랩                (§3-1)
5. AWS Load Balancer Controller + IRSA    (§3-2, §3-3)
6. Linux DB 쪽 TLS + 방화벽 EIP 허용        (§4)
7. ArgoCD 설치 + overlays/eks 연결         (§3-5, §3-6)
8. Route 53 A(ALIAS) 3개 추가              (§5-4)
9. 스모크 테스트 → 컷오버                  (§6, §9)
```

소요: 숙련자 1일, 처음이면 3~5일.

---

## 0. 목표 아키텍처

```
                      Route 53 (Hosted Zone: salesboost-team2.site)
                                │
        ┌───────────────────────┴────────────────────────┐
        │                                                │
 app.salesboost-team2.site                              api.salesboost-team2.site
        │                                                │
        ▼ (ALIAS A/AAAA)                                 ▼ (ALIAS A/AAAA)
 CloudFront Distribution                          AWS ALB (ap-northeast-2)
  Origin: S3 (OAC)                                 TLS: ACM (ap-northeast-2)
  Viewer: HTTPS only (ACM us-east-1)               │
  403/404 → /index.html                            │
        │                                          │
        ▼                                          ▼
 S3: team2-frontend-prod                    AWS Load Balancer Controller
  (Block Public Access ON)                         │ (IngressClass: alb)
  Versioning, SSE-S3                               ▼
                                           ┌────────────────────┐
                                           │ EKS (team2-prod)   │
                                           │ ns: team2          │
                                           └────────────────────┘
                                                    │
               ┌────────────────┬────────────────┬──┴────────────┬────────────────┐
               ▼                ▼                ▼               ▼                ▼
           gateway Pod      auth Pod         master Pod     activity Pod    documents Pod
              :8010          :8011            :8012          :8013           :8014
                              │IRSA            │IRSA
                              ▼                ▼
                         S3: team2-files-prod (stamps, logos, attachments)
                              ▲
                              │ CloudFront OAC (읽기 전용 공개 URL)
                              │
                        cdn.salesboost-team2.site (옵션)

                              ▼ (EKS NAT Gateway 고정 EIP)
                         Internet
                              ▼ (DOCKER-USER iptables: 3306 ← EIP/32 only)
                      Linux 호스트 (playdata4.iptime.org:3306)
                              ▼
                      Docker container: team2-mariadb (mariadb:11.4)
                        bind-mount: /srv/mariadb/{data,conf,ssl,initdb,backup}
                        TLS(require_secure_transport) + 전용 app 계정
                        databases: team2_auth / team2_master / team2_activity / team2_documents
```

**변경 요약**
- **프론트**: nginx Pod → S3 + CloudFront 정적 호스팅 (Pod 수 -1, 서빙 RPS 무제한)
- **백엔드**: k3s → EKS (Kustomize overlays 재사용)
- **파일**: 로컬 파일시스템 → S3 (auth/master, IRSA)
- **DB**: k3s StatefulSet → 기존 Linux 머신 유지 (RDS 미채택, 비용/운영 고려)
- **CI/CD**: ghcr.io + ArgoCD Image Updater **그대로 유지** (registry 교체 없음)

---

## 1. 사전 준비 (D-7 이전)

### 1-1. AWS 계정 / IAM
- [ ] 루트 계정 MFA, IAM Identity Center(SSO) 관리자 2명
- [ ] 팀 작업용 IAM User: `team2-deployer` (프로그램 액세스 + MFA)
- [ ] CLI 프로파일: `aws configure --profile team2 --region ap-northeast-2`

### 1-2. 도메인 — `salesboost-team2.site` (외부 등록처 → Route 53 위임)

`.site` TLD 는 AWS Route 53 Registrar 가 취급하지 않는다 (대부분 Namecheap/Porkbun/Hostinger/가비아 구매). **도메인 자체를 이전(transfer)하지 말고, NS 레코드만 Route 53 으로 위임**한다. 더 빠르고 비용도 안 든다.

**1) Route 53 Hosted Zone 생성**
```bash
aws route53 create-hosted-zone \
  --name salesboost-team2.site \
  --caller-reference "team2-init-$(date +%s)" \
  --hosted-zone-config Comment="team2 prod",PrivateZone=false \
  --profile team2

# Hosted Zone ID 와 NS 레코드 4개 확인
aws route53 list-hosted-zones-by-name --dns-name salesboost-team2.site --profile team2
aws route53 get-hosted-zone --id <ZONE_ID> --profile team2 \
  --query 'DelegationSet.NameServers'
# 예시 출력:
# ["ns-1234.awsdns-12.org",
#  "ns-567.awsdns-34.com",
#  "ns-890.awsdns-56.co.uk",
#  "ns-2345.awsdns-78.net"]
```
나오는 NS 4개를 메모.

**2) 등록처 콘솔에서 NS 교체**
구매처마다 위치가 다름. 공통: 도메인 관리 → "Nameservers" / "DNS" / "네임서버" 항목에서 *Custom DNS* 로 바꾸고 위 NS 4개 입력.

| 구매처 | 메뉴 경로 |
|---|---|
| Namecheap | Domain List → Manage → Nameservers → Custom DNS |
| Porkbun | Details → Authoritative Nameservers → Edit |
| Hostinger | Domains → Manage → DNS / Nameservers → Change nameservers |
| 가비아 | My가비아 → 도메인 → 네임서버 설정 |

저장 후 전파 확인 (수 분 ~ 수 시간):
```bash
dig NS salesboost-team2.site +short
# awsdns 4개가 나오면 위임 완료
```

**3) 서브도메인 계획**
| 서브도메인 | 용도 | 타겟 | TLS |
|---|---|---|---|
| `app.salesboost-team2.site` | 프론트(SPA) | CloudFront → S3 | ACM us-east-1 |
| `api.salesboost-team2.site` | 백엔드 API | ALB → EKS | ACM ap-northeast-2 |
| `cdn.salesboost-team2.site` | 사용자 업로드 파일 | CloudFront → S3 | ACM us-east-1 |
| `argocd.salesboost-team2.site` (옵션) | ArgoCD UI | ALB → ArgoCD svc | ACM ap-northeast-2 |

**가드**
- TTL 평소 300s, 컷오버 24h 전 60s 하향 → 컷오버 후 1일 모니터 → 다시 300s
- Route 53 의 NS 레코드를 "수정" 하지 말 것 (등록처에 이미 알려준 값과 어긋나면 도메인이 죽음)

### 1-3. 툴체인
```bash
# 전체 Phase 공통
brew install awscli eksctl kubectl helm       # macOS
# or choco install awscli kubernetes-cli kubernetes-helm   # Windows

aws sts get-caller-identity --profile team2    # 계정 확인
```

### 1-4. 기존 리소스 인벤토리
| 리소스 | 현 위치 | 이전 전략 |
|---|---|---|
| DB(MariaDB 11) | playdata4.iptime.org | **호스트 위 Docker 컨테이너로 운영** (외부 접근 허용 + TLS). §4 참고 |
| DB 백업 | 수동 | `docker exec mariadb-dump` → S3 업로드 크론 (§4-8) |
| JWT 키 (RSA) | k8s Secret `team2-jwt-keys` | EKS Secret 으로 복제 (동일 값) |
| SMTP 계정 | `teamsalesboost@gmail.com` | 그대로 재사용 |
| ghcr.io 이미지 | 현재 사용중 | 그대로 |

---

## 2. Phase A — S3 파일 스토리지 (1~2일, 무중단)

**목적**: auth/master 의 파일 업로드 경로를 S3 로 전환. EKS 이전 이전에 먼저 독립적으로 적용 가능 (현 k3s 에서도 바로 사용).

### 2-1. S3 버킷 생성

```bash
aws s3api create-bucket \
  --bucket team2-files-prod \
  --region ap-northeast-2 \
  --create-bucket-configuration LocationConstraint=ap-northeast-2 \
  --profile team2

# Block Public Access (기본이지만 명시)
aws s3api put-public-access-block \
  --bucket team2-files-prod \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
  --profile team2

# 버저닝 + SSE-S3
aws s3api put-bucket-versioning --bucket team2-files-prod \
  --versioning-configuration Status=Enabled --profile team2
aws s3api put-bucket-encryption --bucket team2-files-prod \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' \
  --profile team2
```

### 2-2. IAM (임시: User Access Key → 이후 IRSA 로 교체)

k3s 단계에서 임시로 사용할 IAM User + Access Key:
```bash
aws iam create-user --user-name team2-s3-app --profile team2
aws iam attach-user-policy \
  --user-name team2-s3-app \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess \
  --profile team2
# 후에 최소권한(bucket 한정)으로 재발급. 아래 3-3 참고.
aws iam create-access-key --user-name team2-s3-app --profile team2
# → AccessKeyId / SecretAccessKey 저장
```

### 2-3. auth 서비스 — 이미 `S3FileService` 존재

`team2-backend-auth/src/main/java/com/team2/auth/command/application/service/S3FileService.java` 가 이미 있음. `application.yml` 에 다음 env 바인딩되어 있으므로 **Secret 만 주입하면 바로 동작**:

```yaml
# application.yml (변경 없음)
cloud:
  aws:
    credentials:
      access-key: ${AWS_ACCESS_KEY:}
      secret-key: ${AWS_SECRET_KEY:}
    region:
      static: ${AWS_REGION:ap-northeast-2}
    s3:
      bucket: ${AWS_S3_BUCKET:team2-bucket}
```

**수정 필요**: `S3FileService.upload()` 의 반환 URL 을 CloudFront 도메인으로 변경 (2-6 후 적용).

### 2-4. master 서비스 — 동일 구조 이식

auth 의 `S3FileService` 를 master 로 복사:
```bash
cp team2-backend-auth/src/main/java/com/team2/auth/command/application/service/S3FileService.java \
   team2-backend-master/src/main/java/com/team2/master/command/application/service/S3FileService.java
# 패키지 경로 com.team2.auth.* → com.team2.master.* 치환
```

`build.gradle` 에 AWS SDK 의존성 추가 (auth 와 동일 버전):
```groovy
implementation platform("software.amazon.awssdk:bom:2.25.0")
implementation "software.amazon.awssdk:s3"
```

`application.yml` 의 `cloud.aws.*` 블록 auth 와 동일하게 복사.

### 2-5. Secret 등록 (현 k3s)

```bash
kubectl -n team2 create secret generic team2-aws \
  --from-literal=AWS_ACCESS_KEY=<KEY> \
  --from-literal=AWS_SECRET_KEY=<SECRET> \
  --from-literal=AWS_REGION=ap-northeast-2 \
  --from-literal=AWS_S3_BUCKET=team2-files-prod
```

`backend-auth.yaml` / `backend-master.yaml` 의 envFrom 에 `team2-aws` 추가.

### 2-6. CloudFront OAC (공개 읽기 URL)

S3 는 Block Public Access 상태이므로 CloudFront OAC 로만 읽기 허용.
```bash
# (콘솔 권장) CloudFront → Create Distribution
#   Origin: S3 (team2-files-prod), Origin Access: OAC 새로 생성
#   Viewer Protocol: Redirect HTTP to HTTPS
#   Alternate domain: cdn.salesboost-team2.site
#   ACM 인증서: us-east-1 에서 발급
# → S3 버킷 정책 자동 추가 (OAC sid)
```

`S3FileService` 반환 URL:
```java
return "https://cdn.salesboost-team2.site/" + key;
```

### 2-7. Presigned URL (옵션, 프라이빗 문서용)
도장/로고처럼 공개해도 되는 건 CloudFront URL, **영업비밀성 첨부(CI/PL 원본)** 는 presigned URL 권장:
```java
try (S3Presigner presigner = S3Presigner.create()) {
    PresignedGetObjectRequest presigned = presigner.presignGetObject(b -> b
        .signatureDuration(Duration.ofMinutes(10))
        .getObjectRequest(r -> r.bucket(bucket).key(key)));
    return presigned.url().toString();
}
```

---

## 3. Phase B — EKS 클러스터 (3~4일)

### 3-0. 사전 점검 (생략하면 1시간 후에 실패한다)

- [ ] 리전: **`ap-northeast-2`** (서울) 고정. CloudFront 인증서만 us-east-1.
- [ ] 서비스 한도: EC2 vCPU 32 이상 (기본 OK), Elastic IP 5 이상, NAT Gateway 5 이상.
  ```bash
  aws service-quotas get-service-quota --service-code ec2 --quota-code L-1216C47A --region ap-northeast-2 --profile team2
  ```
- [ ] **AWS Budgets** 월 $300 알림 1개. (실수로 NAT 트래픽 폭주 시 조기 감지)
- [ ] 로컬에 `eksctl >= 0.180`, `kubectl >= 1.30`, `helm >= 3.14`, `aws-cli >= 2.15`.

### 3-1. VPC + EKS 생성 (`eksctl` — 가장 빠른 부트스트랩)

`eks-cluster.yaml`:
```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: team2-prod
  region: ap-northeast-2
  version: "1.30"

vpc:
  nat:
    gateway: Single          # 비용: NAT 1개 ($32/월 + 데이터)

iam:
  withOIDC: true             # IRSA 필수

managedNodeGroups:
  - name: ng-default
    instanceType: t3.medium  # 2vCPU/4GB, 2~4노드
    minSize: 2
    maxSize: 4
    desiredCapacity: 2
    volumeSize: 30
    privateNetworking: true

addons:
  - name: vpc-cni
  - name: kube-proxy
  - name: coredns
  - name: aws-ebs-csi-driver
```

```bash
eksctl create cluster -f eks-cluster.yaml --profile team2
aws eks update-kubeconfig --name team2-prod --region ap-northeast-2 --profile team2
kubectl get nodes
```

> **Terraform 대안**: 운영이 길어지면 `terraform-aws-modules/eks` 로 전환 권장. 지금은 eksctl 로 충분.

### 3-1a. (Windows 사용자) Bastion EC2 — 선택지 둘

> Windows 에서 `eksctl`/`kubectl`/`helm` 직접 돌려도 됨. 단 IRSA 검증, NAT EIP 추적 같은 운영 작업은 같은 VPC 안의 작은 EC2 가 편하다.

**옵션 A — 로컬 Windows 에서 모두 처리 (간단)**
```bash
# Git Bash 에서
choco install awscli kubernetes-cli kubernetes-helm eksctl
aws configure --profile team2     # access key / region=ap-northeast-2
```

**옵션 B — Bastion EC2 (권장: 권한격리 + 24/7 cron 작업용)**
```bash
# t4g.nano (ARM, $3/월)
aws ec2 run-instances \
  --image-id ami-0c9c942bd7bf113a2 \
  --instance-type t4g.nano \
  --key-name team2-bastion \
  --security-group-ids <SG_ID> \
  --subnet-id <PUBLIC_SUBNET_ID> \
  --associate-public-ip-address \
  --iam-instance-profile Name=team2-bastion-profile \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=team2-bastion}]' \
  --profile team2
# SG: inbound 22 from 사무실 IP/32 only
# IAM: AdministratorAccess 또는 EKS+Route53+ACM+S3 한정
```
SSM Session Manager 쓰면 SSH 키 관리 불필요:
```bash
aws ssm start-session --target i-xxxx --profile team2
```

### 3-2. AWS Load Balancer Controller 설치

### 3-2a. ACM 인증서 발급 (DNS 검증)

ALB/CloudFront 가 사용할 TLS 인증서. **CloudFront 용은 반드시 us-east-1**.

```bash
# 1) ALB 용 (서울)
aws acm request-certificate \
  --domain-name api.salesboost-team2.site \
  --validation-method DNS \
  --region ap-northeast-2 --profile team2
# → CertificateArn 출력. 메모.

# 2) CloudFront 용 (버지니아). SAN 으로 두 호스트 한번에.
aws acm request-certificate \
  --domain-name app.salesboost-team2.site \
  --subject-alternative-names cdn.salesboost-team2.site \
  --validation-method DNS \
  --region us-east-1 --profile team2
```

각 인증서마다 **검증용 CNAME 1개씩** 자동 생성 — Route 53 에 그대로 추가하면 자동 검증 (~5분):
```bash
# 검증 레코드 조회
aws acm describe-certificate --certificate-arn <ARN> --region ap-northeast-2 --profile team2 \
  --query 'Certificate.DomainValidationOptions[0].ResourceRecord'
# {
#   "Name": "_abc123.api.salesboost-team2.site.",
#   "Type": "CNAME",
#   "Value": "_xyz456.acm-validations.aws."
# }

# Route 53 에 UPSERT (편의: aws acm 의 출력을 change-batch JSON 으로 변환)
aws route53 change-resource-record-sets --hosted-zone-id <ZONE_ID> \
  --change-batch '{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{
    "Name":"_abc123.api.salesboost-team2.site.","Type":"CNAME","TTL":300,
    "ResourceRecords":[{"Value":"_xyz456.acm-validations.aws."}]}}]}' \
  --profile team2

# 검증 상태 폴링
aws acm describe-certificate --certificate-arn <ARN> --region ap-northeast-2 --profile team2 \
  --query 'Certificate.Status'
# → "ISSUED" 가 나오면 끝
```

> 한 번에 받기: 위 절차를 ARN 2개에 대해 반복. ACM us-east-1 / ap-northeast-2 두 ARN 메모해두고 §3-6, §5-3 에서 사용.



```bash
# OIDC provider 이미 생성됨 (withOIDC: true)
eksctl create iamserviceaccount \
  --cluster=team2-prod --region=ap-northeast-2 \
  --namespace=kube-system --name=aws-load-balancer-controller \
  --role-name=AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess \
  --approve --profile team2

helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=team2-prod \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

### 3-3. IRSA — auth/master 가 S3 쓰기 (Access Key 제거)

최소권한 IAM 정책:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ObjectRW",
      "Effect": "Allow",
      "Action": ["s3:PutObject","s3:GetObject","s3:DeleteObject"],
      "Resource": "arn:aws:s3:::team2-files-prod/*"
    },
    {
      "Sid": "ListBucket",
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": "arn:aws:s3:::team2-files-prod"
    }
  ]
}
```

```bash
aws iam create-policy --policy-name team2-s3-files-rw \
  --policy-document file://s3-policy.json --profile team2

# auth ServiceAccount → IAM Role 바인딩
eksctl create iamserviceaccount \
  --cluster team2-prod --region ap-northeast-2 \
  --namespace team2 --name backend-auth \
  --attach-policy-arn arn:aws:iam::<ACCOUNT>:policy/team2-s3-files-rw \
  --approve --profile team2

# master ServiceAccount 동일
eksctl create iamserviceaccount \
  --cluster team2-prod --region ap-northeast-2 \
  --namespace team2 --name backend-master \
  --attach-policy-arn arn:aws:iam::<ACCOUNT>:policy/team2-s3-files-rw \
  --approve --profile team2
```

Deployment manifest 수정:
```yaml
spec:
  template:
    spec:
      serviceAccountName: backend-auth   # IRSA 자동 주입
```

`application.yml` 에서 **`cloud.aws.credentials.*` 블록은 EKS 에서만 제거** (overlays/eks 에서 ConfigMap patch). SDK v2 는 환경에 credentials 가 없으면 IRSA(web identity token) → instance profile 순으로 자동 탐색.

### 3-4. cert-manager (선택, 내부 TLS)
ALB 앞단 TLS 는 ACM 으로 해결. 클러스터 내부 TLS 가 필요하면 `cert-manager` 추가. 지금은 생략.

### 3-5. ArgoCD 설치 + 기존 Repo 연결

```bash
kubectl create ns argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
# Image Updater
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/manifests/install.yaml
```

Application CR (기존 `team2-manifest/k8s/argocd-application.yaml` 재사용):
```yaml
spec:
  source:
    repoURL: https://github.com/hanhwa-swcamp-22th-final/team2-manifest
    targetRevision: main
    path: k8s/overlays/eks    # 새 overlay
  destination:
    server: https://kubernetes.default.svc
    namespace: team2
  syncPolicy:
    automated: { prune: true, selfHeal: true }
```

### 3-6. 새 overlay 추가: `k8s/overlays/eks/`

기존 `k8s/overlays/prod` 와 병행 운영. ArgoCD Application 의 `path` 만 바꿔 가르키면 됨.

```bash
mkdir -p team2-manifest/k8s/overlays/eks
```

`team2-manifest/k8s/overlays/eks/kustomization.yaml`:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: team2

resources:
  - ../../base

# 운영 환경 이미지 태그 (Image Updater 가 SHA 로 자동 교체)
images:
  - { name: ghcr.io/hanhwa-swcamp-22th-final/team2-backend-auth,       newTag: latest }
  - { name: ghcr.io/hanhwa-swcamp-22th-final/team2-backend-master,     newTag: latest }
  - { name: ghcr.io/hanhwa-swcamp-22th-final/team2-backend-activity,   newTag: latest }
  - { name: ghcr.io/hanhwa-swcamp-22th-final/team2-backend-documents,  newTag: latest }
  - { name: ghcr.io/hanhwa-swcamp-22th-final/team2-gateway,            newTag: latest }

patches:
  # 1) Ingress 를 nginx → ALB 로 교체 + 호스트 변경
  - path: ingress-alb.yaml
    target: { kind: Ingress, name: team2-ingress }

  # 2) base 의 MariaDB StatefulSet 제거 (외부 Linux DB 사용)
  - path: remove-mariadb.yaml

  # 3) base 의 frontend Deployment/Service/ConfigMap 제거 (S3+CF 로 이전)
  - path: remove-frontend.yaml

  # 4) IRSA 적용 — auth/master 의 ServiceAccount 지정
  - path: sa-backend-auth.yaml
    target: { kind: Deployment, name: backend-auth }
  - path: sa-backend-master.yaml
    target: { kind: Deployment, name: backend-master }

  # 5) ConfigMap 의 DB URL/CORS 를 EKS 값으로 교체
  - path: configmap-eks.yaml
    target: { kind: ConfigMap, name: team2-config }
```

`ingress-alb.yaml` — base 의 nginx Ingress 를 ALB Ingress 로 통째 교체:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: team2-ingress
  namespace: team2
  annotations:
    # nginx 어노테이션 제거 (ALB 가 무시하지만 시각적 정리)
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip                # IP 모드 (Pod 직접)
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:ap-northeast-2:<ACCOUNT>:certificate/<UUID-API>
    alb.ingress.kubernetes.io/healthcheck-path: /actuator/health
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: '15'
    alb.ingress.kubernetes.io/load-balancer-attributes: idle_timeout.timeout_seconds=60
    # PDF 첨부 메일용 — 본문 크기 (ALB 자체 제한은 없으나 클라이언트/타깃 측 일관)
spec:
  ingressClassName: alb
  rules:
    - host: api.salesboost-team2.site
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend: { service: { name: gateway, port: { number: 8010 } } }
          - path: /.well-known/jwks.json
            pathType: ImplementationSpecific
            backend: { service: { name: gateway, port: { number: 8010 } } }
          - path: /actuator/health
            pathType: Prefix
            backend: { service: { name: gateway, port: { number: 8010 } } }
```

`remove-mariadb.yaml`:
```yaml
$patch: delete
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: team2-mariadb
  namespace: team2
---
$patch: delete
apiVersion: v1
kind: Service
metadata:
  name: team2-mariadb
  namespace: team2
```

`remove-frontend.yaml` (frontend 는 S3+CF 로 이전 — Phase D):
```yaml
$patch: delete
apiVersion: apps/v1
kind: Deployment
metadata: { name: frontend, namespace: team2 }
---
$patch: delete
apiVersion: v1
kind: Service
metadata: { name: frontend, namespace: team2 }
---
$patch: delete
apiVersion: v1
kind: ConfigMap
metadata: { name: frontend-nginx-config, namespace: team2 }
```

`sa-backend-auth.yaml`:
```yaml
- op: add
  path: /spec/template/spec/serviceAccountName
  value: backend-auth
```
`sa-backend-master.yaml` 도 동일 (`backend-master`).

`configmap-eks.yaml` — 기존 `base/configmap.yaml` 의 DB URL / CORS / JWKS 만 교체:
```yaml
- op: replace
  path: /data/SPRING_DATASOURCE_URL_AUTH
  value: "jdbc:mariadb://playdata4.iptime.org:3306/team2_auth?useSSL=true&requireSSL=true&verifyServerCertificate=true&serverSslCert=/etc/ssl/db/ca-cert.pem"
- op: replace
  path: /data/SPRING_DATASOURCE_URL_MASTER
  value: "jdbc:mariadb://playdata4.iptime.org:3306/team2_master?useSSL=true&requireSSL=true&verifyServerCertificate=true&serverSslCert=/etc/ssl/db/ca-cert.pem"
- op: replace
  path: /data/SPRING_DATASOURCE_URL_ACTIVITY
  value: "jdbc:mariadb://playdata4.iptime.org:3306/team2_activity?useSSL=true&requireSSL=true&verifyServerCertificate=true&serverSslCert=/etc/ssl/db/ca-cert.pem"
- op: replace
  path: /data/SPRING_DATASOURCE_URL_DOCS
  value: "jdbc:mariadb://playdata4.iptime.org:3306/team2_documents?useSSL=true&requireSSL=true&verifyServerCertificate=true&serverSslCert=/etc/ssl/db/ca-cert.pem"
- op: replace
  path: /data/CORS_ALLOWED_ORIGINS
  value: "https://app.salesboost-team2.site"
```

> base 의 ConfigMap 은 `JWKS_URI: http://backend-auth:8011/.well-known/jwks.json` 처럼 ClusterIP 기반이라 EKS 에서도 그대로 작동. 외부에서 노출할 필요 없음.

> 프론트 Pod 는 EKS 에서 **삭제**. Phase D 에서 S3+CloudFront 로 옮김.

### 3-7. ArgoCD Application 의 path 변경

`team2-manifest/k8s/argocd-application.yaml` 의 `spec.source.path` 를 새 overlay 로:
```yaml
spec:
  source:
    repoURL: https://github.com/hanhwa-swcamp-22th-final/team2-manifest.git
    targetRevision: main
    path: k8s/overlays/eks       # ← prod → eks
```
Image Updater 의 write-back-target 도 동일하게:
```yaml
argocd-image-updater.argoproj.io/write-back-target: kustomization:./k8s/overlays/eks
```

> **컷오버 안전장치**: 한동안 `prod` overlay 도 보존. EKS 전환 후 1주 무사고 시 삭제.

---

## 4. Phase C — DB (Linux 호스트 + Docker MariaDB) (2일)

**핵심 결정**: RDS 로 옮기지 않음. **Linux 호스트(`playdata4`) 위 Docker 컨테이너로 MariaDB 11 운영**, EKS 에서 외부 접근.

**왜 Docker 인가**
- 호스트 OS 오염 없음 (mariadb-server 패키지 미설치)
- 버전 업그레이드는 이미지 태그 교체 한 줄
- `mariabackup` 도 별도 컨테이너로 분리 가능
- 데이터 디렉터리(`/srv/mariadb/data`)만 호스트 bind-mount → 컨테이너 날려도 데이터 보존

### 4-0. 호스트 디렉터리 레이아웃

Linux 호스트(`playdata4`)에서:
```bash
sudo mkdir -p /srv/mariadb/{data,conf,ssl,backup,initdb}
sudo chown -R 999:999 /srv/mariadb/data /srv/mariadb/backup   # mariadb 컨테이너 UID
sudo chmod 700 /srv/mariadb/ssl
```

### 4-1. TLS 자체서명 인증서

```bash
cd /srv/mariadb/ssl
sudo openssl genrsa 2048 > ca-key.pem
sudo openssl req -new -x509 -nodes -days 3650 -key ca-key.pem \
  -subj "/CN=team2-db-ca" > ca-cert.pem
sudo openssl req -newkey rsa:2048 -days 3650 -nodes -keyout server-key.pem \
  -subj "/CN=playdata4.iptime.org" > server-req.pem
sudo openssl x509 -req -in server-req.pem -days 3650 \
  -CA ca-cert.pem -CAkey ca-key.pem -set_serial 01 > server-cert.pem
sudo chown -R 999:999 /srv/mariadb/ssl
sudo chmod 600 /srv/mariadb/ssl/*-key.pem
```
> `ca-cert.pem` 은 EKS 쪽 ConfigMap 으로 들어갈 파일. 별도 위치에 복사해 두기.

### 4-2. MariaDB 설정 파일

`/srv/mariadb/conf/server.cnf`:
```ini
[mariadbd]
bind-address = 0.0.0.0
port = 3306
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
default-time-zone = '+09:00'

# TLS 강제
require_secure_transport = ON
ssl-ca   = /etc/mysql/ssl/ca-cert.pem
ssl-cert = /etc/mysql/ssl/server-cert.pem
ssl-key  = /etc/mysql/ssl/server-key.pem

# 운영 권장
max_connections = 200
innodb_buffer_pool_size = 1G    # 호스트 RAM 의 50~70% 권장
slow_query_log = ON
long_query_time = 1
```

### 4-3. 초기 스키마/계정 (initdb)

`/srv/mariadb/initdb/01-create-databases.sql`:
```sql
CREATE DATABASE IF NOT EXISTS team2_auth      DEFAULT CHARSET utf8mb4;
CREATE DATABASE IF NOT EXISTS team2_master    DEFAULT CHARSET utf8mb4;
CREATE DATABASE IF NOT EXISTS team2_activity  DEFAULT CHARSET utf8mb4;
CREATE DATABASE IF NOT EXISTS team2_documents DEFAULT CHARSET utf8mb4;
```
`/srv/mariadb/initdb/02-create-app-user.sql`:
```sql
CREATE USER IF NOT EXISTS 'team2_app'@'%' IDENTIFIED BY '${TEAM2_APP_PASSWORD}' REQUIRE SSL;
GRANT ALL PRIVILEGES ON team2_auth.*      TO 'team2_app'@'%';
GRANT ALL PRIVILEGES ON team2_master.*    TO 'team2_app'@'%';
GRANT ALL PRIVILEGES ON team2_activity.*  TO 'team2_app'@'%';
GRANT ALL PRIVILEGES ON team2_documents.* TO 'team2_app'@'%';
FLUSH PRIVILEGES;
```
> initdb 스크립트는 **데이터 디렉터리가 비어 있을 때만 1회 실행**된다. 이후 변경은 `docker exec` 로 수동 적용.

### 4-4. docker-compose

`/srv/mariadb/docker-compose.yml`:
```yaml
services:
  mariadb:
    image: mariadb:11.4
    container_name: team2-mariadb
    restart: unless-stopped
    ports:
      - "3306:3306"           # 공유기 포트포워딩 대상
    environment:
      MARIADB_ROOT_PASSWORD: ${ROOT_PASSWORD}
      TEAM2_APP_PASSWORD:    ${APP_PASSWORD}
      TZ: Asia/Seoul
    volumes:
      - ./data:/var/lib/mysql
      - ./conf/server.cnf:/etc/mysql/conf.d/server.cnf:ro
      - ./ssl:/etc/mysql/ssl:ro
      - ./initdb:/docker-entrypoint-initdb.d:ro
      - ./backup:/backup
    command: ["--default-authentication-plugin=mysql_native_password"]
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 30s
      timeout: 5s
      retries: 5
    logging:
      driver: json-file
      options: { max-size: "50m", max-file: "5" }
```
`.env` (같은 디렉터리, 0600):
```
ROOT_PASSWORD=<랜덤32자>
APP_PASSWORD=<랜덤32자>
```

기동:
```bash
cd /srv/mariadb
sudo docker compose up -d
sudo docker compose logs -f mariadb        # 부팅 로그 확인
sudo docker exec -it team2-mariadb mariadb -uroot -p   # 접속 테스트
```

### 4-5. 방화벽 — EKS NAT EIP 만 허용

EKS NAT Gateway 의 EIP 확인:
```bash
aws ec2 describe-nat-gateways --region ap-northeast-2 --profile team2 \
  --query 'NatGateways[?State==`available`].NatGatewayAddresses[0].PublicIp' --output text
```

**중요**: Docker 는 자체 iptables 룰을 만들고 호스트 ufw 를 우회한다. 두 가지 안:

**(a) Docker 의 publish 포트를 호스트 내부 IP 에만 바인드 + 호스트 nginx-stream/iptables 로 외부 노출**
```yaml
ports:
  - "127.0.0.1:3306:3306"     # 컨테이너는 로컬에서만 접근
```
호스트에서 stream-proxy:
```bash
sudo apt install -y nginx libnginx-mod-stream
# /etc/nginx/modules-enabled/stream-mariadb.conf
stream {
  server {
    listen <외부IP>:3306;
    allow <NAT_EIP>/32;
    deny all;
    proxy_pass 127.0.0.1:3306;
  }
}
sudo systemctl reload nginx
```

**(b) Docker 의 `DOCKER-USER` iptables chain 직접 편집** (간단)
```bash
# 3306 인바운드를 NAT EIP 만 허용
sudo iptables -I DOCKER-USER -p tcp --dport 3306 ! -s <NAT_EIP>/32 -j DROP
sudo iptables -I DOCKER-USER -p tcp --dport 3306 -s <NAT_EIP>/32 -j ACCEPT
# 영구화
sudo apt install -y iptables-persistent
sudo netfilter-persistent save
```

홈 공유기 / iptime 단의 포트포워딩 3306 → 호스트 IP 도 추가.

> NAT HA 면 EIP 2개 모두 허용. 추후 NAT EIP 가 바뀌면 둘 다 갱신 필요 — `aws ec2 allocate-address` 로 **고정 EIP 를 NAT 에 명시 할당**해 둘 것.

### 4-6. EKS Secret + CA ConfigMap

`ca-cert.pem` 을 로컬로 가져온 뒤:
```bash
# Secret (DB 접속정보)
kubectl -n team2 create secret generic team2-db \
  --from-literal=DB_USERNAME=team2_app \
  --from-literal=DB_PASSWORD='<APP_PASSWORD>' \
  --from-literal=DB_DRIVER=org.mariadb.jdbc.Driver

# ConfigMap (CA 인증서)
kubectl -n team2 create configmap team2-db-ca \
  --from-file=ca-cert.pem=./ca-cert.pem
```

> DB URL 자체는 §3-6 의 `configmap-eks.yaml` 에서 ConfigMap 으로 주입 (TLS 옵션 포함). 비밀이 아니므로 Secret 이 아닌 ConfigMap 으로 충분.

각 백엔드 Deployment patch (overlay 에 추가) — CA 인증서 마운트:
```yaml
- op: add
  path: /spec/template/spec/volumes
  value:
    - name: db-ca
      configMap: { name: team2-db-ca }
- op: add
  path: /spec/template/spec/containers/0/volumeMounts
  value:
    - name: db-ca
      mountPath: /etc/ssl/db
      readOnly: true
```

### 4-7. 연결 검증

```bash
# EKS 안에서 임시 Pod 로 접속
kubectl -n team2 run -it --rm mysql-test --image=mariadb:11.4 --restart=Never \
  --overrides='{"spec":{"volumes":[{"name":"ca","configMap":{"name":"team2-db-ca"}}],
                "containers":[{"name":"mysql-test","image":"mariadb:11.4","stdin":true,"tty":true,
                  "command":["mariadb","-h","playdata4.iptime.org","-u","team2_app","-p",
                             "--ssl-ca=/ca/ca-cert.pem","--ssl-verify-server-cert"],
                  "volumeMounts":[{"name":"ca","mountPath":"/ca","readOnly":true}]}]}}'
# 접속 후 \s → "SSL: Cipher in use is TLS_AES_..." 확인
```

지연 측정 기준: **단건 쿼리 p95 < 50ms**. 초과 시 VPN(Site-to-Site)/DirectConnect 검토.

### 4-8. 백업 (Docker 친화)

`/srv/mariadb/backup.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
TS=$(date +%Y%m%d-%H%M%S)
docker exec team2-mariadb mariadb-dump \
  -uroot -p"${ROOT_PASSWORD}" --all-databases --single-transaction --routines --events \
  | gzip > /srv/mariadb/backup/dump-${TS}.sql.gz

# 7일 이상 오래된 로컬 파일 정리
find /srv/mariadb/backup -name 'dump-*.sql.gz' -mtime +7 -delete

# S3 업로드 (Glacier 30일 후 자동 전환은 lifecycle 설정)
aws s3 cp /srv/mariadb/backup/dump-${TS}.sql.gz \
  s3://team2-db-backup-prod/dump-${TS}.sql.gz --profile team2
```
크론:
```cron
0 3 * * * /srv/mariadb/backup.sh >> /var/log/team2-db-backup.log 2>&1
```

복원:
```bash
gunzip -c dump-XXXX.sql.gz | docker exec -i team2-mariadb mariadb -uroot -p"$ROOT_PASSWORD"
```

### 4-9. 운영 팁

- **버전 업**: `image: mariadb:11.5` 로 바꾸고 `docker compose up -d`. 데이터는 bind-mount 라 보존.
- **컨테이너 재기동 ≠ 데이터 손실**: `docker compose down` OK. `docker compose down -v` 는 anonymous volume 만 지움 — bind-mount 안전.
- **로그 폭주 방지**: 위 compose 의 `logging` 옵션이 50MB × 5 로 제한.
- **호스트 재부팅**: `restart: unless-stopped` 로 자동 기동. systemd 단위 따로 만들 필요 없음.
- **모니터링**: `docker exec team2-mariadb mariadb-admin -uroot -p... extended-status` 또는 `mysqld_exporter` 컨테이너 추가 후 Prometheus 스크랩.

---

## 5. Phase D — 프론트 S3 + CloudFront (1~2일)

### 5-1. S3 버킷

```bash
aws s3api create-bucket --bucket team2-frontend-prod \
  --region ap-northeast-2 \
  --create-bucket-configuration LocationConstraint=ap-northeast-2 \
  --profile team2
aws s3api put-public-access-block --bucket team2-frontend-prod \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
  --profile team2
```

### 5-2. 빌드 & 업로드

frontend 의 `.env.production` 신규 작성:
```
VITE_API_BASE_URL=https://api.salesboost-team2.site
```

> 현 코드(`team2-frontend/src`)는 axios baseURL 을 상대경로(`/api`)로 보냄. 빌드 산출물이 동일 호스트(`app.salesboost-team2.site`)에서 서빙되므로 CloudFront 에 **API origin 동시 라우팅**을 추가해 동일 출처를 유지하면 CORS/SameSite 문제 자체가 사라진다.
>
> **권장 구성 (동일 출처)**: CloudFront 에 origin 2개를 두고 path 로 분기.
> - `/api/*`, `/.well-known/*` → Origin = ALB (api.salesboost-team2.site, HTTPS)
> - 그 외 → Origin = S3 (team2-frontend-prod, OAC)
>
> 이러면 사용자는 `app.salesboost-team2.site` 만 접근하고 백엔드는 같은 origin 으로 보임. axios 코드 수정 0줄.

```bash
cd team2-frontend
npm ci && npm run build
aws s3 sync ./dist/ s3://team2-frontend-prod/ \
  --delete \
  --cache-control "public,max-age=31536000,immutable" \
  --exclude "index.html" --profile team2
aws s3 cp ./dist/index.html s3://team2-frontend-prod/index.html \
  --cache-control "no-cache,no-store,must-revalidate" \
  --content-type "text/html; charset=utf-8" --profile team2
```

### 5-3. CloudFront Distribution (OAC)

콘솔 기준 파라미터:
| 항목 | 값 |
|---|---|
| Origin domain | `team2-frontend-prod.s3.ap-northeast-2.amazonaws.com` |
| Origin access | **Origin access control (OAC)** — 새로 생성 |
| Viewer protocol policy | Redirect HTTP to HTTPS |
| Allowed methods | GET, HEAD |
| Cache policy | CachingOptimized |
| Price class | Asia, N. America (선택적 절감) |
| Alternate domain | `app.salesboost-team2.site` |
| SSL certificate | **ACM 인증서 us-east-1** (CloudFront 는 반드시 us-east-1) |

**Custom error response (SPA fallback)**:
- 403 → `/index.html`, 200, 0 TTL
- 404 → `/index.html`, 200, 0 TTL

OAC 생성 후 자동으로 S3 버킷 정책에 다음이 추가됨:
```json
{
  "Effect": "Allow",
  "Principal": { "Service": "cloudfront.amazonaws.com" },
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::team2-frontend-prod/*",
  "Condition": { "StringEquals": {
    "AWS:SourceArn": "arn:aws:cloudfront::<ACCOUNT>:distribution/<DIST_ID>"
  }}
}
```

### 5-4. Route 53 ALIAS

```bash
aws route53 change-resource-record-sets \
  --hosted-zone-id <ZONE_ID> \
  --change-batch file://alias.json --profile team2
```
```json
{
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "app.salesboost-team2.site",
      "Type": "A",
      "AliasTarget": {
        "HostedZoneId": "Z2FDTNDATAQYW2",
        "DNSName": "<dist-id>.cloudfront.net",
        "EvaluateTargetHealth": false
      }
    }
  }]
}
```
`api.salesboost-team2.site` → ALB ALIAS 도 동일 패턴.

### 5-5. 백엔드 CORS

각 서비스 `application-prod.yml` (또는 EKS overlay ConfigMap):
```yaml
cors:
  allowed-origins: https://app.salesboost-team2.site
auth:
  cookie:
    secure: true
    same-site: None   # 크로스 도메인 쿠키 (app → api)
```

> `SameSite=None` + `Secure=true` 필수. 없으면 refresh token 쿠키 브라우저가 차단.

### 5-6. 배포 자동화 (GHA)

`team2-frontend/.github/workflows/deploy-s3.yml` (새 파일, 기존 ghcr.io 워크플로우는 삭제):
```yaml
name: Deploy Frontend to S3
on:
  push: { branches: [main] }
jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions: { id-token: write, contents: read }   # OIDC
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::<ACCOUNT>:role/GHA-Frontend-Deploy
          aws-region: ap-northeast-2
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: npm, cache-dependency-path: package-lock.json }
      - run: npm ci && npm run build
      - run: aws s3 sync ./dist/ s3://team2-frontend-prod/ --delete --cache-control "public,max-age=31536000,immutable" --exclude index.html
      - run: aws s3 cp ./dist/index.html s3://team2-frontend-prod/index.html --cache-control "no-cache" --content-type "text/html; charset=utf-8"
      - run: aws cloudfront create-invalidation --distribution-id <DIST_ID> --paths "/index.html"
```

GHA OIDC provider 를 AWS IAM 에 등록하고 `GHA-Frontend-Deploy` role 생성 (키 없는 CI).

---

## 6. Phase E — 병행 운영 & 컷오버 (2~3일)

### 6-1. 병행 체크리스트
- [ ] EKS 에 전체 백엔드 배포 완료, `/actuator/health` 전부 UP
- [ ] `api.salesboost-team2.site` 로 `curl https://api.salesboost-team2.site/api/auth/health` 200
- [ ] 브라우저에서 `app.salesboost-team2.site` SPA 렌더, 로그인, PI 생성, 결재, CI PDF 발송까지 E2E
- [ ] S3 업로드: 사용자 도장 재업로드 → CloudFront URL 접근 확인
- [ ] 기존 `playdata4.iptime.org:8001` 도 **동시에 정상** (구 k3s 유지)

### 6-2. DNS 컷오버
- [ ] Route 53 TTL 60s 하향 (24h 전)
- [ ] 컷오버 시각에 Route 53 에서 기존 A 레코드 → EKS/CloudFront ALIAS 로 교체
- [ ] 모니터링 1시간: 5xx 레이트, 로그인 실패율, ALB target health
- [ ] 이상 시 DNS 1분 내 롤백 (TTL 60s 덕분)

### 6-3. 데이터 정합성
DB 는 그대로라 이전 없음. **중요**: 컷오버 전후로 **write 경합이 없는지** 확인. 현재 k3s 와 EKS 가 **같은 DB 를 바라보면** 한쪽만 서비스하는 게 아니라 **양쪽 모두 커밋 가능**. 점진 트래픽 전환은 OK 지만, Refresh Token 같은 상태는 라우팅 섞이면 꼬일 수 있음.
- 전략: 컷오버 시각에 구 k3s `replicas=0` 로 내리고 EKS 만 남김. 롤백 시 역전.

---

## 7. Phase F — 정리 / 운영

### 7-1. 구 인프라 축소 (컷오버 +7일)
- [ ] k3s Pod scale to 0 (구 manifest overlay `prod` 보존, 재가동 가능)
- [ ] nginx-ingress NodePort 유지 (내부 접근용)
- [ ] 1주 observability 이상 없으면 k3s 종료

### 7-2. 모니터링
- **CloudWatch Container Insights**: EKS 애드온 추가 (CPU/Mem/Network 기본)
- **ALB Access Logs**: S3 로 저장 (`alb.ingress.kubernetes.io/load-balancer-attributes: access_logs.s3.enabled=true,access_logs.s3.bucket=team2-alb-logs`)
- **CloudFront Real-Time Logs**: Kinesis → S3 (필요 시)
- **Prometheus/Grafana**: kube-prometheus-stack Helm 차트. Alertmanager → Slack webhook

### 7-3. 백업 루틴
- DB: §4-8 의 `backup.sh` 일 1회 크론 (`docker exec mariadb-dump → gzip → S3`). 라이프사이클로 30일 후 Glacier 전환
- S3 파일: 버저닝으로 실수 복구. Cross-Region Replication 은 선택
- 호스트 디스크: `/srv/mariadb/data` 가 단일 장애점 — RAID1 또는 주 1회 외부 디스크 rsync 권장

### 7-4. 비용 추정 (월)

| 항목 | 규모 | 대략 |
|---|---|---|
| EKS control plane | 1 cluster | $73 |
| EC2 (t3.medium × 2, On-Demand) | 24/7 | ~$60 |
| NAT Gateway | 1개 + 10GB 데이터 | ~$37 |
| ALB | 1개 | ~$18 |
| S3 (파일+프론트, 10GB) | — | < $1 |
| CloudFront (50GB/월) | — | ~$4 |
| Route 53 호스팅 | 1 zone + 쿼리 | ~$1 |
| ACM | 무료 | $0 |
| CloudWatch 로그 5GB | — | ~$3 |
| **합계** | — | **~$200/월** |

> Spot 인스턴스 도입 시 EC2 -70%. 개발자 수업 환경이면 `ng-default` minSize=1 로 낮춰 ~$150/월 가능.

---

## 8. 롤백 플랜

| 시나리오 | 조치 |
|---|---|
| EKS 배포 실패 | ArgoCD rollback (UI 1-click) |
| ALB 5xx 폭증 | Route 53 을 playdata4 IP 로 다시 가리킴 (TTL 60s) |
| CloudFront 캐싱 문제 | `create-invalidation /*` |
| DB 연결 단절 | Linux 방화벽 EIP 체크 → 실패 시 bastion SSH tunnel 임시 우회 |
| IRSA 권한 오류 | `kubectl describe sa` → role-arn 매핑 확인, `kubectl rollout restart` |

---

## 9. 체크리스트 (컷오버 당일)

**D-1**
- [ ] EKS smoke test 통과 (전 도메인)
- [ ] Route 53 TTL 60s 확인
- [ ] on-call 2명 확보

**D-Day (09:00~11:00 권장)**
- [ ] k3s frontend Pod 로그 아카이브
- [ ] `api.salesboost-team2.site` A → ALB 로 변경
- [ ] `app.salesboost-team2.site` A → CloudFront 로 변경
- [ ] 30분 모니터링 (5xx < 0.1%)
- [ ] k3s 백엔드 `replicas=0` 로 축소
- [ ] 사용자 공지 (미리 발송)

**D+1**
- [ ] 로그인 성공률, 주요 API p95 latency, SMTP 발송 성공률 비교 (전일 대비 ±10% 이내)

**D+7**
- [ ] 구 k3s 자원 반환 (또는 staging 전용으로 보존)
- [ ] 비용 리포트 확인 → 예산 초과 항목 최적화

---

## 10. 참고

- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [IRSA](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [CloudFront OAC](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html)
- [MariaDB TLS 설정](https://mariadb.com/kb/en/securing-connections-for-client-and-server/)
- 기존 내부 문서: [`docs/k8s-전환-및-CICD-전략.md`](./k8s-전환-및-CICD-전략.md), [`team2-manifest/k8s/DEPLOY.md`](../team2-manifest/k8s/DEPLOY.md)

---

## 11. Troubleshooting (자주 막히는 지점)

| 증상 | 원인 후보 | 확인/해결 |
|---|---|---|
| `dig NS salesboost-team2.site` 가 등록처 NS 그대로 | 등록처에서 NS 변경 미저장 또는 전파 중 | 등록처 콘솔 재확인. 최대 24h 기다림. `dig +trace` 로 위임 체인 확인 |
| ACM 상태 `PENDING_VALIDATION` 30분 이상 | 검증 CNAME 이름/값 오타, trailing dot 누락 | Route 53 콘솔에서 레코드 비교. CNAME 끝 `.` 포함 |
| `kubectl get nodes` 가 `Unauthorized` | aws-cli 프로파일/리전 미스매치 | `aws eks update-kubeconfig --name team2-prod --region ap-northeast-2 --profile team2` 재실행 |
| ALB Ingress 가 `ADDRESS` 비어있음 | LB Controller 미설치, IRSA 권한 부족 | `kubectl -n kube-system logs deploy/aws-load-balancer-controller --tail=200` 에서 `AccessDenied` 확인 |
| ALB target health `unhealthy` | `/actuator/health` 503, SG 미허용 | `kubectl exec` 로 직접 curl. ALB SG → Pod SG 인바운드 8010 자동 추가되었는지 확인 |
| `https://app...` 무한 리다이렉트 | CloudFront SSL 정책 + S3 객체 권한 충돌 | 객체 ACL 제거 (BucketOwnerEnforced), OAC 정책만 남김 |
| 새로고침 시 404 | SPA fallback 미설정 | CloudFront → Error pages → 403/404 → 200 + `/index.html` |
| 로그인은 되는데 새 페이지에서 401 | 쿠키 SameSite | 동일 출처 구성으로 변경하거나 `SameSite=None;Secure` 명시 |
| Pod → Linux DB 연결 timeout | NAT EIP 미허용, MariaDB bind-address, Docker iptables 우회 | EIP 확인 후 `DOCKER-USER` chain 에 화이트리스트(§4-5). `docker exec team2-mariadb mariadb -uroot -p` 로 컨테이너 자체는 정상인지 먼저 확인 |
| `Access denied for user 'team2_app'@...` | initdb 가 1회만 도는데 비번 안 맞음 | `docker exec` 로 직접 `ALTER USER 'team2_app'@'%' IDENTIFIED BY '...'` 재설정 |
| TLS handshake fail | CA 인증서 mismatch (호스트 갱신 후 ConfigMap 미갱신) | `team2-db-ca` ConfigMap 재생성 후 백엔드 `rollout restart` |
| `Could not find or load main class` (이미지 새로 안 받음) | imagePullPolicy + 동일 태그 | Image Updater 가 SHA 태그로 갱신하는지 git log 확인 |
| ArgoCD Image Updater 가 git push 실패 | PAT 권한 부족, SSO authorize 안됨 | `kubectl -n argocd logs deploy/argocd-image-updater` |
| Feign 호출 401/403 | `INTERNAL_API_TOKEN` env 미주입 | configmap-eks 에 `INTERNAL_API_TOKEN` 추가, deploy 재시작 |
| S3 업로드 `AccessDenied` (IRSA) | SA 어노테이션 미적용 / Pod 재시작 안 함 | `kubectl describe sa backend-auth -n team2` 로 `eks.amazonaws.com/role-arn` 확인 후 `rollout restart` |
| CloudFront 캐시 안 빠짐 | invalidation 안 함 | `aws cloudfront create-invalidation --distribution-id <ID> --paths "/index.html"` |

### 11-1. 환경별 명령 빠른 참조

```bash
# 클러스터 컨텍스트
kubectl config get-contexts
kubectl config use-context arn:aws:eks:ap-northeast-2:<ACCOUNT>:cluster/team2-prod

# 리소스 한눈에
kubectl get pods,svc,ingress -n team2
kubectl top pods -n team2

# 이벤트 (실패 원인 1차)
kubectl get events -n team2 --sort-by=.lastTimestamp | tail -20

# 특정 Pod 디버깅
kubectl logs -n team2 deploy/backend-auth --tail=200 -f
kubectl exec -it -n team2 deploy/backend-auth -- /bin/sh

# ALB 실제 DNS / target health
aws elbv2 describe-load-balancers --profile team2 \
  --query 'LoadBalancers[?contains(LoadBalancerName,`team2`)].DNSName'
aws elbv2 describe-target-health --target-group-arn <TG_ARN> --profile team2

# NAT EIP (DB 화이트리스트용)
aws ec2 describe-nat-gateways --region ap-northeast-2 --profile team2 \
  --query 'NatGateways[?State==`available`].NatGatewayAddresses[0].PublicIp' --output text
```

---

## 12. 도메인 / 리소스 명칭 표 (단일 출처)

이 문서/매니페스트/스크립트가 모두 같은 값을 참조하도록.

| 항목 | 값 |
|---|---|
| 루트 도메인 | `salesboost-team2.site` |
| 프론트 호스트 | `app.salesboost-team2.site` |
| API 호스트 | `api.salesboost-team2.site` |
| CDN(파일) 호스트 | `cdn.salesboost-team2.site` |
| EKS 클러스터 | `team2-prod` (region: `ap-northeast-2`) |
| K8s namespace | `team2` |
| S3 (프론트) | `team2-frontend-prod` |
| S3 (파일) | `team2-files-prod` |
| S3 (ALB 로그) | `team2-alb-logs` |
| S3 (DB 백업) | `team2-db-backup-prod` |
| IAM Policy | `team2-s3-files-rw` |
| IAM Role (GHA 배포) | `GHA-Frontend-Deploy` |
| ServiceAccount (auth) | `backend-auth` (IRSA) |
| ServiceAccount (master) | `backend-master` (IRSA) |
| Secret (DB) | `team2-db` |
| ConfigMap (DB CA) | `team2-db-ca` |
| Secret (AWS, k3s 임시) | `team2-aws` |
| MariaDB 호스트 | `playdata4.iptime.org:3306` |
| ACM ARN (ALB) | `arn:aws:acm:ap-northeast-2:<ACCOUNT>:certificate/<UUID-API>` |
| ACM ARN (CloudFront) | `arn:aws:acm:us-east-1:<ACCOUNT>:certificate/<UUID-WEB>` |

> 변경 시 이 표만 갱신하고 본문 grep 으로 일괄 치환.
