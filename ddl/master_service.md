# Master Service Database 설계 문서

## 서비스 개요

기준정보(마스터 데이터)를 관리하는 서비스입니다.
거래처, 품목, 거래처 담당자 및 각종 참조 데이터(국가, 통화, 항구, 결제조건, 인코텀즈)를 관리합니다.
다른 모든 서비스에서 참조하는 기반 데이터를 제공합니다.

## 테이블 목록 (8개)

| 테이블 | 설명 | 레코드 예시 |
|--------|------|-------------|
| countries | 국가 코드 | US/United States, KR/대한민국 (13개) |
| incoterms | 인코텀즈 카탈로그 | FOB, CIF, EXW 등 (11개) |
| currencies | 통화 | USD/$, EUR/€, KRW/₩ (6개) |
| ports | 항구/항만 | KRPUS/부산항, USNYC/뉴욕항 (15개) |
| payment_terms | 결제조건 | T/T, L/C, D/P (5개) |
| clients | 거래처 (바이어) | 해외 수출 대상 기업 (20개) |
| items | 품목 (상품) | 수출 제품 목록 (20개) |
| buyers | 거래처 담당자 | 거래처별 연락 담당자 (46개) |

---

## 테이블 상세

### 1. countries (국가)

국가 코드 마스터입니다. 거래처, 항구 등에서 참조합니다.

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| country_id | INT | PK, AUTO_INCREMENT | |
| country_code | VARCHAR(10) | NOT NULL, UNIQUE | 국가 코드 (US, KR, JP 등) |
| country_name | VARCHAR(100) | NOT NULL | 영문 국가명 |
| country_name_kr | VARCHAR(100) | NULL | 한글 국가명 |

**사용 화면**: ClientListPage (국가 필터), PI/PO 문서 (국가 표시)

---

### 2. incoterms (인코텀즈)

국제상업회의소(ICC) 인코텀즈 2020 기준 무역 조건 카탈로그입니다.

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| incoterm_id | INT | PK, AUTO_INCREMENT | |
| incoterm_code | VARCHAR(10) | NOT NULL, UNIQUE | 인코텀즈 코드 (FOB, CIF, EXW 등) |
| incoterm_name | VARCHAR(200) | NOT NULL | 영문 정식명칭 |
| incoterm_name_kr | VARCHAR(200) | NULL | 한글명 |
| incoterm_description | TEXT | NULL | 조건 상세 설명 |
| incoterm_transport_mode | VARCHAR(50) | NULL | 운송 수단 (해상, 복합 등) |
| incoterm_seller_segments | VARCHAR(50) | NULL | 매도인 부담 구간 |
| incoterm_default_named_place | VARCHAR(100) | NULL | 기본 지정 장소 |

**비즈니스 규칙**:
- 거래처(clients)에 인코텀즈를 할당하지 않음 (건별 관리)
- PI/PO 생성 시 문서 단위로 인코텀즈 코드와 지정 장소(pi_named_place/po_named_place)를 선택
- Document 서비스의 `proforma_invoices.pi_incoterms_code`, `purchase_orders.po_incoterms_code`에서 코드로 참조

**사용 화면**: PIPage (PI 생성/수정 폼), POPage (PO 생성/수정 폼)

---

### 3. currencies (통화)

거래에 사용되는 통화 마스터입니다.

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| currency_id | INT | PK, AUTO_INCREMENT | |
| currency_code | VARCHAR(10) | NOT NULL, UNIQUE | 통화 코드 (USD, EUR, KRW 등) |
| currency_name | VARCHAR(100) | NOT NULL | 통화명 |
| currency_symbol | VARCHAR(5) | NULL | 통화 기호 ($, €, ₩ 등) |

**사용 화면**: ClientListPage (통화 필터), PI/PO/CI 문서 (금액 표시)

**참조하는 테이블**:
- Master: `clients.currency_id`
- Document: `proforma_invoices.currency_id`, `purchase_orders.currency_id`, `commercial_invoices.currency_id`
- Document: `collections.currency_id`

---

### 4. ports (항구)

수출 선적항/도착항 마스터입니다.

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| port_id | INT | PK, AUTO_INCREMENT | |
| port_code | VARCHAR(20) | NOT NULL, UNIQUE | 항구 코드 (KRPUS, USNYC 등) |
| port_name | VARCHAR(100) | NOT NULL | 항구명 |
| port_city | VARCHAR(100) | NULL | 소재 도시 |
| country_id | INT | NOT NULL | FK → countries.country_id (주석 참조) |

**사용 화면**: ClientListPage (거래처 등록 시 항구 선택)

---

### 5. payment_terms (결제조건)

무역 결제 조건 마스터입니다.

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| payment_term_id | INT | PK, AUTO_INCREMENT | |
| payment_term_code | VARCHAR(20) | NOT NULL, UNIQUE | 결제조건 코드 (TT, LC, DP 등) |
| payment_term_name | VARCHAR(100) | NOT NULL | 결제조건명 |
| payment_term_description | VARCHAR(200) | NULL | 상세 설명 (예: "전신환 송금") |

**사용 화면**: ClientListPage (거래처 등록 시 결제조건 선택)

---

### 6. clients (거래처)

수출 대상 해외 바이어 정보를 관리합니다. RBAC 필터링이 적용되는 핵심 테이블입니다.

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| client_id | INT | PK, AUTO_INCREMENT | |
| client_code | VARCHAR(20) | NOT NULL, UNIQUE | 거래처 코드 |
| client_name | VARCHAR(100) | NOT NULL | 영문 거래처명 |
| client_name_kr | VARCHAR(100) | NULL | 한글 거래처명 |
| country_id | INT | FK→countries, NULL | 소재 국가 |
| client_city | VARCHAR(100) | NULL | 소재 도시 |
| port_id | INT | FK→ports, NULL | 주 선적/도착 항구 |
| client_address | TEXT | NULL | 상세 주소 |
| client_tel | VARCHAR(50) | NULL | 전화번호 |
| client_email | VARCHAR(255) | NULL | 이메일 |
| payment_term_id | INT | FK→payment_terms, NULL | 기본 결제조건 |
| currency_id | INT | FK→currencies, NULL | 기본 거래통화 |
| client_manager | VARCHAR(100) | NULL | 담당자명 (텍스트) |
| department_id | INT | NULL | FK → auth.departments.department_id (cross-service) |
| client_status | ENUM('활성','비활성') | NOT NULL, DEFAULT '활성' | 거래 상태 |
| client_reg_date | DATE | NULL | 등록일 |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | |
| updated_at | TIMESTAMP | ON UPDATE | |

**RBAC (역할 기반 접근 제어)**:
- `sales` 역할 사용자: 자신의 `department_id`와 일치하는 거래처만 조회/수정 가능
- `admin` 역할: 전체 거래처 접근 가능
- `production`, `shipping`: 문서에 연결된 거래처 정보만 읽기 전용 조회

**비즈니스 규칙**:
- 거래처에 인코텀즈를 직접 할당하지 않음 (문서별 건별 관리)
- 거래처 삭제 시 연결된 PI/PO/활동기록 존재 여부 확인 필요
- `client_status = '비활성'`으로 변경하여 소프트 삭제 처리

**사용 화면**: ClientListPage, ClientDetailPage, PI/PO 생성 시 거래처 검색 모달

**참조하는 테이블** (cross-service):
- Document: `proforma_invoices.client_id`, `purchase_orders.client_id`, `commercial_invoices.client_id`, `packing_lists.client_id`, `production_orders.client_id`, `shipment_orders.client_id`
- Activity: `activities.client_id`, `contacts.client_id`, `email_logs.client_id`
- Document: `collections.client_id`, `shipments.client_id`

---

### 7. items (품목)

수출 제품/상품 마스터입니다.

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| item_id | INT | PK, AUTO_INCREMENT | |
| item_code | VARCHAR(50) | NOT NULL, UNIQUE | 품목 코드 |
| item_name | VARCHAR(100) | NOT NULL | 영문 품목명 |
| item_name_kr | VARCHAR(100) | NULL | 한글 품목명 |
| item_spec | VARCHAR(200) | NULL | 규격/사양 |
| item_unit | VARCHAR(50) | NULL | 단위 (EA, KG, SET 등) |
| item_pack_unit | VARCHAR(50) | NULL | 포장 단위 |
| item_unit_price | DECIMAL(15,2) | NULL | 기본 단가 |
| item_weight | DECIMAL(10,3) | NULL | 중량 (kg) |
| item_hs_code | VARCHAR(20) | NULL | HS 코드 (관세 분류) |
| item_category | VARCHAR(100) | NULL | 품목 카테고리 |
| item_status | ENUM('활성','비활성') | NOT NULL, DEFAULT '활성' | |
| item_reg_date | DATE | NULL | 등록일 |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | |
| updated_at | TIMESTAMP | ON UPDATE | |

**비즈니스 규칙**:
- PI/PO 품목 추가 시 items에서 검색하여 기본 정보(단가, 단위 등) 자동 입력
- 단가는 문서별로 변경 가능 (items.item_unit_price는 기본값)
- item_hs_code는 관세 신고 시 필요한 국제 표준 코드

**사용 화면**: ItemListPage, ItemDetailPage, PI/PO 생성 시 품목 검색 모달

**참조하는 테이블**: `pi_items.item_id`, `po_items.item_id`

---

### 8. buyers (거래처 담당자)

거래처별 해외 바이어 담당자 연락처입니다.

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| buyer_id | INT | PK, AUTO_INCREMENT | |
| client_id | INT | FK→clients, NOT NULL | 소속 거래처 |
| buyer_name | VARCHAR(100) | NOT NULL | 담당자명 |
| buyer_position | VARCHAR(100) | NULL | 직함 |
| buyer_email | VARCHAR(255) | NULL | 이메일 |
| buyer_tel | VARCHAR(50) | NULL | 전화번호 |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | |
| updated_at | TIMESTAMP | ON UPDATE | |

**buyers vs contacts 관계**:
- `buyers` (Master): 거래처에 귀속된 해외 바이어 담당자. 거래처 상세 화면에서 관리
- `contacts` (Activity): 영업 활동 맥락의 컨택 리스트. ContactListPage에서 독립 관리
- 두 테이블은 동일 인물을 참조할 수 있으나, 용도와 관리 주체가 다름

**사용 화면**: ClientDetailPage (거래처 상세 내 담당자 목록)

---

## ERD (Master 서비스 내부)

```
countries ──1:N──→ ports (country_id)
countries ──1:N──→ clients (country_id)
ports ──1:N──→ clients (port_id)
payment_terms ──1:N──→ clients (payment_term_id)
currencies ──1:N──→ clients (currency_id)
clients ──1:N──→ buyers (client_id)
incoterms (독립 카탈로그, FK 없음 — 문서에서 incoterm_code로 참조)
```

## Cross-Service 참조 (Master → 외부)

| 외부 서비스 | 참조 관계 | 방향 |
|-------------|-----------|------|
| Auth | clients.department_id → departments.department_id | Master → Auth |
| Document | PI/PO/CI/PL/생산/출하.client_id → clients.client_id | Document → Master |
| Document | PI/PO/CI.currency_id → currencies.currency_id | Document → Master |
| Document | pi_items/po_items.item_id → items.item_id | Document → Master |
| Activity | activities/contacts/email_logs/collections/shipments.client_id → clients.client_id | Activity → Master |
| Activity | collections.currency_id → currencies.currency_id | Activity → Master |
