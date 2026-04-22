-- ============================================================
-- Positions 중복 정리 + 팀장/팀원 고정 제약
-- ============================================================
-- 대상 DB: team2_auth
-- 목적:
--   1) data.sql 반복 실행/수동 생성으로 누적된 positions 중복 제거
--   2) 사용자의 position_id 를 팀장(1) / 팀원(2) 로 재매핑
--   3) position_name unique 제약 추가로 재발 방지
-- 재실행 가능(idempotent).
-- ============================================================

USE team2_auth;

SET FOREIGN_KEY_CHECKS = 0;

-- 충돌을 피하기 위해 임시 고정 ID/임시 이름으로 canonical row 생성.
-- 이미 uk_position_name 이 있는 DB에서도 기존 '팀장'/'팀원' unique 와 부딪히지 않게 한다.
INSERT INTO positions (position_id, position_name, position_level, created_at) VALUES
  (900001, '__tmp_team_manager__', 1, NOW()),
  (900002, '__tmp_team_member__', 3, NOW())
ON DUPLICATE KEY UPDATE
  position_name = VALUES(position_name),
  position_level = VALUES(position_level);

-- 기존 직급명 기반으로 사용자 직급 재매핑.
-- 팀장 계열: 팀장/부장/이사/대표이사, 그 외는 팀원.
UPDATE users u
LEFT JOIN positions p ON u.position_id = p.position_id
SET u.position_id = CASE
  WHEN p.position_name IN ('팀장', '부장', '이사', '대표이사') THEN 900001
  ELSE 900002
END;

-- canonical 임시 행 외 positions 정리.
DELETE FROM positions WHERE position_id NOT IN (900001, 900002);

-- 최종 ID를 1/2로 정규화.
UPDATE users SET position_id = 1 WHERE position_id = 900001;
UPDATE positions SET position_id = 1 WHERE position_id = 900001;
UPDATE users SET position_id = 2 WHERE position_id = 900002;
UPDATE positions SET position_id = 2 WHERE position_id = 900002;

UPDATE positions
SET position_name = CASE position_id WHEN 1 THEN '팀장' WHEN 2 THEN '팀원' END,
    position_level = CASE position_id WHEN 1 THEN 1 WHEN 2 THEN 3 END
WHERE position_id IN (1, 2);

SET FOREIGN_KEY_CHECKS = 1;

-- 재발 방지: position_name unique index 없으면 추가.
SET @position_index_exists := (
  SELECT COUNT(*)
  FROM information_schema.statistics
  WHERE table_schema = DATABASE()
    AND table_name = 'positions'
    AND index_name = 'uk_position_name'
);

SET @position_index_sql := IF(
  @position_index_exists = 0,
  'ALTER TABLE positions ADD CONSTRAINT uk_position_name UNIQUE (position_name)',
  'SELECT ''uk_position_name already exists'''
);

PREPARE stmt FROM @position_index_sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

ALTER TABLE positions AUTO_INCREMENT = 3;

-- 사후 확인:
-- SELECT position_id, position_name, position_level FROM positions ORDER BY position_id;
-- SELECT position_id, COUNT(*) FROM users GROUP BY position_id ORDER BY position_id;
