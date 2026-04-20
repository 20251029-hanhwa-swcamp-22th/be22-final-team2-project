# AWS 컷오버 D+7 정리 체크리스트

**컷오버 완료일**: 2026-04-20
**D+7 만료**: **2026-04-28**

D+7 이전까지 아래 리소스 **절대 삭제 금지**. 컷오버 이후 운영에서 예기치 못한 문제 발견 시 k3s 경로로 즉시 롤백할 수 있도록 보존한다.

---

## 롤백 보험 (D+7 까지 건드리지 말 것)

| 대상 | 상태 | 손대면 안 되는 이유 |
|---|---|---|
| `team2-manifest/k8s/argocd-application.yaml` (prod) | git 에 존재 | k3s ArgoCD Application 이 이 매니페스트를 watch 중 |
| `team2-manifest/k8s/overlays/prod/` | git 에 존재 | 위 Application 의 path. 지우면 OutOfSync 에러 |
| k3s `team2-mariadb` StatefulSet + PVC (5Gi BOUND) | 보존 중 | 프리 컷오버 데이터가 PVC 안에 그대로. **지우면 영구 손실** |
| k3s 5개 Deploy (auth/master/activity/documents/gateway) | replicas=0 | 롤백 = scale 다시 올리기. 지우면 재배포 필요 |
| k3s ArgoCD salesboost Application | auto-sync OFF, 수동 모드 | selfHeal 재가동 방지 상태 유지 |
| `/srv/mariadb/backup/pre-migrate-2026-04-20.sql.gz` | 27.8KB, Linux 로컬 | 덤프 백업. 완전 롤백 시 `zcat ... | docker exec -i team2-mariadb mariadb -uroot -p...` 한 줄 |

## 지금(D+0~D+6) 진행해도 되는 항목

| 작업 | 리스크 | 비고 |
|---|---|---|
| `team2-frontend/.github/workflows/docker-build.yml` 삭제 | 낮음 | GHCR 이미지 빌드 워크플로. S3+CF 로 대체됐으니 매 push 마다 빌드 낭비. 프론트 PR 요 것 하나만 올리면 됨 |
| GHCR 기존 team2-frontend 이미지 청소 | 매우 낮음 | 최신 N개만 남기고 정리. 스토리지 절약 |
| 모니터링 설정 추가 (CloudWatch alarm, Budgets alert) | 낮음 | 오히려 권장 |

## D+7 (2026-04-28) 도래 시 실행

**프론트(이슈→브랜치→PR)**:
- `team2-frontend/.github/workflows/docker-build.yml` 정리 (위 "지금도 됨" 에서 안 했다면 여기서)

**루트/매니페스트(직접 main 푸시 OK)**:
- `team2-manifest` 레포: `k8s/argocd-application.yaml` 삭제 커밋
- `team2-manifest` 레포: `k8s/overlays/prod/` 디렉터리 삭제 커밋
- k3s 에서 `kubectl -n argocd delete application salesboost` (Application CR 제거)
- k3s 에서 `kubectl -n team2 delete statefulset team2-mariadb` (PVC 는 `kubectl delete pvc` 로 별도)
- k3s 에서 `kubectl -n team2 delete deploy backend-auth backend-master backend-activity backend-documents gateway frontend` (Deployment 일괄)
- ArgoCD prod Application 이미 지웠으면 ConfigMap/Secret 등도 kustomize 없이 바로 정리

**비용 방어 (선택)**:
- AWS Budgets 월별 알람 추가 (예: $100 초과 시 이메일)
- CloudWatch dashboard 간단한 것 (EKS CPU/메모리, ALB 5xx, CloudFront 4xx)

## D+14 이후 정리 (더 뒤에 할 수 있는 것)

- k3s 클러스터 자체 중지/제거 결정 (playdata4 Linux 박스에 더 이상 k3s 안 돌릴 거면)
- iptime 라우터 포트 포워딩 정리 (현재 8001 → 3306 MariaDB 만 유지하면 됨)
- 루트 레포 `docker-compose-dev.yml`, `docs/deployment-plan.md` 등 legacy 문서 노후 정리

## 최종 운영 상태 요약 (2026-04-21 현재)

```
User → Route53 (salesboost-team2.site)
         ├─ app → CloudFront E1NUT5BB6DLB2G → S3 team2-frontend-prod (SPA) + ALB (/api/*, /.well-known/*)
         ├─ cdn → CloudFront E3KYUTS0POZBJ6 → S3 team2-files-prod (첨부파일)
         └─ api → ALB (ap-northeast-2) → EKS team2-prod Ingress → gateway → 4 백엔드 Pod

Backend → (NAT EIP 고정) → playdata4.iptime.org:8001 → Linux host:3306 → Docker MariaDB 11.8 (TLS verify-full)

S3:
  team2-frontend-prod (SPA)        OAC + BPA + SSE-AES256 + Versioning
  team2-files-prod (첨부)           OAC + BPA + SSE-AES256 + Versioning
  team2-alb-logs (ALB access logs)  BPA + SSE-AES256
  team2-db-backup-prod (DB dump)    BPA + SSE-AES256 + Versioning. 매일 3AM cron (Linux team2-db-backup IAM)
```
