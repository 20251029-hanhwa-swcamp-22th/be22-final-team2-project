-- =============================================================================
-- Migration: CI / PL 스냅샷 필드 일회성 백필
-- 발행일:     2026-04-20
-- 대상 DB:    documents 서비스 스키마
--   - 운영(k8s) 스키마명: team2_docs
--   - 로컬 dev 스키마명:  team2_documents
-- ⚠️ 실행 전 `USE <해당 스키마>` 선행.
-- =============================================================================
-- 배경
--   CommercialInvoiceRepository.createFromPurchaseOrder / PackingListRepository
--   .createFromPurchaseOrder 의 INSERT SQL 이 과거에는 ci_code/po_id/총액/상태만
--   복사하고 ci_client_name/ci_client_address/ci_country/ci_currency_code/
--   ci_items_snapshot/ci_linked_documents 를 누락했다. 결과적으로 CI 상세 화면
--   과 PDF 가 거래처 "-", 품목 빈 row 로 표시됐고 (QA Issue #3), CI 목록 총액
--   컬럼도 currency_code 누락으로 통화 기호 없이 노출됐다 (Issue #10).
--
--   2026-04-20 에 SQL 에 스냅샷 컬럼을 추가해서 **신규 생성분은 정상화**됐지만
--   기존 레코드는 여전히 NULL 이므로 일회성 백필이 필요.
--
-- 복원 소스
--   연결 PO (purchase_orders) 의 po_client_name / po_client_address / po_country
--   / po_currency_code / po_items_snapshot / po_linked_documents. CI/PL 이 PO
--   1:1 관계이므로 단순 JOIN-UPDATE.
--
-- 제약
--   - 이미 사용자가 CI/PL 상세에서 수기로 채운 snapshot 필드는 덮어쓰지 않음
--     (COALESCE 로 기존 값 우선). empty string "" 은 NULLIF 로 NULL 취급.
--   - PL 의 pl_gross_weight 는 PO 에 소스가 없으므로 건드리지 않는다 (별도 이슈).
--
-- 롤백
--   CREATE TABLE _bak_2026_04_20b_* AS SELECT * 로 사전 스냅샷을 찍은 뒤 실행.
--   롤백 시 TRUNCATE + INSERT SELECT ... FROM _bak_* 로 복원 가능.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) 안전 스냅샷
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS _bak_2026_04_20b_commercial_invoices AS SELECT * FROM commercial_invoices;
CREATE TABLE IF NOT EXISTS _bak_2026_04_20b_packing_lists       AS SELECT * FROM packing_lists;

-- -----------------------------------------------------------------------------
-- 2) commercial_invoices 스냅샷 필드 백필
--    COALESCE 로 기존 값이 있으면 유지. ci_currency_code 는 빈 문자열도 NULL 취급.
-- -----------------------------------------------------------------------------
UPDATE commercial_invoices ci
JOIN purchase_orders po ON ci.po_id = po.po_id
SET
    ci.ci_client_name      = COALESCE(ci.ci_client_name,      po.po_client_name),
    ci.ci_client_address   = COALESCE(ci.ci_client_address,   po.po_client_address),
    ci.ci_country          = COALESCE(ci.ci_country,          po.po_country),
    ci.ci_currency_code    = COALESCE(NULLIF(ci.ci_currency_code, ''), po.po_currency_code),
    ci.ci_items_snapshot   = COALESCE(ci.ci_items_snapshot,   po.po_items_snapshot),
    ci.ci_linked_documents = COALESCE(ci.ci_linked_documents, po.po_linked_documents)
WHERE ci.ci_client_name       IS NULL
   OR ci.ci_country           IS NULL
   OR ci.ci_currency_code     IS NULL
   OR ci.ci_currency_code     = ''
   OR ci.ci_items_snapshot    IS NULL;

-- -----------------------------------------------------------------------------
-- 3) packing_lists 스냅샷 필드 백필
-- -----------------------------------------------------------------------------
UPDATE packing_lists pl
JOIN purchase_orders po ON pl.po_id = po.po_id
SET
    pl.pl_client_name      = COALESCE(pl.pl_client_name,      po.po_client_name),
    pl.pl_client_address   = COALESCE(pl.pl_client_address,   po.po_client_address),
    pl.pl_country          = COALESCE(pl.pl_country,          po.po_country),
    pl.pl_items_snapshot   = COALESCE(pl.pl_items_snapshot,   po.po_items_snapshot),
    pl.pl_linked_documents = COALESCE(pl.pl_linked_documents, po.po_linked_documents)
WHERE pl.pl_client_name    IS NULL
   OR pl.pl_country        IS NULL
   OR pl.pl_items_snapshot IS NULL;

-- -----------------------------------------------------------------------------
-- 4) 검증 쿼리 (주석 해제 실행)
-- -----------------------------------------------------------------------------
-- 4-a) 백필 후 여전히 NULL 인 CI (있으면 linked PO 가 NULL 이거나 orphan)
-- SELECT ci.ci_code, ci.ci_client_name, ci.ci_country, ci.ci_currency_code,
--        (ci.ci_items_snapshot IS NULL) AS items_null
-- FROM commercial_invoices ci
-- WHERE ci.ci_client_name IS NULL OR ci.ci_country IS NULL
--    OR ci.ci_currency_code IS NULL OR ci.ci_currency_code = ''
--    OR ci.ci_items_snapshot IS NULL;

-- 4-b) PL 동일
-- SELECT pl.pl_code, pl.pl_client_name, pl.pl_country,
--        (pl.pl_items_snapshot IS NULL) AS items_null
-- FROM packing_lists pl
-- WHERE pl.pl_client_name IS NULL OR pl.pl_country IS NULL
--    OR pl.pl_items_snapshot IS NULL;
