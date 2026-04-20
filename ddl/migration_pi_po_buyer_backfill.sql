-- =============================================================================
-- Migration: PI / PO buyer_name 컬럼 추가 + 기존 레코드 백필
-- 발행일:     2026-04-20
-- 대상 DB:    documents 서비스 스키마 (team2_docs / team2_documents)
-- ⚠️ 실행 전 USE <schema> 선행.
-- =============================================================================
-- 배경
--   Issue C / #14 — PI·PO 에 buyer 컬럼이 없어 PDF / 결재 모달에서 "바이어: -" 로
--   노출. ddl-auto=update 는 이미 컬럼을 추가했을 수 있으나 validate 환경에서는
--   안 되므로 명시적 ALTER 를 함께 제공.
--
--   신규 생성분은 프론트 payload 에 buyerName 이 포함돼 자동 저장됨. 기존 레코드
--   는 NULL 이므로 master.buyers 를 참조한 휴리스틱 백필.
--
-- 백필 소스
--   team2_master.buyers 의 각 거래처 첫 바이어(buyer_id 오름차순). 정확한 "당시
--   선택된 바이어" 는 알 수 없으므로 근사값. 사용자가 필요 시 PI/PO 상세에서 수정.
--
-- 실행 순서
--   1) ALTER TABLE (컬럼이 없으면 추가)
--   2) 기존 레코드 백필 (buyer_name IS NULL 만)
--   3) 검증
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) 컬럼 추가 (존재하면 skip)
-- -----------------------------------------------------------------------------
SET @has_pi_col = (SELECT COUNT(*) FROM information_schema.columns
                   WHERE table_schema = DATABASE() AND table_name = 'proforma_invoices'
                     AND column_name = 'pi_buyer_name');
SET @sql_pi = IF(@has_pi_col = 0,
                 'ALTER TABLE proforma_invoices ADD COLUMN pi_buyer_name VARCHAR(200) NULL COMMENT ''바이어 이름 (PIC)''',
                 'SELECT 1');
PREPARE stmt FROM @sql_pi; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_po_col = (SELECT COUNT(*) FROM information_schema.columns
                   WHERE table_schema = DATABASE() AND table_name = 'purchase_orders'
                     AND column_name = 'po_buyer_name');
SET @sql_po = IF(@has_po_col = 0,
                 'ALTER TABLE purchase_orders ADD COLUMN po_buyer_name VARCHAR(200) NULL COMMENT ''바이어 이름 (PIC)''',
                 'SELECT 1');
PREPARE stmt FROM @sql_po; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- -----------------------------------------------------------------------------
-- 2) 백필 — master.buyers 의 각 거래처 첫 바이어 (buyer_id 오름차순) 로 추정
--    CROSS-DB 조회: team2_master.buyers 에 접근. documents/master 가 같은 MariaDB
--    인스턴스에 있다고 가정. 아니면 별도 export→import 필요.
-- -----------------------------------------------------------------------------
UPDATE proforma_invoices pi
JOIN (
    SELECT b.client_id, MIN(b.buyer_id) AS first_buyer_id
    FROM team2_master.buyers b
    GROUP BY b.client_id
) firstb ON firstb.client_id = pi.client_id
JOIN team2_master.buyers b2 ON b2.buyer_id = firstb.first_buyer_id
SET pi.pi_buyer_name = b2.buyer_name
WHERE pi.pi_buyer_name IS NULL;

UPDATE purchase_orders po
JOIN proforma_invoices pi ON po.pi_id = pi.pi_code
SET po.po_buyer_name = pi.pi_buyer_name
WHERE po.po_buyer_name IS NULL
  AND pi.pi_buyer_name IS NOT NULL;

-- PO 중 PI 가 없거나 PI 의 buyer_name 도 비어있는 경우는 master fallback
UPDATE purchase_orders po
JOIN (
    SELECT b.client_id, MIN(b.buyer_id) AS first_buyer_id
    FROM team2_master.buyers b
    GROUP BY b.client_id
) firstb ON firstb.client_id = po.client_id
JOIN team2_master.buyers b2 ON b2.buyer_id = firstb.first_buyer_id
SET po.po_buyer_name = b2.buyer_name
WHERE po.po_buyer_name IS NULL;

-- CI / PL 의 ci_buyer / pl_buyer 도 동일 근사 (컬럼은 이미 존재)
UPDATE commercial_invoices ci
JOIN purchase_orders po ON ci.po_id = po.po_id
SET ci.ci_buyer = po.po_buyer_name
WHERE (ci.ci_buyer IS NULL OR ci.ci_buyer = '')
  AND po.po_buyer_name IS NOT NULL;

UPDATE packing_lists pl
JOIN purchase_orders po ON pl.po_id = po.po_id
SET pl.pl_buyer = po.po_buyer_name
WHERE (pl.pl_buyer IS NULL OR pl.pl_buyer = '')
  AND po.po_buyer_name IS NOT NULL;

-- -----------------------------------------------------------------------------
-- 3) 검증 (주석 해제 실행)
-- -----------------------------------------------------------------------------
-- 3-a) 여전히 buyer 가 비어있는 PI/PO (거래처 master.buyers 에 바이어 행이 없는 경우)
-- SELECT pi_code, client_id, pi_buyer_name FROM proforma_invoices WHERE pi_buyer_name IS NULL;
-- SELECT po_code, client_id, po_buyer_name FROM purchase_orders WHERE po_buyer_name IS NULL;

-- 3-b) CI / PL 전파 확인
-- SELECT ci.ci_code, ci.ci_buyer, po.po_buyer_name FROM commercial_invoices ci
--   JOIN purchase_orders po ON ci.po_id = po.po_id
--   WHERE ci.ci_buyer <> po.po_buyer_name OR ci.ci_buyer IS NULL;
