# Auth Service TODO

> 최종 업데이트: 2026-04-02

## 완료된 작업

### 백엔드 (team2-backend-auth)
- [x] POST /api/auth/login — TokenResponse에 UserInfo 포함
- [x] POST /api/auth/logout — 리프레시 토큰 무효화
- [x] POST /api/auth/refresh — 토큰 갱신 + UserInfo 포함
- [x] POST /api/auth/forgot-password — 임시 비밀번호 이메일 발송
- [x] GET /api/auth/validate — JWT 헤더 검증 (기존)
- [x] GET /api/users — 페이징 + 필터 (userName, departmentId, userRole, userStatus)
- [x] GET /api/users/{id} — 사용자 상세 (기존)
- [x] POST /api/users — 사용자 생성 (기존)
- [x] PUT /api/users/{id} — 사용자 수정 (기존)
- [x] PUT /api/users/{id}/password — 비밀번호 변경 (현재 비밀번호 검증)
- [x] POST /api/users/{id}/password/reset — 관리자 비밀번호 초기화 (test1234)
- [x] PATCH /api/users/{id}/status — 사용자 상태 변경 (ACTIVE/ON_LEAVE/RETIRED)
- [x] GET /api/departments — 부서 목록 (기존)
- [x] POST /api/departments — 부서 생성 (기존)
- [x] PUT /api/departments/{id} — 부서 수정 (신규)
- [x] DELETE /api/departments/{id} — 부서 삭제 (기존)
- [x] GET /api/positions — 직급 목록 (기존)
- [x] POST /api/positions — 직급 생성 (기존)
- [x] PUT /api/positions/{id} — 직급 수정 (신규)
- [x] DELETE /api/positions/{id} — 직급 삭제 (신규)
- [x] GET /api/company — 회사 정보 (기존)
- [x] PUT /api/company — 회사 정보 수정 (기존)
- [x] POST /api/company/seal — 회사 인감 S3 업로드 (신규)
- [x] ENUM 정합성 — DDL(소문자 영문) ↔ Java enum (JPA Converter + MyBatis TypeHandler)
- [x] PagedResponse 공통 DTO

### 프론트엔드 (team2-frontend)
- [x] 로그인/로그아웃/토큰갱신 — 실제 백엔드 JWT 연동
- [x] 비밀번호 변경/초기화/찾기 — 백엔드 API 연동
- [x] 사용자 목록 — PagedResponse 대응
- [x] 사용자 삭제 → PATCH /status (RETIRED) 변경
- [x] 회사 정보 경로 수정 (/company/1 → /company)
- [x] enumLabels.js — 전 서비스 공통 ENUM 한글 라벨 유틸
- [x] 필드명 정합성 (userId, userName, userEmail, userRole, userStatus)
- [x] PR #225: https://github.com/hanhwa-swcamp-22th-final/team2-frontend/pull/225

### DDL
- [x] 전 서비스 ENUM 한글 → 영문 소문자 통일 (auth/master/document/activity)
- [x] company_seal_image_url VARCHAR(255) → VARCHAR(500)

### API 명세서
- [x] REST_API_명세서.md v1.1 업데이트

---

## 미완료 TODO

### AWS / 외부 서비스 설정 (계정 생성 후)
- [ ] **S3**: `AWS_ACCESS_KEY`, `AWS_SECRET_KEY`, `AWS_REGION`, `AWS_S3_BUCKET` 환경변수 설정
- [ ] **S3**: CloudFront 도메인 설정 시 `S3FileService.java` URL 생성 부분 수정
- [ ] **Gmail SMTP**: 공용 구글 계정 생성 → 앱 비밀번호 발급
- [ ] **Gmail SMTP**: `MAIL_USERNAME`, `MAIL_PASSWORD` 환경변수 설정
- [ ] **Gmail SMTP**: `EmailService.java`의 `FROM_ADDRESS` 실제 발신 주소로 변경

### 테스트 코드
- [ ] Auth Service 테스트 코드 변경 필요 (기존 Jacoco 100% → 새 엔드포인트/서비스 반영)
  - TokenResponse.UserInfo 관련 테스트
  - UserCommandService: changePassword, resetPassword, forgotPassword
  - UserQueryService: getUsers (페이징)
  - DepartmentCommandService: updateDepartment
  - PositionCommandService: updatePosition, deletePosition
  - CompanyCommandService: uploadSealImage
  - AuthController: forgotPassword
  - UserCommandController: changePassword, resetPassword
  - Enum Converter / TypeHandler 테스트

### 프론트엔드 (PR 머지 후)
- [ ] 상위 레포 서브모듈 포인터 업데이트

---

## 데이터 흐름 정리

```
DB (active/sales)
  → MyBatis (그대로 영문 코드)
  → 백엔드 응답 JSON (active/sales)
  → 프론트엔드 (active/sales)
  → enumLabels.js (active → 재직, sales → 영업)
  → 화면 표시 (재직, 영업)

프론트 폼 (sales 선택)
  → 백엔드 전송 (sales)
  → Java enum (Role.SALES)
  → DB (active)
```
