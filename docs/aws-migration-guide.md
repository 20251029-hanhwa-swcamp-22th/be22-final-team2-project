# SalesBoost AWS 마이그레이션 가이드

> **대상 독자**: 인프라 담당자(정진호)
> **전제**: 현재 k3s + ghcr.io + ArgoCD 기반 파이프라인을 유지하면서, 프로덕션을 AWS 로 이전.
> **원칙**: 무중단. 병행 운영 → 트래픽 컷오버 → 구 인프라 축소 순서.

---

## 0. 목표 아키텍처

```
                      Route 53 (Hosted Zone: salesboost.kr)
                                │
        ┌───────────────────────┴────────────────────────┐
        │                                                │
 app.salesboost.kr                              api.salesboost.kr
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
                        cdn.salesboost.kr (옵션)

                              ▼ (EKS NAT Gateway 고정 EIP)
                         Internet
                              ▼ (SG: MariaDB 3306 ← EIP/32 only)
                      MariaDB 11 (Linux @ playdata4.iptime.org:3306)
                        TLS(require_secure_transport) + 전용 app 계정
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

### 1-2. 도메인
- [ ] Route 53 호스팅 영역 생성 (`salesboost.kr`)
- [ ] 외부 도메인 이전 or NS 레코드 위임
- [ ] 가드: 이전 DNS 레코드 그대로 copy, TTL 300s → 당일 60s 하향

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
| DB(MariaDB 11) | playdata4.iptime.org | 유지 (외부 접근 허용 + TLS) |
| DB 백업 | 수동 | `mariabackup --incremental` 크론 추가 |
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
#   Alternate domain: cdn.salesboost.kr
#   ACM 인증서: us-east-1 에서 발급
# → S3 버킷 정책 자동 추가 (OAC sid)
```

`S3FileService` 반환 URL:
```java
return "https://cdn.salesboost.kr/" + key;
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

### 3-2. AWS Load Balancer Controller 설치

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

`kustomization.yaml`:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: team2
resources:
  - ../../base
patches:
  - path: ingress-alb.yaml        # NodePort → ALB 로 교체
  - path: remove-mariadb.yaml     # StatefulSet 삭제 ($patch: delete)
  - path: remove-aws-creds.yaml   # env 에서 access key 제거 (IRSA)
  - path: sa-auth.yaml            # serviceAccountName 주입
  - path: sa-master.yaml
```

`ingress-alb.yaml`:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: team2-ingress
  namespace: team2
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:ap-northeast-2:<ACCOUNT>:certificate/<UUID>
spec:
  rules:
    - host: api.salesboost.kr
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend: { service: { name: gateway, port: { number: 8010 } } }
          - path: /.well-known
            pathType: Prefix
            backend: { service: { name: gateway, port: { number: 8010 } } }
```

> 프론트 Pod 는 EKS 에서 **삭제**. Phase D 에서 S3+CloudFront 로 옮김.

---

## 4. Phase C — DB 외부 연결 (2일)

**핵심 결정**: RDS 로 옮기지 않음. 운영 중인 Linux 머신을 EKS 에서 접근하도록 네트워크만 뚫기.

### 4-1. Linux DB 쪽 설정

`/etc/my.cnf.d/server.cnf` (MariaDB):
```ini
[mariadbd]
bind-address = 0.0.0.0
require_secure_transport = ON
ssl-cert = /etc/mysql/ssl/server-cert.pem
ssl-key  = /etc/mysql/ssl/server-key.pem
ssl-ca   = /etc/mysql/ssl/ca-cert.pem
```

TLS 자체서명 인증서 생성 (or Let's Encrypt):
```bash
# MariaDB 공식 가이드 참고. 요지는 ca/server-cert/server-key 3쌍.
openssl genrsa 2048 > ca-key.pem
openssl req -new -x509 -nodes -days 3650 -key ca-key.pem > ca-cert.pem
openssl req -newkey rsa:2048 -days 3650 -nodes -keyout server-key.pem > server-req.pem
openssl x509 -req -in server-req.pem -days 3650 -CA ca-cert.pem -CAkey ca-key.pem -set_serial 01 > server-cert.pem
```

전용 계정:
```sql
CREATE USER 'team2_app'@'%' IDENTIFIED BY '<랜덤32자>' REQUIRE SSL;
GRANT ALL PRIVILEGES ON team2_auth.*     TO 'team2_app'@'%';
GRANT ALL PRIVILEGES ON team2_master.*   TO 'team2_app'@'%';
GRANT ALL PRIVILEGES ON team2_activity.* TO 'team2_app'@'%';
GRANT ALL PRIVILEGES ON team2_docs.*     TO 'team2_app'@'%';
FLUSH PRIVILEGES;
```

### 4-2. 방화벽 — EKS NAT EIP 만 허용

EKS NAT Gateway 의 EIP 확인:
```bash
aws ec2 describe-nat-gateways --region ap-northeast-2 \
  --query 'NatGateways[*].NatGatewayAddresses[0].PublicIp' --profile team2
```

Linux 호스트의 iptables/ufw/공유기 포트포워딩에서 MariaDB 3306 을 **EIP/32 한 개 주소만 허용**:
```bash
ufw allow from <EIP> to any port 3306 proto tcp
ufw deny 3306      # 나머지 전부 차단
```

> NAT 이중화(HA) 면 EIP 2개. 홈 공유기는 포트포워딩 원본 IP 필터 제한이 있으므로 필요 시 EC2 bastion + iptables 로 1차 필터링.

### 4-3. EKS Secret

```bash
kubectl -n team2 create secret generic team2-db \
  --from-literal=DB_URL='jdbc:mariadb://playdata4.iptime.org:3306/team2_auth?useSSL=true&requireSSL=true&verifyServerCertificate=true&serverSslCert=/etc/ssl/db/ca-cert.pem' \
  --from-literal=DB_USERNAME=team2_app \
  --from-literal=DB_PASSWORD='<랜덤32자>' \
  --from-literal=DB_DRIVER=org.mariadb.jdbc.Driver
```

CA 인증서는 ConfigMap 으로 마운트:
```bash
kubectl -n team2 create configmap team2-db-ca --from-file=ca-cert.pem=./ca-cert.pem
```

Deployment 에 volumeMount:
```yaml
volumeMounts:
  - name: db-ca
    mountPath: /etc/ssl/db
    readOnly: true
volumes:
  - name: db-ca
    configMap: { name: team2-db-ca }
```

### 4-4. 연결 검증

```bash
kubectl -n team2 run -it --rm mysql-test --image=mariadb:11 --restart=Never -- \
  mariadb -h playdata4.iptime.org -u team2_app -p --ssl-ca=/etc/ssl/db/ca-cert.pem
# \s 로 SSL: Cipher in use... 확인
```

지연 측정 기준: **단건 쿼리 p95 < 50ms**. 초과 시 VPN(Site-to-Site)/DirectConnect 검토.

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

frontend 의 `.env.production`:
```
VITE_API_BASE_URL=https://api.salesboost.kr
```

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
| Alternate domain | `app.salesboost.kr` |
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
      "Name": "app.salesboost.kr",
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
`api.salesboost.kr` → ALB ALIAS 도 동일 패턴.

### 5-5. 백엔드 CORS

각 서비스 `application-prod.yml` (또는 EKS overlay ConfigMap):
```yaml
cors:
  allowed-origins: https://app.salesboost.kr
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
- [ ] `api.salesboost.kr` 로 `curl https://api.salesboost.kr/api/auth/health` 200
- [ ] 브라우저에서 `app.salesboost.kr` SPA 렌더, 로그인, PI 생성, 결재, CI PDF 발송까지 E2E
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
- DB: `mariabackup --incremental` 일 1회 크론 → S3 `team2-db-backup-prod` (Glacier 30d)
- S3 파일: 버저닝으로 실수 복구. Cross-Region Replication 은 선택

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
- [ ] `api.salesboost.kr` A → ALB 로 변경
- [ ] `app.salesboost.kr` A → CloudFront 로 변경
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
