-- =============================================================================
-- Migration: po_items 에 po_item_weight 컬럼 추가 + 기존 레코드 master 기반 backfill
-- 발행일:     2026-04-20
-- 대상 DB:    documents 서비스 스키마 (team2_docs / team2_documents)
-- ⚠️ 실행 전 USE <schema> 선행.
-- =============================================================================
-- 배경
--   Issue D — PL 총중량(pl_gross_weight) 을 생성 시점에 자동 계산하기 위해
--   po_items 에 PO 생성 당시의 master.items.item_weight(kg) 스냅샷을 컬럼으로 갖는다.
--   ddl-auto=update 환경에서는 JPA 가 자동 추가하지만 prod validate 환경에선
--   ALTER 를 명시적으로 실행해야 backend rollout 가능.
--
-- 백필
--   기존 po_items 는 weight 미기록 → master.items.item_weight 를 item_id 매칭으로
--   복사. master 가 cross-schema 이므로 team2_master.items 참조.
--   item_id 가 NULL 인 과거 row 나 master 에 매칭 안 되는 경우는 NULL 유지.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) 컬럼 추가 (존재하면 skip)
-- -----------------------------------------------------------------------------
SET @has_col = (SELECT COUNT(*) FROM information_schema.columns
                WHERE table_schema = DATABASE() AND table_name = 'po_items'
                  AND column_name = 'po_item_weight');
SET @sql = IF(@has_col = 0,
              'ALTER TABLE po_items ADD COLUMN po_item_weight DECIMAL(10,3) NULL COMMENT ''개당 중량 kg 스냅샷 (PL 총중량 집계 소스)''',
              'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- -----------------------------------------------------------------------------
-- 2) master.items.item_weight 를 item_id 매칭으로 스냅샷 복사
-- -----------------------------------------------------------------------------
UPDATE po_items poi
JOIN team2_master.items mi ON mi.item_id = poi.item_id
SET poi.po_item_weight = mi.item_weight
WHERE poi.po_item_weight IS NULL
  AND mi.item_weight IS NOT NULL;

-- -----------------------------------------------------------------------------
-- 3) 기존 PL 의 pl_gross_weight 재계산 (NULL 인 건만 대상)
--    PO 당 SUM(qty × weight) 로 업데이트.
-- -----------------------------------------------------------------------------
UPDATE packing_lists pl
JOIN (
    SELECT po.po_id,
           ROUND(COALESCE(SUM(poi.po_item_qty * COALESCE(poi.po_item_weight, 0)), 0), 2) AS gross
    FROM purchase_orders po
    LEFT JOIN po_items poi ON poi.po_id = po.po_id
    GROUP BY po.po_id
) agg ON agg.po_id = pl.po_id
SET pl.pl_gross_weight = agg.gross
WHERE pl.pl_gross_weight IS NULL
  AND agg.gross > 0;

-- -----------------------------------------------------------------------------
-- 4) 검증 (주석 해제)
-- -----------------------------------------------------------------------------
-- 4-a) 백필 후에도 NULL 인 po_items (master 에 item_id 없는 경우)
-- SELECT poi.po_item_id, poi.item_id, poi.po_item_name, po.po_code
-- FROM po_items poi JOIN purchase_orders po ON po.po_id = poi.po_id
-- WHERE poi.po_item_weight IS NULL;

-- 4-b) 업데이트된 PL 총중량 샘플
-- SELECT pl.pl_code, pl.pl_gross_weight, po.po_code
-- FROM packing_lists pl JOIN purchase_orders po ON pl.po_id = po.po_id
-- ORDER BY pl.pl_id DESC LIMIT 5;
