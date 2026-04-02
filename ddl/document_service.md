# Document Service Database 설계 문서

## 서비스 개요

무역 문서의 전체 라이프사이클과 현황 모니터링을 관리하는 서비스입니다.
견적(PI) → 발주(PO) → 상업송장(CI) + 포장명세서(PL) + 생산지시서 + 출하지시서의 문서 흐름,
결재 워크플로우, 그리고 매출/수금 현황 및 출하현황 추적을 처리합니다.

## 테이블 목록 (11개)

| 테이블 | 설명 | 레코드 예시 |
|--------|------|-------------|
| proforma_invoices | 견적송장 (PI) | 해외 바이어 대상 견적 문서 |
| pi_items | PI 품목 | PI별 품목 상세 (N개) |
| purchase_orders | 발주서 (PO) | PI 기반 발주 문서 |
| po_items | PO 품목 | PO별 품목 상세 (N개) |
| commercial_invoices | 상업송장 (CI) | PO 확정 시 자동 생성 |
| packing_lists | 포장명세서 (PL) | PO 확정 시 자동 생성 |
| production_orders | 생산지시서 | PO 확정 시 자동 생성 |
| shipment_orders | 출하지시서 | PO 확정 시 자동 생성 |
| approval_requests | 결재 요청 | PI/PO 결재 워크플로우 |
| collections | 매출·수금 현황 | PO별 매출/수금 추적 (현황 모니터링) |
| shipments | 출하현황 | 출하 상태 모니터링 (현황 모니터링) |

---

## 문서 흐름 (Document Flow)

```
[PI 생성] → 결재 → [PI 확정]
                        ↓
                   [PO 생성] → 결재 → [PO 확정]
                                          ↓ (자동 생성)
                                    ┌─────┼─────────────┐
                                    ↓     ↓             ↓
                                  [CI]  [PL]   [생산지시서] [출하지시서]
```

**PO 확정 시 자동 생성되는 문서**: CI, PL, 생산지시서, 출하지시서
**자동 생성 문서는 읽기 전용** (CI, PL은 직접 수정 불가)

---

## 테이블 상세

### 1. proforma_invoices (견적송장 PI)

해외 바이어에게 발송하는 견적 문서입니다. PK는 문서번호 형식(VARCHAR(30))입니다.

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| pi_id | VARCHAR(30) | PK | 문서번호 (예: PI2025-0001) |
| pi_issue_date | DATE | NOT NULL | 발행일 |
| client_id | INT | NOT NULL | FK → master.clients.client_id |
| currency_id | INT | NOT NULL | FK → master.currencies.currency_id |
| manager_id | INT | NOT NULL | FK → auth.users.user_id (담당자) |
| pi_status | ENUM | NOT NULL, DEFAULT '초안' | 문서 상태 (아래 참고) |
| pi_delivery_date | DATE | NULL | 납기일 |
| pi_incoterms_code | VARCHAR(10) | NULL | 인코텀즈 코드 (FOB, CIF 등) |
| pi_named_place | VARCHAR(200) | NULL | 인코텀즈 지정 장소 |
| pi_total_amount | DECIMAL(15,2) | DEFAULT 0 | 총 금액 (pi_items 합계) |
| pi_client_name | VARCHAR(200) | NULL | 거래처명 스냅샷 |
| pi_client_address | TEXT | NULL | 거래처 주소 스냅샷 |
| pi_country | VARCHAR(100) | NULL | 국가명 스냅샷 |
| pi_currency_code | VARCHAR(10) | NULL | 통화 코드 스냅샷 |
| pi_manager_name | VARCHAR(100) | NULL | 담당자명 스냅샷 |
| pi_approval_status | ENUM('대기','승인','반려') | NULL | 결재 상태 |
| pi_request_status | ENUM('등록요청','수정요청','삭제요청') | NULL | 요청 상태 |
| pi_approval_action | ENUM('등록','수정','삭제') | NULL | 결재 액션 |
| pi_approval_requested_by | VARCHAR(100) | NULL | 결재 요청자 |
| pi_approval_requested_at | TIMESTAMP | NULL | 결재 요청 시각 |
| pi_approval_review | JSON | NULL | 결재 검토 데이터 |
| pi_items_snapshot | JSON | NULL | 품목 스냅샷 (결재/이력용) |
| pi_linked_documents | JSON | NULL | 연결 문서 정보 |
| pi_revision_history | JSON | NULL | 수정 이력 |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | |
| updated_at | TIMESTAMP | ON UPDATE | |

**pi_status ENUM 값 및 전이**:

| 상태 | 설명 | 전이 가능 상태 |
|------|------|----------------|
| `초안` | 최초 등록 (팀원) | → 등록요청 |
| `등록요청` | 결재 요청됨 | → 확정 (승인) / 반려 |
| `결재대기` | 결재 대기 중 | → 확정 (승인) / 반려 |
| `확정` | 승인 완료 | → 수정요청 / 삭제요청 |
| `수정요청` | 수정 결재 요청됨 | → 확정 (승인) / 반려 |
| `삭제요청` | 삭제 결재 요청됨 | → 취소 (승인) / 반려 |
| `반려` | 결재 거부됨 | → 등록요청 (재요청) |
| `취소` | 삭제 승인됨 (소프트 삭제) | 최종 상태 |

**팀장 바이패스**: `position_level = 1`인 경우 결재 과정 없이 즉시 `확정` 처리

**사용 화면**: PIPage (목록/생성/수정/삭제), PIDetailPage (상세/PDF)

---

### 2. pi_items (PI 품목)

PI에 포함된 품목 상세입니다. PI 1건에 N개의 품목이 포함됩니다.

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| pi_item_id | INT | PK, AUTO_INCREMENT | |
| pi_id | VARCHAR(30) | FK→proforma_invoices, NOT NULL | 소속 PI |
| item_id | INT | NULL | FK → master.items.item_id (카탈로그 참조) |
| pi_item_name | VARCHAR(200) | NOT NULL | 품목명 (입력 시점 스냅샷) |
| pi_item_qty | INT | DEFAULT 0 | 수량 |
| pi_item_unit | VARCHAR(20) | NULL | 단위 |
| pi_item_unit_price | DECIMAL(15,2) | DEFAULT 0 | 단가 |
| pi_item_amount | DECIMAL(15,2) | DEFAULT 0 | 금액 (qty * unit_price) |
| pi_item_remark | TEXT | NULL | 비고 |

**비즈니스 규칙**:
- `item_id`는 master.items에서 선택 시 자동 입력, 직접 입력 시 NULL 가능
- `pi_item_name`, `pi_item_unit_price` 등은 입력 시점의 스냅샷 (master.items 변경과 무관)

---

### 3. purchase_orders (발주서 PO)

PI를 기반으로 생성되는 발주 문서입니다. PO 확정 시 하위 문서가 자동 생성됩니다. PK는 문서번호 형식(VARCHAR(30))입니다.

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| po_id | VARCHAR(30) | PK | 문서번호 (예: PO2025-0001) |
| pi_id | VARCHAR(30) | FK→proforma_invoices, NULL | 연결된 PI |
| po_issue_date | DATE | NOT NULL | 발행일 |
| client_id | INT | NOT NULL | FK → master.clients.client_id |
| currency_id | INT | NOT NULL | FK → master.currencies.currency_id |
| manager_id | INT | NOT NULL | FK → auth.users.user_id |
| po_status | ENUM | NOT NULL, DEFAULT '초안' | PI와 동일한 상태 체계 |
| po_delivery_date | DATE | NULL | 납기일 |
| po_incoterms_code | VARCHAR(10) | NULL | 인코텀즈 코드 |
| po_named_place | VARCHAR(200) | NULL | 인코텀즈 지정 장소 |
| po_source_delivery_date | DATE | NULL | PI에서 가져온 원본 납기일 |
| po_delivery_date_override | BOOLEAN | DEFAULT FALSE | 납기일 수동 변경 여부 |
| po_total_amount | DECIMAL(15,2) | DEFAULT 0 | 총 금액 |
| po_client_name | VARCHAR(200) | NULL | 거래처명 스냅샷 |
| po_client_address | TEXT | NULL | 거래처 주소 스냅샷 |
| po_country | VARCHAR(100) | NULL | 국가명 스냅샷 |
| po_currency_code | VARCHAR(10) | NULL | 통화 코드 스냅샷 |
| po_manager_name | VARCHAR(100) | NULL | 담당자명 스냅샷 |
| po_approval_status | ENUM('대기','승인','반려') | NULL | 결재 상태 |
| po_request_status | ENUM('등록요청','수정요청','삭제요청') | NULL | 요청 상태 |
| po_approval_action | ENUM('등록','수정','삭제') | NULL | 결재 액션 |
| po_approval_requested_by | VARCHAR(100) | NULL | 결재 요청자 |
| po_approval_requested_at | TIMESTAMP | NULL | 결재 요청 시각 |
| po_approval_review | JSON | NULL | 결재 검토 데이터 |
| po_items_snapshot | JSON | NULL | 품목 스냅샷 (결재/이력용) |
| po_linked_documents | JSON | NULL | 연결 문서 정보 |
| po_revision_history | JSON | NULL | 수정 이력 |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | |
| updated_at | TIMESTAMP | ON UPDATE | |

**PO 확정 시 자동 생성**:
1. `commercial_invoices` 1건
2. `packing_lists` 1건
3. `production_orders` 1건
4. `shipment_orders` 1건

**사용 화면**: POPage, PODetailPage (연결 문서 표시)

---

### 4. po_items (PO 품목)

pi_items와 동일 구조. PO에 포함된 품목 상세입니다.

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| po_item_id | INT | PK, AUTO_INCREMENT | |
| po_id | VARCHAR(30) | FK→purchase_orders, NOT NULL | 소속 PO |
| item_id | INT | NULL | FK → master.items.item_id |
| po_item_name | VARCHAR(200) | NOT NULL | 품목명 |
| po_item_qty | INT | DEFAULT 0 | 수량 |
| po_item_unit | VARCHAR(20) | NULL | 단위 |
| po_item_unit_price | DECIMAL(15,2) | DEFAULT 0 | 단가 |
| po_item_amount | DECIMAL(15,2) | DEFAULT 0 | 금액 |
| po_item_remark | TEXT | NULL | 비고 |

---

### 5. commercial_invoices (상업송장 CI)

PO 확정 시 자동 생성되는 상업송장입니다. **읽기 전용**. PK는 문서번호 형식(VARCHAR(30))입니다.

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| ci_id | VARCHAR(30) | PK | 문서번호 (예: CI2025-0001) |
| po_id | VARCHAR(30) | FK→purchase_orders, NOT NULL | 원본 PO |
| ci_invoice_date | DATE | NOT NULL | 송장 발행일 |
| client_id | INT | NOT NULL | FK → master.clients.client_id |
| currency_id | INT | NOT NULL | FK → master.currencies.currency_id |
| ci_total_amount | DECIMAL(15,2) | DEFAULT 0 | 총 금액 |
| ci_status | ENUM('발행대기','발행완료') | DEFAULT '발행대기' | 발행 상태 |
| ci_client_name | VARCHAR(200) | NULL | 거래처명 스냅샷 |
| ci_client_address | TEXT | NULL | 거래처 주소 스냅샷 |
| ci_country | VARCHAR(100) | NULL | 국가명 스냅샷 |
| ci_currency_code | VARCHAR(10) | NULL | 통화 코드 스냅샷 |
| ci_payment_terms | VARCHAR(100) | NULL | 결제조건 스냅샷 |
| ci_port_of_discharge | VARCHAR(200) | NULL | 양하항 스냅샷 |
| ci_buyer | VARCHAR(100) | NULL | 바이어 정보 스냅샷 |
| ci_items_snapshot | JSON | NULL | 품목 스냅샷 (PDF/출력용) |
| ci_linked_documents | JSON | NULL | 연결 문서 목록 |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | |

**ci_status 전이**: `발행대기` → `발행완료` (출하 완료 시)

**사용 화면**: CIPage (목록), CIDetailPage (상세/PDF 다운로드)

---

### 6. packing_lists (포장명세서 PL)

PO 확정 시 자동 생성되는 포장명세서입니다. **읽기 전용**. PK는 문서번호 형식(VARCHAR(30))입니다.

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| pl_id | VARCHAR(30) | PK | 문서번호 (예: PL2025-0001) |
| po_id | VARCHAR(30) | FK→purchase_orders, NOT NULL | 원본 PO |
| pl_invoice_date | DATE | NOT NULL | 명세서 발행일 |
| client_id | INT | NOT NULL | FK → master.clients.client_id |
| pl_gross_weight | DECIMAL(10,3) | NULL | 총 중량 (kg) |
| pl_status | ENUM('발행대기','발행완료') | DEFAULT '발행대기' | 발행 상태 |
| pl_client_name | VARCHAR(200) | NULL | 거래처명 스냅샷 |
| pl_client_address | TEXT | NULL | 거래처 주소 스냅샷 |
| pl_country | VARCHAR(100) | NULL | 국가명 스냅샷 |
| pl_payment_terms | VARCHAR(100) | NULL | 결제조건 스냅샷 |
| pl_port_of_discharge | VARCHAR(200) | NULL | 양하항 스냅샷 |
| pl_buyer | VARCHAR(100) | NULL | 바이어 정보 스냅샷 |
| pl_items_snapshot | JSON | NULL | 품목 스냅샷 (PDF/출력용) |
| pl_linked_documents | JSON | NULL | 연결 문서 목록 |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | |

**사용 화면**: PLPage (목록), PLDetailPage (상세/PDF 다운로드)

---

### 7. production_orders (생산지시서)

PO 확정 시 자동 생성되는 생산 지시서입니다. PK는 문서번호 형식(VARCHAR(30))입니다.

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| production_order_id | VARCHAR(30) | PK | 문서번호 (예: PRD2025-0001) |
| po_id | VARCHAR(30) | FK→purchase_orders, NOT NULL | 원본 PO |
| production_issue_date | DATE | NOT NULL | 발행일 |
| client_id | INT | NOT NULL | FK → master.clients.client_id |
| manager_id | INT | NULL | FK → auth.users.user_id (생산 담당자) |
| production_status | ENUM('진행중','생산완료') | DEFAULT '진행중' | 생산 진행 상태 |
| production_due_date | DATE | NULL | 생산 완료 기한 |
| production_client_name | VARCHAR(200) | NULL | 거래처명 스냅샷 |
| production_country | VARCHAR(100) | NULL | 국가명 스냅샷 |
| production_manager_name | VARCHAR(100) | NULL | 담당자명 스냅샷 |
| production_item_name | VARCHAR(200) | NULL | 품목명 스냅샷 |
| production_linked_documents | JSON | NULL | 연결 문서 정보 |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | |
| updated_at | TIMESTAMP | ON UPDATE | |

**사용 화면**: ProductionOrderPage, ProductionOrderDetailPage, PDF 다운로드

---

### 8. shipment_orders (출하지시서)

PO 확정 시 자동 생성되는 출하 지시서입니다. PK는 문서번호 형식(VARCHAR(30))입니다.

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| shipment_order_id | VARCHAR(30) | PK | 문서번호 (예: SH2025-0001) |
| po_id | VARCHAR(30) | FK→purchase_orders, NOT NULL | 원본 PO |
| shipment_issue_date | DATE | NOT NULL | 발행일 |
| client_id | INT | NOT NULL | FK → master.clients.client_id |
| manager_id | INT | NULL | FK → auth.users.user_id (출하 담당자) |
| shipment_status | ENUM('출하준비','출하완료') | DEFAULT '출하준비' | 출하 진행 상태 |
| shipment_due_date | DATE | NULL | 출하 기한 |
| shipment_client_name | VARCHAR(200) | NULL | 거래처명 스냅샷 |
| shipment_country | VARCHAR(100) | NULL | 국가명 스냅샷 |
| shipment_manager_name | VARCHAR(100) | NULL | 담당자명 스냅샷 |
| shipment_item_name | VARCHAR(200) | NULL | 품목명 스냅샷 |
| shipment_linked_documents | JSON | NULL | 연결 문서 정보 |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | |
| updated_at | TIMESTAMP | ON UPDATE | |

**Shipment Lock**: `출하준비` 이후 상태에서는 PO 수정/삭제가 차단됩니다.

**사용 화면**: ShipmentOrderPage, ShipmentOrderDetailPage

---

### 9. approval_requests (결재 요청)

PI/PO 문서의 결재 워크플로우를 관리합니다.

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| approval_request_id | INT | PK, AUTO_INCREMENT | |
| approval_document_type | ENUM('PI','PO') | NOT NULL | 대상 문서 유형 |
| approval_document_id | VARCHAR(30) | NOT NULL | 대상 문서 ID (문서번호) |
| approval_request_type | ENUM | NOT NULL | 요청 유형 |
| approval_requester_id | INT | NOT NULL | FK → auth.users.user_id (요청자) |
| approval_approver_id | INT | NOT NULL | FK → auth.users.user_id (결재자) |
| approval_status | ENUM('대기','승인','반려') | DEFAULT '대기' | 결재 상태 |
| approval_review_snapshot | JSON | NULL | 결재 시점 문서 스냅샷 |
| approval_requested_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | 요청 시각 |
| approval_reviewed_at | TIMESTAMP | NULL | 처리 시각 |

**approval_request_type ENUM 값**:

| 값 | 설명 | 승인 시 동작 |
|----|------|-------------|
| `등록요청` | 신규 문서 등록 요청 | 문서 pi_status/po_status → '확정' |
| `수정요청` | 기존 문서 수정 요청 | 변경사항 적용 + pi_status/po_status → '확정' |
| `삭제요청` | 문서 삭제 요청 | 문서 pi_status/po_status → '취소' |

**approval_review_snapshot 구조** (JSON):
```json
{
  "title": "PO 등록 결재 검토",
  "message": "검토 설명",
  "requestRows": [{"label": "요청자", "value": "김영업"}],
  "documentRows": [{"label": "거래처", "value": "Global Steel"}],
  "changeRows": [{"label": "납기일", "before": "03/01", "after": "03/15"}],
  "itemRows": [{"name": "품목A", "qty": 100, "unit": "EA", "unitPrice": 50.00}],
  "itemSummaryRows": [{"label": "합계", "value": "$5,000"}],
  "referenceRows": [{"label": "연결 PI", "value": "PI2025001"}]
}
```

**알림 연동**: `approval_status = '대기'`인 결재건은 헤더 벨 아이콘 알림에 동적으로 표시됩니다.

**사용 화면**: PIPage/POPage (결재 요청 모달), ApprovalReviewModal (결재 검토)

---

## 결재 워크플로우 상세

### 일반 직원 (position_level = 2) 플로우
```
문서 생성/수정/삭제 클릭
  → ApprovalRequestModal 표시
  → 결재자 선택 (팀장 목록)
  → 확인 → approval_requests 생성 (approval_status='대기')
  → 문서 pi_status/po_status → '결재대기'
  → 팀장 검토 (ApprovalReviewModal)
  → 승인: 문서 pi_status/po_status → '확정', approval_requests.approval_status → '승인'
  → 반려: 문서 pi_status/po_status → '반려', approval_requests.approval_status → '반려'
```

### 팀장 (position_level = 1) 바이패스
```
문서 생성 클릭
  → 결재 모달 없이 즉시 처리
  → 문서 pi_status/po_status → '확정'
  → PO 확정 시: CI, PL, 생산지시서, 출하지시서 자동 생성
```

---

## 현황 모니터링 (Status Monitoring)

### 10. collections (매출·수금 현황)

PO 기반 매출 발생과 수금 추적을 관리합니다. `src/views/documents/CollectionsPage.vue`에 위치하며, 사이드바에서 "현황" 섹션에 표시됩니다.

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| collection_id | INT | PK, AUTO_INCREMENT | |
| po_id | VARCHAR(30) | FK→purchase_orders, NOT NULL | 원본 PO |
| client_id | INT | NOT NULL | FK → master.clients.client_id |
| manager_id | INT | NOT NULL | FK → auth.users.user_id (담당자) |
| currency_id | INT | NOT NULL | FK → master.currencies.currency_id |
| collection_sales_amount | DECIMAL(15,2) | DEFAULT 0 | 매출/수금 금액 |
| collection_issue_date | DATE | NOT NULL | 매출 발생일 |
| collection_completed_date | DATE | NULL | 수금 완료일 |
| collection_status | ENUM('미수금','수금완료') | DEFAULT '미수금' | 수금 상태 |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | |
| updated_at | TIMESTAMP | ON UPDATE | |

**collection_status 전이**: `미수금` → `수금완료`

**알림 연동**: `collection_status = '수금완료'`인 건은 헤더 벨 알림에 표시 (sales, admin 역할)

**사용 화면**: CollectionsPage (필터: PO, 담당자, 상태, 발행일, 수금일)

---

### 11. shipments (출하현황)

출하지시서 기반의 실제 출하 상태를 모니터링합니다. `src/views/documents/ShipmentsPage.vue`에 위치합니다.

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| shipment_id | INT | PK, AUTO_INCREMENT | |
| po_id | VARCHAR(30) | FK→purchase_orders, NOT NULL | 원본 PO |
| shipment_order_id | VARCHAR(30) | FK→shipment_orders, NOT NULL | 원본 출하지시서 |
| client_id | INT | NOT NULL | FK → master.clients.client_id |
| shipment_request_date | DATE | NULL | 출하 요청일 |
| shipment_due_date | DATE | NULL | 출하 기한 |
| shipment_status | ENUM('출하준비','출하완료') | DEFAULT '출하준비' | 출하 상태 |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | |
| updated_at | TIMESTAMP | ON UPDATE | |

**알림 연동**: `shipment_status = '출하완료'`인 건은 헤더 벨 알림에 표시 (production 제외)

**Shipment Lock**: `출하완료` 시 해당 PO의 수정/삭제가 차단됨

**사용 화면**: ShipmentsPage (통계: 출하준비/출하완료 건수), ShipmentsDetailPage

**Document 서비스 소속 근거**:
- 뷰 파일이 `src/views/documents/` 폴더에 위치
- Store가 `documentSeedRepository.js`에서 PO/ShipmentOrder와 연계하여 생성
- `useDocumentFilter()` 등 문서 전용 Composable 사용
- PO → ShipmentOrder → Shipments 문서 흐름의 연장선

---

## Cross-Service 참조 (Document → 외부)

| 외부 서비스 | 참조 테이블.컬럼 | 참조 대상 |
|-------------|-----------------|-----------|
| Auth | PI/PO/생산/출하.manager_id | → users.user_id |
| Auth | PI/PO.pi_approval_requested_by/po_approval_requested_by | → users.user_id |
| Auth | approval_requests.approval_requester_id | → users.user_id |
| Auth | approval_requests.approval_approver_id | → users.user_id |
| Auth | collections.manager_id | → users.user_id |
| Master | PI/PO/CI/PL/생산/출하.client_id | → clients.client_id |
| Master | PI/PO/CI.currency_id | → currencies.currency_id |
| Master | pi_items/po_items.item_id | → items.item_id |
| Master | collections.client_id | → clients.client_id |
| Master | collections.currency_id | → currencies.currency_id |
| Master | shipments.client_id | → clients.client_id |
