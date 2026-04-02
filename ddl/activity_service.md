# Activity Service Database 설계 문서

## 서비스 개요

영업 활동 기록, 거래처 컨택 관리, 메일 이력을 관리하는 서비스입니다.
영업 담당자의 고객 접점 활동과 문서 발송 이력을 추적합니다.

> **참고**: 매출/수금 현황(collections)과 출하현황(shipments)은 PO 기반 문서 흐름의 연장선이므로 **Document 서비스**에 소속됩니다.

## 테이블 목록 (8개)

| 테이블 | 설명 | 레코드 예시 |
|--------|------|-------------|
| activities | 영업 활동 기록 | 미팅, 이슈, 메모, 일정 |
| contacts | 거래처 담당자 연락처 | 바이어 담당자 컨택 정보 |
| email_logs | 메일 발송 이력 | 문서 메일 발송 기록 |
| email_log_types | 메일 첨부 문서 유형 | PI, CI, PL, MO, SO |
| email_log_attachments | 메일 첨부파일 | PDF 파일명 |
| activity_packages | 활동기록 패키지 | 월별 영업활동 보고 패키지 |
| activity_package_viewers | 패키지 열람 권한 | 패키지별 열람 가능 사용자 |
| activity_package_items | 패키지 포함 활동기록 | 패키지에 포함된 활동 목록 |

---

## 테이블 상세

### 1. activities (영업 활동 기록)

영업 담당자의 활동을 기록합니다. 4가지 유형의 활동을 관리합니다.

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| activity_id | INT | PK, AUTO_INCREMENT | |
| client_id | INT | NOT NULL | FK → master.clients.client_id (필수) |
| po_id | VARCHAR(30) | NULL | FK → document.purchase_orders.po_id (선택) |
| activity_author_id | INT | NOT NULL | FK → auth.users.user_id (작성자) |
| activity_date | DATE | NOT NULL | 활동일 |
| activity_type | ENUM | NOT NULL | 활동 유형 (아래 참고) |
| activity_title | VARCHAR(100) | NOT NULL | 활동 제목 |
| activity_content | TEXT | NULL | 활동 내용 |
| activity_priority | ENUM('높음','보통') | NULL | 이슈 우선순위 |
| activity_schedule_from | DATE | NULL | 일정 시작일 |
| activity_schedule_to | DATE | NULL | 일정 종료일 |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | |
| updated_at | TIMESTAMP | ON UPDATE | |

**type ENUM 값 및 사용 컬럼**:

| 유형 | 설명 | 추가 사용 컬럼 |
|------|------|---------------|
| `미팅/협의` | 고객 미팅, 전화 협의 기록 | activity_content |
| `이슈` | 문제/이슈 추적 | activity_content, **activity_priority** |
| `메모/노트` | 일반 메모 | activity_content |
| `일정` | 향후 일정 관리 | activity_content, **activity_schedule_from**, **activity_schedule_to** |

**비즈니스 규칙**:
- `client_id`는 필수 (모든 활동은 거래처에 귀속)
- `po_id`는 선택 (특정 PO와 연결 가능)
- `activity_priority`는 `activity_type = '이슈'`일 때만 사용
- `activity_schedule_from/to`는 `activity_type = '일정'`일 때만 사용

**사용 화면**: ActivityListPage (목록/필터/상세 모달), ActivityCreatePage (등록/수정)

---

### 2. contacts (거래처 담당자 연락처)

영업 활동 관점의 거래처 담당자 컨택 리스트입니다.

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| contact_id | INT | PK, AUTO_INCREMENT | |
| client_id | INT | NOT NULL | FK → master.clients.client_id |
| contact_name | VARCHAR(100) | NOT NULL | 담당자명 |
| contact_position | VARCHAR(100) | NULL | 직함 |
| contact_email | VARCHAR(255) | NULL | 이메일 |
| contact_tel | VARCHAR(50) | NULL | 전화번호 |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | |
| updated_at | TIMESTAMP | ON UPDATE | |

**contacts (Activity) vs buyers (Master) 차이점**:

| 항목 | contacts | buyers |
|------|----------|--------|
| 서비스 | Activity | Master |
| 관리 화면 | ContactListPage (독립) | ClientDetailPage (거래처 내) |
| 용도 | 영업 컨택 관리 | 거래처 공식 담당자 |
| 접근 | 영업팀 | 전체 |

**사용 화면**: ContactListPage (거래처별 컨택 CRUD)

---

### 3. email_logs (메일 이력)

시스템을 통해 발송된 문서 메일의 이력을 기록합니다.

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| email_log_id | INT | PK, AUTO_INCREMENT | |
| client_id | INT | NOT NULL | FK → master.clients.client_id |
| po_id | VARCHAR(30) | NULL | FK → document.purchase_orders.po_id |
| email_title | VARCHAR(200) | NOT NULL | 메일 제목 |
| email_recipient_name | VARCHAR(100) | NULL | 수신자명 |
| email_recipient_email | VARCHAR(255) | NOT NULL | 수신자 이메일 |
| email_sender_id | INT | NOT NULL | FK → auth.users.user_id (발송자) |
| email_status | ENUM('발송','실패') | DEFAULT '발송' | 발송 상태 |
| email_sent_at | TIMESTAMP | NULL | 발송 시각 |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | |

**자동 기록**: 문서(PI/CI/PL/생산지시서/출하지시서) 발송 시 `documentActivityEmail.js` 유틸에 의해 자동 생성

**사용 화면**: EmailListPage (이력 조회, 첨부파일 PDF 프리뷰)

---

### 4. email_log_types (메일 첨부 문서 유형)

하나의 메일에 여러 유형의 문서가 첨부될 수 있습니다 (1:N 관계).

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| email_log_type_id | INT | PK, AUTO_INCREMENT | |
| email_log_id | INT | FK→email_logs, NOT NULL | 소속 메일 |
| email_doc_type | ENUM('PI','CI','PL','MO','SO') | NOT NULL | 첨부 문서 유형 |

**doc_type 값**:

| 값 | 문서 유형 |
|----|-----------|
| `PI` | Proforma Invoice (견적송장) |
| `CI` | Commercial Invoice (상업송장) |
| `PL` | Packing List (포장명세서) |
| `MO` | Manufacturing/Production Order (생산지시서) |
| `SO` | Shipment Order (출하지시서) |

---

### 5. email_log_attachments (메일 첨부파일)

메일에 첨부된 PDF 파일명을 기록합니다 (1:N 관계).

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| email_log_attachment_id | INT | PK, AUTO_INCREMENT | |
| email_log_id | INT | FK→email_logs, NOT NULL | 소속 메일 |
| email_attachment_filename | VARCHAR(255) | NOT NULL | 첨부파일명 (예: PI2025001.pdf) |

**사용 화면**: EmailListPage에서 첨부파일 클릭 시 PDF 프리뷰 모달 표시

---

### 6. activity_packages (활동기록 패키지)

영업 활동 기록을 묶어서 보고용 패키지로 관리합니다. 특정 기간의 활동을 선택하여 패키지로 구성하고, 지정된 열람자에게 공유할 수 있습니다.

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| package_id | INT | PK, AUTO_INCREMENT | |
| package_title | VARCHAR(100) | NOT NULL | 패키지 제목 |
| package_description | TEXT | NULL | 패키지 설명 |
| po_id | VARCHAR(30) | NULL | FK → document.purchase_orders.po_id (선택) |
| creator_id | INT | NOT NULL | FK → auth.users.user_id (작성자) |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | |
| updated_at | TIMESTAMP | ON UPDATE | |

**비즈니스 규칙**:
- `creator_id`는 필수 (패키지 작성자)
- `po_id`는 선택 (특정 PO와 연결 가능)
- 패키지에 포함할 활동은 `activity_package_items`로 관리
- 열람 권한은 `activity_package_viewers`로 관리

**사용 화면**: ActivityPackagePage (패키지 작성/수정), DashboardPage (패키지 목록), PackageDetailModal (패키지 상세/PDF)

---

### 7. activity_package_viewers (패키지 열람 권한)

패키지별 열람 가능 사용자를 관리합니다 (N:M 관계).

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| package_viewer_id | INT | PK, AUTO_INCREMENT | |
| package_id | INT | FK→activity_packages, NOT NULL | 소속 패키지 |
| user_id | INT | FK→auth.users, NOT NULL | 열람 가능 사용자 |

**제약조건**: `UNIQUE (package_id, user_id)` — 동일 패키지에 같은 사용자 중복 등록 방지

---

### 8. activity_package_items (패키지 포함 활동기록)

패키지에 포함된 활동 기록을 관리합니다 (N:M 관계).

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| package_item_id | INT | PK, AUTO_INCREMENT | |
| package_id | INT | FK→activity_packages, NOT NULL | 소속 패키지 |
| activity_id | INT | FK→activities, NOT NULL | 포함된 활동 |

**제약조건**: `UNIQUE (package_id, activity_id)` — 동일 패키지에 같은 활동 중복 등록 방지

---

## 알림(Notification) 시스템 참고

**알림은 별도 테이블에 저장하지 않고, 기존 데이터에서 동적으로 계산합니다.**

| 알림 유형 | 데이터 소스 (서비스) | 조건 | 대상 역할 |
|-----------|---------------------|------|-----------|
| 결재 요청 | approval_requests (Document) | `approval_status='대기'` | admin, 팀장 |
| 출하 완료 | shipments (Document) | `shipment_status='출하완료'` | sales, admin, shipping |
| 수금 완료 | collections (Document) | `collection_status='수금완료'` | sales, admin |

Toast 메시지는 완전 메모리 기반 (2.5~3.5초 자동 소멸, DB 미저장).

---

## 대시보드(Dashboard) 데이터 참고

대시보드 KPI, 차트, 테이블 데이터는 **별도 테이블이 아닌 집계 API**로 제공됩니다.
실제 구현 시 각 서비스의 데이터를 집계하여 생성합니다. **별도 DDL 불필요.**

---

## Cross-Service 참조 (Activity → 외부)

| 외부 서비스 | 참조 테이블.컬럼 | 참조 대상 |
|-------------|-----------------|-----------|
| Auth | activities.activity_author_id | → users.user_id |
| Auth | email_logs.email_sender_id | → users.user_id |
| Master | activities.client_id | → clients.client_id |
| Master | contacts.client_id | → clients.client_id |
| Master | email_logs.client_id | → clients.client_id |
| Auth | activity_packages.creator_id | → users.user_id |
| Auth | activity_package_viewers.user_id | → users.user_id |
| Document | activities.po_id (VARCHAR(30)) | → purchase_orders.po_id |
| Document | email_logs.po_id (VARCHAR(30)) | → purchase_orders.po_id |
| Document | activity_packages.po_id (VARCHAR(30)) | → purchase_orders.po_id |
