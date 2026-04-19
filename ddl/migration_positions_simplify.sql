-- ============================================================
-- Positions 단순화: 7개 직급 → 팀장(1)/팀원(2) 2개
-- ============================================================
-- 정책: 직급은 "팀장 / 팀원" 만 사용. 기존 lvl1(부장·이사·대표이사) 은 모두
-- 팀장으로, 나머지(사원·대리·과장·차장) 는 팀원으로 재매핑.
--
-- 실행 대상: team2_auth 운영 DB. 한 번만 수행.
-- 선행 조건: users.position_id 의 FK 대상이 positions.position_id.
-- 롤백 필요 시: migration 전 positions 테이블 전체 + users.position_id 를 백업해 두세요.
--
-- 실행 예:
--   mysql -h <host> -u <user> -p team2_auth < migration_positions_simplify.sql
-- ============================================================

USE team2_auth;

SET FOREIGN_KEY_CHECKS = 0;

-- 1) 임시 id(101/102) 로 새 position 추가. 기존 1-7 과 충돌 안 하게 분리.
INSERT INTO positions (position_id, position_name, position_level, created_at) VALUES
  (101, '팀장', 1, NOW()),
  (102, '팀원', 3, NOW())
ON DUPLICATE KEY UPDATE
  position_name = VALUES(position_name),
  position_level = VALUES(position_level);

-- 2) users.position_id 재매핑: level=1 → 101(팀장), 그 외 → 102(팀원).
UPDATE users u
JOIN positions p ON u.position_id = p.position_id
SET u.position_id = CASE WHEN p.position_level = 1 THEN 101 ELSE 102 END
WHERE p.position_id BETWEEN 1 AND 99;

-- 3) 기존 position 7건 삭제.
DELETE FROM positions WHERE position_id BETWEEN 1 AND 99;

-- 4) id 를 1, 2 로 정규화 (users 먼저 옮기고 positions 옮김).
UPDATE users SET position_id = 1 WHERE position_id = 101;
UPDATE positions SET position_id = 1 WHERE position_id = 101;
UPDATE users SET position_id = 2 WHERE position_id = 102;
UPDATE positions SET position_id = 2 WHERE position_id = 102;

SET FOREIGN_KEY_CHECKS = 1;

-- 검증 쿼리 (마이그레이션 후 수동 실행):
--   SELECT * FROM positions ORDER BY position_id;
--     → (1,'팀장',1), (2,'팀원',3) 두 행만 남아야 함
--   SELECT position_id, COUNT(*) FROM users GROUP BY position_id;
--     → position_id 가 1 또는 2 두 값만 나와야 함
