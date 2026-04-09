# SalesBoost k8s 전환 및 CI/CD 전략

## 목차

- [1. 전환 이력](#1-전환-이력)
- [2. 현재 인프라 구성 (k3s)](#2-현재-인프라-구성-k3s)
- [3. CI/CD 파이프라인](#3-cicd-파이프라인)
- [4. k8s 매니페스트 구조](#4-k8s-매니페스트-구조)
- [5. 배포 흐름](#5-배포-흐름)
- [6. AWS EKS 전환 가이드](#6-aws-eks-전환-가이드)

---

## 1. 전환 이력

### Phase 1 — 로컬 Docker Compose (개발)
- 단일 `docker-compose.yml`로 7개 서비스 기동
- 로컬 MariaDB + 볼륨 마운트

### Phase 2 — 리눅스 서버 Docker Compose (스테이징)
- `playdata4.iptime.org:8001` 에서 운영
- GitHub Actions → ghcr.io 이미지 빌드/푸시 → 서버에서 `docker compose pull && up -d`
- nginx 리버스 프록시 + Gateway + 4개 백엔드 + MariaDB

### Phase 3a — k3s + nginx-ingress (현재)
- 2026-04-09 전환 완료
- Docker Compose → k8s(k3s) 무중단 전환
- MariaDB도 StatefulSet + PVC로 이전 (mysqldump 마이그레이션)
- ArgoCD + Image Updater 자동 배포 파이프라인

### Phase 3b — AWS EKS (계획)
- k3s → EKS 전환
- RDS (Aurora MariaDB) + ALB Ingress
- 본 문서 하단 [EKS 전환 가이드](#6-aws-eks-전환-가이드) 참고

---

## 2. 현재 인프라 구성 (k3s)

```
                    [인터넷]
                       │
              외부 8001 포트포워딩 (iptime)
                       │
                       ▼
            ┌─────────────────────┐
            │   k3s (단일 노드)    │
            │   playdata4 서버     │
            │                     │
            │  ┌───────────────┐  │
            │  │ nginx-ingress │  │  ← NodePort :8001
            │  │  controller   │  │
            │  └───────┬───────┘  │
            │          │          │
            │    ┌─────┼─────┐    │
            │    │ Ingress   │    │
            │    │ Rules:    │    │
            │    │ /api/* →  │    │
            │    │  gateway  │    │
            │    │ /* →      │    │
            │    │  frontend │    │
            │    └─────┬─────┘    │
            │          │          │
            │  ┌───────┴────────┐ │
            │  │   Namespace:   │ │
            │  │     team2      │ │
            │  │                │ │
            │  │  frontend      │ │  ← nginx + Vue SPA
            │  │  gateway       │ │  ← Spring Cloud Gateway (JWT/RBAC)
            │  │  backend-auth  │ │  ← JWT 발급 + JWKS + 사용자
            │  │  backend-master│ │  ← 거래처/품목/기준정보
            │  │  backend-      │ │  ← 활동기록/연락처/이메일 로그
            │  │   activity     │ │
            │  │  backend-      │ │  ← PI/PO/CI/PL/결재/수금
            │  │   documents    │ │
            │  │  team2-mariadb │ │  ← StatefulSet + PVC 5Gi
            │  └────────────────┘ │
            │                     │
            │  ┌────────────────┐ │
            │  │   Namespace:   │ │
            │  │     argocd     │ │
            │  │                │ │
            │  │  argocd-server │ │  ← GitOps 컨트롤러
            │  │  image-updater │ │  ← ghcr.io 태그 자동 감지
            │  └────────────────┘ │
            └─────────────────────┘
```

### 서비스 포트

| Service | Pod Port | k8s Service | 외부 접근 |
|---------|----------|-------------|----------|
| frontend | 80 | ClusterIP :80 | Ingress `/` |
| gateway | 8010 | ClusterIP :8010 | Ingress `/api/*` |
| backend-auth | 8011 | ClusterIP :8011 | 내부 전용 |
| backend-master | 8012 | ClusterIP :8012 | 내부 전용 |
| backend-activity | 8013 | ClusterIP :8013 | 내부 전용 |
| backend-documents | 8014 | ClusterIP :8014 | 내부 전용 |
| team2-mariadb | 3306 | ClusterIP :3306 | 내부 전용 |
| nginx-ingress | — | NodePort :8001 | 외부 진입점 |

---

## 3. CI/CD 파이프라인

### 전체 흐름

```
개발자 코드 push (main)
       │
       ▼
┌──────────────────┐
│  GitHub Actions  │  각 서브모듈별 docker-build.yml
│  - gradle build  │
│  - docker build  │
│  - ghcr.io push  │
│    :latest       │
│    :${SHA}       │
└────────┬─────────┘
         │
         ▼  (ghcr.io 레지스트리 폴링, ~2분 간격)
┌──────────────────┐
│  ArgoCD Image    │
│  Updater         │
│  - newest-build  │
│  - ignore:latest │
│  - SHA 태그 감지  │
└────────┬─────────┘
         │  (Kustomize overlay 이미지 태그 자동 갱신)
         ▼
┌──────────────────┐
│  ArgoCD          │
│  - auto sync     │
│  - prune         │
│  - selfHeal      │
└────────┬─────────┘
         │  (kubectl apply — rolling update)
         ▼
┌──────────────────┐
│  k8s Cluster     │
│  Pod 자동 교체    │
│  (무중단 배포)    │
└──────────────────┘
```

### GitHub Actions (각 서브모듈)

```yaml
# .github/workflows/docker-build.yml (6개 서브모듈 동일)
on:
  push:
    branches: [main]

jobs:
  build-and-push:
    steps:
      - docker build & push
        tags:
          - ghcr.io/.../서비스명:latest
          - ghcr.io/.../서비스명:${github.sha}   ← immutable
```

### ArgoCD Image Updater 설정

```yaml
# argocd-application.yaml annotations
argocd-image-updater.argoproj.io/image-list: >-
  auth=ghcr.io/.../team2-backend-auth,
  master=ghcr.io/.../team2-backend-master,
  ...
argocd-image-updater.argoproj.io/auth.update-strategy: newest-build
argocd-image-updater.argoproj.io/auth.ignore-tags: latest
argocd-image-updater.argoproj.io/write-back-method: argocd
```

- **전략**: `newest-build` — 이미지 `createdAt` 기준 최신 태그 자동 선택
- **무시**: `:latest` 태그 (mutable이므로 버전 추적 불가)
- **추적**: `:SHA` 태그 (immutable, rollback 가능)
- **write-back**: `argocd` 모드 — manifest 레포에 `.argocd-source` 파일 자동 생성

### 배포 소요 시간

| 단계 | 시간 |
|------|------|
| GHA 빌드 + 푸시 | ~3-5분 |
| Image Updater 감지 | ~2분 (폴링 주기) |
| ArgoCD sync + rolling update | ~1-2분 |
| **총 (push → 운영 반영)** | **~6-9분** |

### Rollback

```bash
# ArgoCD UI 에서 이전 버전 sync 또는:
argocd app rollback salesboost <revision>

# 또는 직접 이미지 태그 지정:
kubectl -n team2 set image deploy/backend-auth backend-auth=ghcr.io/.../:이전SHA
```

---

## 4. k8s 매니페스트 구조

```
team2-manifest/k8s/
├── argocd-application.yaml          ← ArgoCD Application + Image Updater annotations
├── DEPLOY.md                        ← 배포 가이드 (k3s + nginx-ingress)
│
├── base/                            ← Kustomize base (환경 공통)
│   ├── kustomization.yaml
│   ├── namespace.yaml               ← team2 namespace
│   ├── configmap.yaml               ← DB URL, JWKS, Feign URLs, CORS, SMTP, 프로파일
│   ├── secret.yaml                  ← placeholder (실제 값은 kubectl create secret)
│   ├── mariadb.yaml                 ← StatefulSet + PVC + Service
│   ├── backend-auth.yaml            ← Deployment + Service (JWT volumeMount)
│   ├── backend-master.yaml          ← Deployment + Service
│   ├── backend-activity.yaml        ← Deployment + Service
│   ├── backend-documents.yaml       ← Deployment + Service
│   ├── gateway.yaml                 ← Deployment + Service
│   ├── frontend.yaml                ← Deployment + Service + nginx ConfigMap
│   └── ingress.yaml                 ← nginx-ingress rules
│
└── overlays/
    └── prod/                        ← 운영 오버레이
        └── kustomization.yaml       ← 이미지 태그 오버라이드 + 호스트 패치
```

### ConfigMap 주요 설정

| 키 | 값 | 용도 |
|----|-----|------|
| `SPRING_PROFILES_ACTIVE` | `prod` | 운영 프로파일 |
| `SPRING_JPA_HIBERNATE_DDL_AUTO` | `validate` | 스키마 자동 변경 방지 |
| `JWKS_URI` | `http://backend-auth:8011/.well-known/jwks.json` | JWT 검증 |
| `CORS_ALLOWED_ORIGINS` | `http://playdata4.iptime.org:8001,...` | CORS 허용 |
| `INTERNAL_API_TOKEN` | (Secret) | 서비스 간 내부 호출 인증 |

### Secret 관리

| Secret | 내용 | 생성 방법 |
|--------|------|----------|
| `team2-secrets` | DB password, MAIL credentials, INTERNAL_API_TOKEN | `kubectl create secret` |
| `team2-jwt-keys` | RSA private/public PEM | `kubectl create secret --from-file` |
| `ghcr-secret` | ghcr.io 이미지 pull 인증 | `kubectl create secret docker-registry` |

---

## 5. 배포 흐름

### 일반 배포 (코드 변경)

```
1. 개발자: 백엔드/프론트 코드 push (main)
2. GHA: 자동 빌드 → ghcr.io 푸시 (:latest + :SHA)
3. Image Updater: 새 SHA 감지 (2분 내)
4. ArgoCD: auto sync → rolling update
5. Pod 교체 완료 (무중단)
```

### 설정 변경 (ConfigMap/Secret)

```
1. team2-manifest 레포에서 configmap.yaml 수정 → push
2. ArgoCD: 변경 감지 → auto sync
3. Pod 재시작 필요 시: kubectl -n team2 rollout restart deploy/서비스명
```

### 긴급 롤백

```
1. ArgoCD UI → salesboost → History → 이전 revision Rollback
   또는
2. kubectl -n team2 set image deploy/서비스명 서비스명=ghcr.io/...:이전SHA
```

---

## 6. AWS EKS 전환 가이드

### 전환 개요

```
현재: k3s (단일 리눅스 서버) + MariaDB StatefulSet + nginx-ingress NodePort
목표: EKS (AWS 관리형) + RDS Aurora + ALB Ingress + Route53
```

### 변경 사항 매트릭스

| 컴포넌트 | k3s (현재) | EKS (목표) | 변경 범위 |
|---------|-----------|-----------|---------|
| 클러스터 | k3s 단일 노드 | **EKS (관리형, multi-AZ)** | 인프라 |
| Ingress | nginx-ingress (NodePort :8001) | **AWS ALB Ingress Controller** | annotation 변경 |
| TLS | 없음 (HTTP) | **ACM 인증서 + ALB HTTPS** | Ingress spec |
| 도메인 | `playdata4.iptime.org:8001` | **`salesboost.example.com`** | ConfigMap CORS + Ingress host |
| DB | MariaDB StatefulSet (PVC) | **RDS Aurora MariaDB** | ConfigMap DB URL |
| 스토리지 | local-path (k3s 기본) | **EBS gp3 (StorageClass)** | PVC StorageClass |
| Secret | kubectl 수동 생성 | **AWS Secrets Manager + External Secrets** | 선택 |
| 이미지 레지스트리 | ghcr.io | ghcr.io (유지) 또는 **ECR** | 선택 |
| ArgoCD | 클러스터 내 설치 | 유지 (EKS에 재설치) | 동일 |

### Step-by-Step

#### 1. EKS 클러스터 생성

```bash
# eksctl (가장 간단)
eksctl create cluster \
  --name salesboost \
  --region ap-northeast-2 \
  --version 1.30 \
  --nodegroup-name workers \
  --node-type t3.medium \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 3

# kubeconfig 자동 설정
aws eks update-kubeconfig --name salesboost --region ap-northeast-2
```

#### 2. ALB Ingress Controller 설치

```bash
# AWS Load Balancer Controller
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=salesboost \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# IAM 정책은 별도 (eksctl utils associate-iam-oidc-provider 등)
```

#### 3. Ingress 변경 (nginx → ALB)

```yaml
# k8s/overlays/eks/ingress-patch.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: team2-ingress
  annotations:
    kubernetes.io/ingress.class: alb            # ← nginx → alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:...  # ACM 인증서
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
    alb.ingress.kubernetes.io/ssl-redirect: "443"
spec:
  ingressClassName: alb
  tls:
    - hosts:
        - salesboost.example.com
  rules:
    - host: salesboost.example.com
      # ... 기존 rules 동일
```

#### 4. RDS 전환

```bash
# Aurora MariaDB 생성 (콘솔 또는 Terraform)
# endpoint: salesboost-db.cluster-xxx.ap-northeast-2.rds.amazonaws.com

# ConfigMap 수정 (k8s/overlays/eks/configmap-patch.yaml)
SPRING_DATASOURCE_URL_AUTH: "jdbc:mariadb://salesboost-db.cluster-xxx.rds.amazonaws.com:3306/team2_auth"
# ... 4개 스키마 모두

# MariaDB StatefulSet 제거 (RDS 사용이므로)
# kustomization.yaml 에서 mariadb.yaml 제거
```

#### 5. 데이터 마이그레이션

```bash
# k3s MariaDB → RDS
kubectl -n team2 exec -it team2-mariadb-0 -- \
  mysqldump -u root -p --all-databases > full-dump.sql

mysql -h salesboost-db.cluster-xxx.rds.amazonaws.com \
  -u admin -p < full-dump.sql
```

#### 6. DNS + TLS

```bash
# Route53 에서 salesboost.example.com → ALB DNS CNAME
# ACM 에서 인증서 발급 (자동 검증)
```

#### 7. Kustomize EKS overlay 생성

```
k8s/overlays/
├── prod/              ← 현재 (k3s, playdata4)
└── eks/               ← 신규 (EKS, AWS)
    ├── kustomization.yaml
    ├── ingress-patch.yaml
    └── configmap-patch.yaml
```

```yaml
# k8s/overlays/eks/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
namespace: team2

# MariaDB StatefulSet 제거 (RDS 사용)
patches:
  - target:
      kind: StatefulSet
      name: team2-mariadb
    patch: |
      $patch: delete
      apiVersion: apps/v1
      kind: StatefulSet
      metadata:
        name: team2-mariadb

  # Ingress ALB 패치
  - path: ingress-patch.yaml
  # ConfigMap DB URL 패치
  - path: configmap-patch.yaml

images:
  # ... 동일
```

#### 8. ArgoCD 재설정

```bash
# EKS 클러스터에 ArgoCD 설치 (동일 절차)
# argocd-application.yaml 의 path 를 k8s/overlays/eks 로 변경
```

#### 9. 최종 전환 체크리스트

```
□ EKS 클러스터 생성 + 노드그룹
□ ALB Ingress Controller + IAM
□ ACM 인증서 + Route53
□ RDS Aurora 생성 + 스키마 초기화
□ k3s → RDS 데이터 마이그레이션
□ k8s/overlays/eks/ 오버레이 작성
□ Secret 생성 (EKS 클러스터)
□ JWT RSA 키 Secret 생성
□ ghcr.io pull Secret 생성
□ ArgoCD 설치 + Application 등록
□ Image Updater 설치 + 레지스트리 설정
□ DNS 전환 (salesboost.example.com → ALB)
□ smoke test (JWKS, frontend, API)
□ k3s 정지
```

### 예상 작업량

| 작업 | 시간 |
|------|------|
| EKS 클러스터 + 노드그룹 | ~30분 (eksctl) |
| ALB + ACM + Route53 | ~1시간 |
| RDS 생성 + 마이그레이션 | ~1시간 |
| overlays/eks 작성 | ~30분 |
| ArgoCD + Image Updater | ~30분 |
| 검증 + DNS 전환 | ~30분 |
| **총합** | **~4시간** |

> k3s 매니페스트가 이미 완성돼 있으므로 EKS는 **overlay 추가 + 인프라 프로비저닝**만 하면 됨.
> 애플리케이션 코드 변경 0건.

---

## 부록: 유용한 명령어

```bash
# Pod 상태 확인
kubectl -n team2 get pods -o wide

# 특정 서비스 로그
kubectl -n team2 logs deploy/backend-auth --tail=50 -f

# Pod 재시작 (설정 변경 반영)
kubectl -n team2 rollout restart deploy/backend-auth

# ArgoCD 상태
argocd app get salesboost

# Image Updater 로그
kubectl -n argocd logs deploy/argocd-image-updater --tail=20

# 전체 리소스 현황
kubectl -n team2 get all
```
