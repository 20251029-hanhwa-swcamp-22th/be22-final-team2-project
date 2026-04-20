-- =============================================================================
-- Migration: stale 결재 메타데이터 cleanup (QA Issue B2)
-- 발행일:     2026-04-20
-- 대상 DB:    documents 서비스 스키마 (team2_docs / team2_documents)
-- ⚠️ 실행 전 USE <schema> 선행.
-- =============================================================================
-- 배경
--   Issue #5 에서 ApprovalDocumentMetadataService.markCancelled 추가해 **향후**
--   결재 취소는 PI/PO 의 approval_status / request_status / approval_action /
--   approval_requested_by / approval_requested_at 컬럼을 모두 비운다.
--
--   그러나 fix 이전에 취소된 이력(예: PI260024) 은 ApprovalRequest 엔티티만
--   삭제되고 문서 컬럼이 남아있어 결재 요청함에 "결재자: 미지정" 으로 계속
--   노출된다 (QA B2).
--
-- 정책
--   approval_requests 테이블에 더 이상 PENDING row 가 없는데 문서 컬럼에만
--   `pi_approval_status='대기'` / `pi_request_status` 가 남아있는 orphan 을
--   cleanup. status=approved/rejected 는 건드리지 않음 (결재 이력은 보존).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) 백업 스냅샷
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS _bak_2026_04_20c_pi_approval_columns AS
SELECT pi_id, pi_code, pi_approval_status, pi_request_status, pi_approval_action,
       pi_approval_requested_by, pi_approval_requested_at
FROM proforma_invoices
WHERE pi_approval_status IS NOT NULL OR pi_request_status IS NOT NULL;

CREATE TABLE IF NOT EXISTS _bak_2026_04_20c_po_approval_columns AS
SELECT po_id, po_code, po_approval_status, po_request_status, po_approval_action,
       po_approval_requested_by, po_approval_requested_at
FROM purchase_orders
WHERE po_approval_status IS NOT NULL OR po_request_status IS NOT NULL;

-- -----------------------------------------------------------------------------
-- 2) PI stale cleanup — pi_approval_status='대기' (혹은 관련 메타) 가 있지만
--    해당 PI 에 대해 PENDING 상태의 approval_request 가 없는 경우
-- -----------------------------------------------------------------------------
UPDATE proforma_invoices pi
LEFT JOIN approval_requests ar
  ON ar.approval_document_type = 'PI'
 AND ar.approval_document_id = pi.pi_code
 AND ar.approval_status = 'pending'
SET
    pi.pi_approval_status       = NULL,
    pi.pi_request_status        = NULL,
    pi.pi_approval_action       = NULL,
    pi.pi_approval_requested_by = NULL,
    pi.pi_approval_requested_at = NULL
WHERE pi.pi_approval_status = '대기'
  AND ar.approval_request_id IS NULL;

-- -----------------------------------------------------------------------------
-- 3) PO stale cleanup (same pattern)
-- -----------------------------------------------------------------------------
UPDATE purchase_orders po
LEFT JOIN approval_requests ar
  ON ar.approval_document_type = 'PO'
 AND ar.approval_document_id = po.po_code
 AND ar.approval_status = 'pending'
SET
    po.po_approval_status       = NULL,
    po.po_request_status        = NULL,
    po.po_approval_action       = NULL,
    po.po_approval_requested_by = NULL,
    po.po_approval_requested_at = NULL
WHERE po.po_approval_status = '대기'
  AND ar.approval_request_id IS NULL;

-- -----------------------------------------------------------------------------
-- 4) 검증 (주석 해제)
-- -----------------------------------------------------------------------------
-- 4-a) 여전히 stale 남아있는지 — 0 건이어야
-- SELECT pi.pi_code, pi.pi_approval_status, pi.pi_request_status
-- FROM proforma_invoices pi
-- LEFT JOIN approval_requests ar ON ar.approval_document_type='PI'
--   AND ar.approval_document_id=pi.pi_code AND ar.approval_status='pending'
-- WHERE pi.pi_approval_status='대기' AND ar.approval_request_id IS NULL;

-- 4-b) PO 동일
-- SELECT po.po_code, po.po_approval_status, po.po_request_status
-- FROM purchase_orders po
-- LEFT JOIN approval_requests ar ON ar.approval_document_type='PO'
--   AND ar.approval_document_id=po.po_code AND ar.approval_status='pending'
-- WHERE po.po_approval_status='대기' AND ar.approval_request_id IS NULL;
