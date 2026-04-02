-- 스키마 4개 생성 (컨테이너 최초 기동 시 자동 실행)
CREATE DATABASE IF NOT EXISTS team2_auth     CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS team2_master   CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS team2_activity CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS team2_docs     CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 개발용 사용자 권한
GRANT ALL PRIVILEGES ON team2_auth.*     TO 'team2'@'%';
GRANT ALL PRIVILEGES ON team2_master.*   TO 'team2'@'%';
GRANT ALL PRIVILEGES ON team2_activity.* TO 'team2'@'%';
GRANT ALL PRIVILEGES ON team2_docs.*     TO 'team2'@'%';
FLUSH PRIVILEGES;
