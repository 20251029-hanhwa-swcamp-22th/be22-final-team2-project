# Auth Service Database 설계 문서

## 서비스 개요

사용자 인증/인가 및 조직 관리를 담당하는 서비스입니다.
로그인, 세션 관리, 사용자/부서/직급 CRUD, 회사 정보 관리를 처리합니다.

## 테이블 목록 (5개)

| 테이블 | 설명 | 레코드 예시 |
|--------|------|-------------|
| positions | 직급 마스터 | 팀장(level:1), 팀원(level:2) |
| departments | 부서 마스터 | 영업1팀, 영업2팀, 생산부, 출하부, 관리부 |
| users | 사용자 계정 | 로그인, 권한, 소속 정보 |
| company | 회사 정보 | 단일 레코드 (회사명, 주소, 직인 등) |
| refresh_tokens | JWT 리프레시 토큰 | 사용자별 토큰 관리 |

---

## 테이블 상세

### 1. positions (직급)

역할 기반 접근 제어(RBAC)의 핵심 테이블입니다. `position_level` 값으로 권한 수준을 결정합니다.

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| position_id | INT | PK, AUTO_INCREMENT | |
| position_name | VARCHAR(50) | NOT NULL | 직급명 (팀장, 팀원) |
| position_level | INT | NOT NULL | 권한 수준 (1=최고, 숫자 클수록 낮음) |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | |

**비즈니스 규칙**:
- `position_level = 1` (팀장): 결재 권한 보유, 문서 등록/수정/삭제 시 결재 없이 즉시 처리 (바이패스)
- `position_level = 2` (팀원): 문서 변경 시 반드시 팀장 결재 필요

**사용 화면**: UserManagementPage (사용자 등록 시 직급 선택)

---

### 2. departments (부서)

조직 구조와 데이터 접근 범위를 결정합니다.

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| department_id | INT | PK, AUTO_INCREMENT | |
| department_name | VARCHAR(100) | NOT NULL | 부서명 |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | |

**비즈니스 규칙**:
- `sales` 역할 사용자는 자신의 `department_id`와 동일한 거래처(clients)만 조회 가능
- 부서 삭제 시 소속 사용자와 거래처 관계 확인 필요

**사용 화면**: UserManagementPage > 부서 관리 탭

**참조하는 테이블**:
- `users.department_id` (Auth 내부)
- `clients.department_id` (Master 서비스, cross-service)

---

### 3. users (사용자)

시스템의 핵심 인증/인가 테이블입니다.

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| user_id | INT | PK, AUTO_INCREMENT | |
| employee_no | VARCHAR(20) | NOT NULL, UNIQUE | 사번 |
| user_name | VARCHAR(100) | NOT NULL | 이름 |
| user_email | VARCHAR(255) | NOT NULL, UNIQUE | 로그인 ID |
| user_pw | VARCHAR(255) | NOT NULL | bcrypt 해시 비밀번호 |
| user_role | ENUM | NOT NULL, DEFAULT 'sales' | 역할 (아래 참고) |
| department_id | INT | FK→departments, NULL | 소속 부서 |
| position_id | INT | FK→positions, NULL | 직급 |
| user_status | ENUM | NOT NULL, DEFAULT '재직' | 계정 상태 |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | |
| updated_at | TIMESTAMP | ON UPDATE | |

**role ENUM 값**:

| 값 | 설명 | 접근 범위 |
|----|------|-----------|
| `admin` | 관리자 | 전체 시스템 접근, 사용자 관리 가능 |
| `sales` | 영업 담당 | PI/PO/활동기록 CRUD, 소속 부서 거래처만 조회 |
| `production` | 생산 담당 | 생산지시서 조회, 대시보드 생산 KPI |
| `shipping` | 출하 담당 | 출하지시서/출하현황 조회, 대시보드 출하 KPI |

**status ENUM 값**:

| 값 | 설명 | 비고 |
|----|------|------|
| `재직` | 활성 계정 | 로그인 가능 |
| `휴직` | 일시 비활성 | 로그인 차단 |
| `퇴직` | 소프트 삭제 | 로그인 차단, 기존 데이터 참조 유지 |

**인덱스**: user_email (로그인 조회), employee_no (사번 조회), department_id, position_id

**사용 화면**: LoginPage, UserManagementPage, 모든 화면의 RBAC 필터링

**참조하는 테이블** (cross-service):
- Document: `proforma_invoices.manager_id`, `purchase_orders.manager_id`, `production_orders.manager_id`, `shipment_orders.manager_id`, `approval_requests.approval_requester_id`, `approval_requests.approval_approver_id`
- Activity: `activities.activity_author_id`, `email_logs.email_sender_id`, `collections.manager_id`

---

### 4. company (회사정보)

단일 레코드 테이블. 문서 PDF 출력 시 회사 정보로 사용됩니다.

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| company_id | INT | PK, AUTO_INCREMENT | |
| company_name | VARCHAR(200) | NOT NULL | 회사명 |
| company_address_en | VARCHAR(500) | NULL | 영문 주소 (PI/PO/CI/PL 영문 문서용) |
| company_address_kr | VARCHAR(500) | NULL | 국문 주소 |
| company_tel | VARCHAR(50) | NULL | 대표전화 |
| company_fax | VARCHAR(50) | NULL | FAX 번호 |
| company_email | VARCHAR(255) | NULL | 대표 이메일 |
| company_website | VARCHAR(255) | NULL | 웹사이트 |
| company_seal_image_url | VARCHAR(255) | NULL | 회사 직인 이미지 URL (PDF 출력 시 사용) |
| updated_at | TIMESTAMP | ON UPDATE | |

**사용 화면**: UserManagementPage > 회사정보 탭, 문서 PDF 출력 시 헤더/푸터

---

### 5. refresh_tokens (리프레시 토큰)

JWT 인증의 리프레시 토큰을 관리합니다.

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| refresh_token_id | INT | PK, AUTO_INCREMENT | |
| user_id | INT | FK→users, NOT NULL | 토큰 소유자 |
| token_value | VARCHAR(512) | NOT NULL | 리프레시 토큰 값 |
| token_expires_at | DATETIME | NOT NULL | 만료 시각 |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | |

**비즈니스 규칙**:
- AccessToken: 메모리(Pinia store)에 저장, 단기 만료
- RefreshToken: httpOnly 쿠키 + DB 저장, 장기 만료
- 로그아웃 시 DB에서 해당 토큰 삭제
- 백엔드 구현 시 토큰 로테이션 적용 예정

**인덱스**: user_id, token_value(255)

---

## 알림(Notification) 관련 참고

Auth 서비스 자체에 알림 테이블은 없습니다. 시스템의 알림은 **DB에 저장하지 않고 동적으로 생성**됩니다:

| 알림 유형 | 데이터 소스 | 대상 역할 |
|-----------|------------|-----------|
| 결재 요청 | PI/PO의 `pi_approval_status/po_approval_status='대기'` | admin, 팀장(position_level:1) |
| 출하 완료 | shipments의 `shipment_status='출하완료'` | sales, admin, shipping |
| 수금 완료 | collections의 `collection_status='수금완료'` | sales, admin |

알림은 헤더의 벨 아이콘에서 기존 문서 상태를 조회하여 실시간 계산합니다.
Toast 메시지(성공/에러/경고/정보)는 완전한 메모리 기반으로, DB 저장 없이 2.5~3.5초 후 자동 소멸합니다.

---

## ERD (Auth 서비스 내부)

```
positions ──1:N──→ users
departments ──1:N──→ users
users ──1:N──→ refresh_tokens
company (독립, FK 없음)
```

## Cross-Service 참조 (Auth → 외부)

| 외부 서비스 | 참조 테이블.컬럼 | 참조 방향 |
|-------------|-----------------|-----------|
| Master | clients.department_id → departments.department_id | Master → Auth |
| Document | proforma_invoices.manager_id → users.user_id | Document → Auth |
| Document | purchase_orders.manager_id → users.user_id | Document → Auth |
| Document | production_orders.manager_id → users.user_id | Document → Auth |
| Document | shipment_orders.manager_id → users.user_id | Document → Auth |
| Document | approval_requests.approval_requester_id → users.user_id | Document → Auth |
| Document | approval_requests.approval_approver_id → users.user_id | Document → Auth |
| Activity | activities.activity_author_id → users.user_id | Activity → Auth |
| Activity | email_logs.email_sender_id → users.user_id | Activity → Auth |
| Activity | collections.manager_id → users.user_id | Activity → Auth |
| Activity | activity_packages.creator_id → users.user_id | Activity → Auth |
| Activity | activity_package_viewers.user_id → users.user_id | Activity → Auth |
