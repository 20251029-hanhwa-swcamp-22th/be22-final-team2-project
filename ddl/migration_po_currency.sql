-- =============================================================================
-- Migration: PO / CI / Collection 단가·합계 외화 기준 정합화
-- 발행일:     2026-04-20
-- 대상 DB:    documents 서비스 스키마
--   - 운영(k8s) 스키마명: team2_docs
--   - 로컬 dev 스키마명: team2_documents (프로젝트 표기 관례)
-- ⚠️ 실행 전 반드시 오퍼레이터가 `USE <해당 스키마>;` 를 선행 수행할 것.
--    (스키마 이름을 하드코드하지 않기 위해 파일 본문에는 USE 문을 두지 않는다.)
-- =============================================================================
-- 배경
--   PI 는 생성 시점에 KRW → 거래처 통화로 변환하여 pi_items / pi_total_amount 를
--   거래처 통화(foreign currency) 기준으로 저장한다 (ExchangeRateService.convertFromKrw).
--   반면 PO 는 그 동안 프론트에서 "foreign → KRW" 역변환을 거쳐 KRW 값 그대로 저장되었다.
--   화면·PDF 는 이 KRW 값을 거래처 통화 기호($, €, ¥ 등)만 붙여서 렌더링했기에
--   "100,000원 주문인데 $100,000 로 노출" 되는 **돈 표시 오류**가 발생했다.
--
--   정상화 이후 (프론트 POPage.buildCreatePayload 에서 toKrw 제거) PO / CI / Collection
--   은 모두 거래처 통화 기준으로 저장된다. 이 마이그레이션은 **기존에 KRW 로 저장된**
--   운영 데이터를 거래처 통화 값으로 되돌린다.
--
-- 복원 소스
--   모든 PO 는 pi_code 를 참조하는 PI 를 가지며(PurchaseOrderCreationService.validateLinkedProformaInvoice),
--   PI items 는 이미 거래처 통화 기준으로 보관돼 있다. 따라서 matching item_id 기준으로
--   PI 의 단가·금액을 복사하면 된다.
--
-- 제약
--   - PO 생성 이후 담당자가 품목을 수기로 수정한 이력이 있으면 그 수정분은 사라진다
--     (PI 값으로 덮어쓰기). 현 운영 환경에서 PO items 수기 편집이 드문 점을 전제.
--   - PO 에 item_id 가 NULL 인 라인은 매칭 실패 → 별도 처리 필요(수기 검토 항목).
--
-- 실행 순서
--   1) 안전 스냅샷 테이블 생성
--   2) po_items 단가·금액 복원 (from pi_items)
--   3) purchase_orders.po_total_amount 재집계
--   4) purchase_orders.po_items_snapshot JSON 재생성
--   5) commercial_invoices.ci_total_amount 동기화
--   6) collections.collection_sales_amount 동기화
--   7) 검증 쿼리 (주석 해제하여 수동 확인)
--
-- 롤백
--   각 단계는 _bak_2026_04_20_* 스냅샷으로부터 복원 가능:
--     TRUNCATE po_items; INSERT INTO po_items SELECT * FROM _bak_2026_04_20_po_items;
--     UPDATE purchase_orders po JOIN _bak_2026_04_20_purchase_orders b USING (po_id)
--       SET po.po_total_amount = b.po_total_amount, po.po_items_snapshot = b.po_items_snapshot;
--     등등.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) 안전 스냅샷 (IF NOT EXISTS 로 중복 실행 안전)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS _bak_2026_04_20_po_items            AS SELECT * FROM po_items;
CREATE TABLE IF NOT EXISTS _bak_2026_04_20_purchase_orders     AS SELECT * FROM purchase_orders;
CREATE TABLE IF NOT EXISTS _bak_2026_04_20_commercial_invoices AS SELECT * FROM commercial_invoices;
CREATE TABLE IF NOT EXISTS _bak_2026_04_20_collections         AS SELECT * FROM collections;

-- -----------------------------------------------------------------------------
-- 2) po_items 단가·금액 → 연결 PI 의 외화 기준 값 복사 (item_id 매칭)
--    * 외화 PO 만 대상. KRW PO 는 원래부터 KRW 저장이 맞으므로 건너뜀.
-- -----------------------------------------------------------------------------
UPDATE po_items poi
JOIN purchase_orders  po ON poi.po_id = po.po_id
JOIN proforma_invoices pi ON po.pi_id = pi.pi_code
JOIN pi_items pii ON pii.pi_id = pi.pi_id
                 AND pii.item_id = poi.item_id
SET poi.po_item_unit_price = pii.pi_item_unit_price,
    poi.po_item_amount     = pii.pi_item_amount
WHERE po.po_currency_code IS NOT NULL
  AND UPPER(po.po_currency_code) <> 'KRW';

-- -----------------------------------------------------------------------------
-- 3) purchase_orders.po_total_amount 재집계 (sum of po_items.amount)
-- -----------------------------------------------------------------------------
UPDATE purchase_orders po
SET po.po_total_amount = COALESCE(
    (SELECT SUM(poi.po_item_amount) FROM po_items poi WHERE poi.po_id = po.po_id),
    0
)
WHERE po.po_currency_code IS NOT NULL
  AND UPPER(po.po_currency_code) <> 'KRW';

-- -----------------------------------------------------------------------------
-- 4) purchase_orders.po_items_snapshot JSON 재생성 (PDF / 상세 fallback 용)
--    MariaDB 10.5+ 기준 JSON_ARRAYAGG 사용. ORDER BY 로 라인 순서 보존.
-- -----------------------------------------------------------------------------
UPDATE purchase_orders po
SET po.po_items_snapshot = COALESCE(
    (
        SELECT JSON_ARRAYAGG(
                   JSON_OBJECT(
                       'itemId',    COALESCE(poi.item_id, 0),
                       'itemName',  poi.po_item_name,
                       'quantity',  poi.po_item_qty,
                       'unit',      COALESCE(poi.po_item_unit, ''),
                       'unitPrice', poi.po_item_unit_price,
                       'amount',    poi.po_item_amount,
                       'remark',    COALESCE(poi.po_item_remark, '')
                   )
               )
        FROM po_items poi
        WHERE poi.po_id = po.po_id
    ),
    JSON_ARRAY()
)
WHERE po.po_currency_code IS NOT NULL
  AND UPPER(po.po_currency_code) <> 'KRW';

-- -----------------------------------------------------------------------------
-- 5) commercial_invoices.ci_total_amount = 연결 PO.total_amount
--    CI 는 createFromPurchaseOrder SQL 이 po_total_amount 를 그대로 복사하므로
--    PO 가 바뀌었으면 CI 도 동일하게 맞춰준다.
-- -----------------------------------------------------------------------------
UPDATE commercial_invoices ci
JOIN purchase_orders po ON ci.po_id = po.po_id
SET ci.ci_total_amount = po.po_total_amount
WHERE po.po_currency_code IS NOT NULL
  AND UPPER(po.po_currency_code) <> 'KRW';

-- -----------------------------------------------------------------------------
-- 6) collections.collection_sales_amount = 연결 PO.total_amount
--    수금 집계 / 대시보드 매출 / 미수금 계산의 기준 값.
-- -----------------------------------------------------------------------------
UPDATE collections c
JOIN purchase_orders po ON c.po_id = po.po_id
SET c.collection_sales_amount = po.po_total_amount
WHERE po.po_currency_code IS NOT NULL
  AND UPPER(po.po_currency_code) <> 'KRW';

-- -----------------------------------------------------------------------------
-- 7) 검증 쿼리 (수동 확인용 — 주석 해제하여 실행)
-- -----------------------------------------------------------------------------
-- 7-a) item_id 매칭 실패 (NULL) PO items — 수기 검토 대상
-- SELECT po.po_code, poi.po_item_id, poi.po_item_name, poi.po_item_unit_price
-- FROM po_items poi
-- JOIN purchase_orders po ON poi.po_id = po.po_id
-- WHERE poi.item_id IS NULL
--   AND UPPER(po.po_currency_code) <> 'KRW';

-- 7-b) PO ↔ PI 총액 비교 (불일치 시 수기 확인)
-- SELECT po.po_code, po.po_currency_code, po.po_total_amount, pi.pi_total_amount
-- FROM purchase_orders po
-- JOIN proforma_invoices pi ON po.pi_id = pi.pi_code
-- WHERE UPPER(po.po_currency_code) <> 'KRW'
--   AND po.po_total_amount <> pi.pi_total_amount;

-- 7-c) Collection ↔ PO 총액 일치 확인
-- SELECT c.collection_id, po.po_code, c.collection_sales_amount, po.po_total_amount
-- FROM collections c
-- JOIN purchase_orders po ON c.po_id = po.po_id
-- WHERE UPPER(po.po_currency_code) <> 'KRW'
--   AND c.collection_sales_amount <> po.po_total_amount;
