-- ============================================================
-- Auth Service DDL
-- 서비스 설명: 사용자 인증/인가 관련 테이블
--   - positions: 직급 마스터
--   - departments: 부서 마스터
--   - users: 사용자 계정 (로그인, 권한, 소속 정보)
--   - company: 회사 기본 정보
--   - refresh_tokens: JWT 리프레시 토큰 관리
-- Engine: InnoDB | Charset: utf8mb4_unicode_ci
-- ============================================================

-- 의존성 역순으로 DROP
DROP TABLE IF EXISTS refresh_tokens;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS company;
DROP TABLE IF EXISTS departments;
DROP TABLE IF EXISTS positions;

-- ------------------------------------------------------------
-- 1. positions (직급)
-- ------------------------------------------------------------
CREATE TABLE positions (
    position_id    INT          NOT NULL AUTO_INCREMENT,
    position_name  VARCHAR(50)  NOT NULL,
    position_level INT          NOT NULL,
    created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (position_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 2. departments (부서)
-- ------------------------------------------------------------
CREATE TABLE departments (
    department_id   INT          NOT NULL AUTO_INCREMENT,
    department_name VARCHAR(100) NOT NULL,
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (department_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 3. users (사용자)
-- ------------------------------------------------------------
CREATE TABLE users (
    user_id       INT                            NOT NULL AUTO_INCREMENT,
    employee_no   VARCHAR(20)                    NOT NULL,
    user_name     VARCHAR(100)                   NOT NULL,
    user_email    VARCHAR(255)                   NOT NULL,
    user_pw       VARCHAR(255)                   NOT NULL COMMENT 'bcrypt hash',
    user_role     ENUM('admin','sales','production','shipping') NOT NULL DEFAULT 'sales',
    department_id INT                            NULL,
    position_id   INT                            NULL,
    user_status   ENUM('active','on_leave','retired') NOT NULL DEFAULT 'active',
    created_at    TIMESTAMP                      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP                      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id),
    UNIQUE KEY uk_users_employee_no (employee_no),
    UNIQUE KEY uk_users_user_email (user_email),
    INDEX idx_users_user_email (user_email),
    INDEX idx_users_employee_no (employee_no),
    INDEX idx_users_department_id (department_id),
    INDEX idx_users_position_id (position_id),
    CONSTRAINT fk_users_department_id FOREIGN KEY (department_id) REFERENCES departments (department_id),
    CONSTRAINT fk_users_position_id   FOREIGN KEY (position_id)   REFERENCES positions (position_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 4. company (회사정보)
-- ------------------------------------------------------------
CREATE TABLE company (
    company_id             INT          NOT NULL AUTO_INCREMENT,
    company_name           VARCHAR(200) NOT NULL,
    company_address_en     VARCHAR(500) NULL,
    company_address_kr     VARCHAR(500) NULL,
    company_tel            VARCHAR(50)  NULL,
    company_fax            VARCHAR(50)  NULL,
    company_email          VARCHAR(255) NULL,
    company_website        VARCHAR(255) NULL,
    company_seal_image_url VARCHAR(500) NULL,
    updated_at             TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (company_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 5. refresh_tokens (리프레시 토큰)
-- ------------------------------------------------------------
CREATE TABLE refresh_tokens (
    refresh_token_id INT          NOT NULL AUTO_INCREMENT,
    user_id          INT          NOT NULL,
    token_value      VARCHAR(512) NOT NULL,
    token_expires_at DATETIME     NOT NULL,
    created_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (refresh_token_id),
    INDEX idx_refresh_tokens_user_id (user_id),
    INDEX idx_refresh_tokens_token_value (token_value(255)),
    CONSTRAINT fk_refresh_tokens_user_id FOREIGN KEY (user_id) REFERENCES users (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
