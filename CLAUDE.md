# SalesBoost / team2 프로젝트

## 구조
모노레포 (`be22-final-team2-project`) + 6 서브모듈:
- `team2-backend-auth` (8011) — 인증, 사용자, **부서/팀/직급**, 회사정보
- `team2-backend-master` (8012) — 거래처, 품목, 바이어, 국가/항구/통화/결제조건
- `team2-backend-activity` (8013) — 영업활동, 컨택, 이메일, 기록패키지
- `team2-backend-documents` (8014) — PI/PO/CI/PL, 생산/출하지시서, 수금, 출하현황
- `team2-gateway` (8010) — Spring Cloud Gateway, 라우팅 + JWT 검증
- `team2-frontend` — Vue 3 Composition API

## 도메인 규칙
- **조직 계층**: `departments → teams → users / clients`. users/clients 는 `team_id` 만 보유, 부서는 `team.department` 역참조로 해소
- 새 테이블/DTO 에 `department_id` 직접 필드 만들지 말 것 (항상 `team_id`)
- JWT claim: `teamId` + `departmentId` (파생) 둘 다 포함. 프론트는 `teamId` 우선

## MSA 경계
- **cross-DB JOIN 금지**. master 가 auth 의 teams/departments 참조하려면 `AuthFeignClient.getTeamsByIds` / `getTeamsByDepartment` 로 enrich
- 내부 전용 엔드포인트: `/api/**/internal/**` — `X-Internal-Token` 필수, gateway 에서 외부 denyAll. Feign 호출자는 `INTERNAL_API_TOKEN` 환경변수 주입
- Feign 실패 시 best-effort: enrich 필드만 null, 본 데이터는 정상 반환

## CQRS + 스택
- 각 백엔드: `command/` (JPA + Spring Data) / `query/` (MyBatis XML + DTO) 분리
- MariaDB, Flyway 아님 — JPA `ddl-auto=update` + `data.sql` init
- HATEOAS (`EntityModel`/`PagedModel`/`CollectionModel`) 적용, 프론트는 `unwrapCollection` 으로 `_embedded` 정규화

## Workflow
- **프론트만 PR 필수** (`team2-frontend`). 백엔드/gateway/루트는 main 직접 푸시 허용
- Pre-push: `./gradlew build -x test` 통과 (테스트는 CQRS 리팩토링 이후 일부 깨짐, 별도 정리 예정)
- 커밋: `type(scope): 설명` 한국어/영어 혼용 OK. Co-Authored-By 포함
- 금지: `--no-verify`, `push --force`, `.env`/RSA 키 커밋, 다른 서브모듈 건드리기

## 위치 / 실행 환경
- 개발: Windows `D:\Users\Documents\be22-final-team2-project` (bash / git-bash)
- **현재 운영 (2026-04-20 ~)**: AWS EKS `team2-prod` (ap-northeast-2) + S3/CloudFront (정적·CDN) + Linux Docker MariaDB (`playdata4.iptime.org:8001` → :3306, TLS verify-full)
  - 사용자 접속: `https://app.salesboost-team2.site/` (Route 53 → CloudFront)
  - 직접 API: `https://api.salesboost-team2.site/api/...` (Route 53 → ALB)
  - EKS kubeconfig context: `eks-team2-prod`
  - ArgoCD: EKS `argocd` ns, Application `salesboost-eks` watch `k8s/overlays/eks`
- **Legacy k3s (2026-04-28 철거 예정)**: Deployment replicas=0 + StatefulSet/PVC 보존 상태로 롤백 창만 유지. 상세 [`docs/d+7-cleanup-checklist.md`](docs/d+7-cleanup-checklist.md).
- 리눅스 운영 박스: playdata4. Docker MariaDB (TLS ON, `/srv/mariadb/backup.sh` 가 매일 3AM S3 업로드)
- 운영 DB 스키마: `team2_auth`, `team2_master`, `team2_activity`, **`team2_docs`** (k3s/EKS 모두 동일, `team2_documents` 아님 — 가이드 문서상 8006/team2_documents 스펙은 실운영 미적용)

## AWS 마이그레이션 아티팩트 (2026-04-20 컷오버)
- 매니페스트: `team2-manifest/k8s/overlays/eks/` (remove-mariadb, remove-frontend, ingress-alb, configmap-eks, sa-backend-*, tls-mount-*)
- ArgoCD app: `team2-manifest/k8s/argocd-application-eks.yaml` (prod 버전은 D+7 까지 보존)
- 프론트 PR: `team2-frontend#469` merge → `.env.production`(`VITE_API_BASE_URL=/api`) + `.github/workflows/deploy-s3.yml`(OIDC `GHA-Frontend-Deploy`)
- 이관 코드: `team2-backend-master` S3FileService + S3Config 추가; `team2-backend-auth` URL prefix 파라미터화 (`cloud.aws.s3.public-url-prefix`, 기본 공란 → k3s 동작 유지)
- 백업 크론: Linux IAM user `team2-db-backup` (write-only), s3://team2-db-backup-prod/<YYYY-MM-DD>/ 매일

## 회고 포인트
- 대규모 리팩토링 시 **백엔드 커밋 푸시 확인** 먼저 (프론트 PR 만 쏘고 백엔드 로컬에 남겨둔 적 있음)
- 스키마 변경 후 **이미지 준비 → DB 마이그레이션 → rollout** 순서. 중간 안전지점(컬럼 유지 단계) 두고 단계별 적용
- **AWS NAT Gateway primary EIP 는 disassociate 불가** — `associate-nat-gateway-address` 로 secondary 추가가 유일한 고정화 경로. Linux 화이트리스트는 두 IP 모두
- **S3 ALB log bucket** 은 BucketOwnerEnforced 에 `s3:x-amz-acl` 조건 넣지 말 것. log prefix 도 Resource 에 포함 필수
- **ALB Controller IAM policy 는 helm chart 버전과 정합** 필요 (v2.8 policy + v3.x controller → DescribeListenerAttributes AccessDenied)
- **컷오버 시 포트 매핑은 구 README 가 아닌 실 iptime 설정 기반**: MariaDB 외부는 8001 → 3306 (docs 의 8006 스펙은 미사용)
- **백업 IAM 은 write-only**. head-object 403 이 정상. 복구/감사는 별도 read principal

## 깃 푸시
- 프론트만 메인 푸시가 금지되어 이슈 템플릿 맞춰서 이슈 발행 후, 코드컨벤션 맞게 브랜치 생성 후 작업한 뒤 PR 템플릿 맞춰 PR까지 작성.
PR만 달랑 올리지말고 이슈도 꼭 선행해서 발행할 것.
- 나머지 레포는 메인에 푸시.
- github actions 붙어 있어서 상위 레포에 포인터 자동 업데이트됨 + 서브모듈 업데이트되면 argoCD image updater가 이미지 자동 최신화