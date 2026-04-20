-- ============================================================
-- Positions 단순화: 7개 직급 → 팀장(1)/팀원(2) 2개
-- ============================================================
-- 정책: 직급은 "팀장 / 팀원" 만 사용.
-- 매핑 규칙(운영 DB 기준):
--   팀장 ← position_name ∈ { '부장', '이사', '대표이사', '팀장' }
--   팀원 ← 그 외 모든 직급 (사원, 대리, 과장, 차장, 팀원 등)
-- 기준을 position_level 이 아니라 **position_name** 으로 잡은 이유:
--   seed_dml.sql 은 level=1 을 '팀장급' 으로 썼지만 운영 DB 는 직급 서열을
--   그대로 level 에 담아둔 경우가 있어(1=사원 … 7=대표이사) level 기준으로
--   분기하면 역전되어 사원이 팀장으로 승격되는 치명적 회귀가 발생.
--   name 은 양쪽 DB 에서 일관되므로 name 기준이 안전하다.
--
-- 실행 대상: team2_auth 운영 DB. 한 번만 수행(재실행 idempotent).
-- 선행 조건: users.position_id 의 FK 대상이 positions.position_id.
-- 롤백 필요 시: migration 전 positions 테이블 + users.position_id 를 덤프해 두세요.
--
-- 실행 예:
--   mysql -h <host> -u <user> -p team2_auth < migration_positions_simplify.sql
-- ============================================================

USE team2_auth;

-- ============================================================
-- 사전 검증 쿼리 (A/B/C) — 실행 전 반드시 결과 확인
-- ============================================================

-- A. 현재 positions 현황
-- SELECT position_id, position_name, position_level FROM positions ORDER BY position_id;

-- B. 매핑 후 각 사용자의 예상 position
-- SELECT u.user_id, u.user_name, u.team_id, p.position_name AS before_name,
--        CASE WHEN p.position_name IN ('부장','이사','대표이사','팀장') THEN '팀장' ELSE '팀원' END AS after_role
-- FROM users u JOIN positions p ON u.position_id = p.position_id
-- ORDER BY u.team_id, after_role DESC, u.user_id;

-- C. 마이그레이션 후 "팀장 0명" 이 될 팀 식별
-- SELECT t.team_id, t.team_name,
--        SUM(CASE WHEN p.position_name IN ('부장','이사','대표이사','팀장') THEN 1 ELSE 0 END) AS 팀장_수
-- FROM teams t
-- LEFT JOIN users u ON u.team_id = t.team_id AND u.user_status = 'active'
-- LEFT JOIN positions p ON u.position_id = p.position_id
-- GROUP BY t.team_id, t.team_name
-- HAVING 팀장_수 = 0;
-- 팀장 부재 팀이 있으면 사전에 특정 사용자의 position_name 을 '부장' 등으로
-- 수동 UPDATE 한 뒤 마이그레이션을 돌리거나, 마이그레이션 후 정상화 UPDATE 를
-- 별도 수행하세요. (결재 승인자 부재로 PI/PO 등록이 막힘)

SET FOREIGN_KEY_CHECKS = 0;

-- 1) 임시 id(101/102) 로 새 position 추가. 기존 1-99 와 충돌 회피.
INSERT INTO positions (position_id, position_name, position_level, created_at) VALUES
  (101, '팀장', 1, NOW()),
  (102, '팀원', 3, NOW())
ON DUPLICATE KEY UPDATE
  position_name = VALUES(position_name),
  position_level = VALUES(position_level);

-- 2) users.position_id 재매핑: position_name 기반.
--    '부장','이사','대표이사','팀장' → 101(팀장), 그 외 → 102(팀원).
--    이미 '팀장' 이름으로 저장된 레코드도 포함시켜 재실행 idempotency 보장.
UPDATE users u
JOIN positions p ON u.position_id = p.position_id
SET u.position_id = CASE
  WHEN p.position_name IN ('부장', '이사', '대표이사', '팀장') THEN 101
  ELSE 102
END
WHERE p.position_id BETWEEN 1 AND 99;

-- 3) 기존 position 삭제 (1-99 범위).
DELETE FROM positions WHERE position_id BETWEEN 1 AND 99;

-- 4) id 를 1, 2 로 정규화 (users 먼저 옮기고 positions 옮김).
UPDATE users SET position_id = 1 WHERE position_id = 101;
UPDATE positions SET position_id = 1 WHERE position_id = 101;
UPDATE users SET position_id = 2 WHERE position_id = 102;
UPDATE positions SET position_id = 2 WHERE position_id = 102;

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- 사후 검증 쿼리 (마이그레이션 후 수동 실행)
-- ============================================================
--   SELECT * FROM positions ORDER BY position_id;
--     → (1,'팀장',1), (2,'팀원',3) 두 행만 남아야 함
--   SELECT position_id, COUNT(*) FROM users GROUP BY position_id ORDER BY position_id;
--     → position_id 가 1 또는 2 두 값만 나와야 함
--   SELECT t.team_id, t.team_name,
--          SUM(CASE WHEN u.position_id = 1 THEN 1 ELSE 0 END) AS 팀장_수
--   FROM teams t LEFT JOIN users u ON u.team_id = t.team_id AND u.user_status = 'active'
--   GROUP BY t.team_id, t.team_name
--   HAVING 팀장_수 = 0;
--     → 팀장 부재 팀이 남아있으면 즉시 수동 승격:
--       UPDATE users SET position_id = 1 WHERE user_id = <대상>;
