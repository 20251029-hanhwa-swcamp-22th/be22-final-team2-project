-- ============================================================
-- Master Service DDL (MariaDB)
--
-- 기준정보 서비스: 국가, 인코텀즈, 통화, 항구, 결제조건, 거래처, 품목, 거래처 담당자
-- ============================================================

-- DROP TABLE (의존성 역순)
DROP TABLE IF EXISTS buyers;
DROP TABLE IF EXISTS items;
DROP TABLE IF EXISTS clients;
DROP TABLE IF EXISTS payment_terms;
DROP TABLE IF EXISTS ports;
DROP TABLE IF EXISTS incoterms;
DROP TABLE IF EXISTS currencies;
DROP TABLE IF EXISTS countries;

-- ------------------------------------------------------------
-- 1. countries (국가)
-- ------------------------------------------------------------
CREATE TABLE countries (
    country_id      INT          NOT NULL AUTO_INCREMENT,
    country_code    VARCHAR(10)  NOT NULL,
    country_name    VARCHAR(100) NOT NULL,
    country_name_kr VARCHAR(100) DEFAULT NULL,
    PRIMARY KEY (country_id),
    UNIQUE KEY uk_countries_country_code (country_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX idx_countries_country_name ON countries (country_name);

-- ------------------------------------------------------------
-- 2. incoterms (인코텀즈)
-- ------------------------------------------------------------
CREATE TABLE incoterms (
    incoterm_id                  INT          NOT NULL AUTO_INCREMENT,
    incoterm_code                VARCHAR(10)  NOT NULL,
    incoterm_name                VARCHAR(200) NOT NULL,
    incoterm_name_kr             VARCHAR(200) DEFAULT NULL,
    incoterm_description         TEXT         DEFAULT NULL,
    incoterm_transport_mode      VARCHAR(50)  DEFAULT NULL,
    incoterm_seller_segments     VARCHAR(50)  DEFAULT NULL,
    incoterm_default_named_place VARCHAR(100) DEFAULT NULL,
    PRIMARY KEY (incoterm_id),
    UNIQUE KEY uk_incoterms_incoterm_code (incoterm_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX idx_incoterms_incoterm_name ON incoterms (incoterm_name);

-- ------------------------------------------------------------
-- 3. currencies (통화) — symbol 포함
-- ------------------------------------------------------------
CREATE TABLE currencies (
    currency_id     INT          NOT NULL AUTO_INCREMENT,
    currency_code   VARCHAR(10)  NOT NULL,
    currency_name   VARCHAR(100) NOT NULL,
    currency_symbol VARCHAR(5)   DEFAULT NULL,
    PRIMARY KEY (currency_id),
    UNIQUE KEY uk_currencies_currency_code (currency_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX idx_currencies_currency_name ON currencies (currency_name);

-- ------------------------------------------------------------
-- 4. ports (항구)
-- ------------------------------------------------------------
CREATE TABLE ports (
    port_id    INT          NOT NULL AUTO_INCREMENT,
    port_code  VARCHAR(20)  NOT NULL,
    port_name  VARCHAR(100) NOT NULL,
    port_city  VARCHAR(100) DEFAULT NULL,
    country_id INT          NOT NULL,   -- REFERENCES countries(country_id)
    PRIMARY KEY (port_id),
    UNIQUE KEY uk_ports_port_code (port_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX idx_ports_port_name ON ports (port_name);
CREATE INDEX idx_ports_country_id ON ports (country_id);

-- ------------------------------------------------------------
-- 5. payment_terms (결제조건)
-- ------------------------------------------------------------
CREATE TABLE payment_terms (
    payment_term_id          INT          NOT NULL AUTO_INCREMENT,
    payment_term_code        VARCHAR(20)  NOT NULL,
    payment_term_name        VARCHAR(100) NOT NULL,
    payment_term_description VARCHAR(200) DEFAULT NULL,
    PRIMARY KEY (payment_term_id),
    UNIQUE KEY uk_payment_terms_payment_term_code (payment_term_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX idx_payment_terms_payment_term_name ON payment_terms (payment_term_name);

-- ------------------------------------------------------------
-- 6. clients (거래처)
-- ------------------------------------------------------------
CREATE TABLE clients (
    client_id        INT          NOT NULL AUTO_INCREMENT,
    client_code      VARCHAR(20)  NOT NULL,
    client_name      VARCHAR(100) NOT NULL,
    client_name_kr   VARCHAR(100) DEFAULT NULL,
    country_id       INT          DEFAULT NULL,
    client_city      VARCHAR(100) DEFAULT NULL,
    port_id          INT          DEFAULT NULL,
    client_address   TEXT         DEFAULT NULL,
    client_tel       VARCHAR(50)  DEFAULT NULL,
    client_email     VARCHAR(255) DEFAULT NULL,
    payment_term_id  INT          DEFAULT NULL,
    currency_id      INT          DEFAULT NULL,
    client_manager   VARCHAR(100) DEFAULT NULL,
    department_id    INT          DEFAULT NULL, -- REFERENCES auth.departments(id)
    client_status    ENUM('active','inactive') NOT NULL DEFAULT 'active',
    client_reg_date  DATE         DEFAULT NULL,
    created_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (client_id),
    UNIQUE KEY uk_clients_client_code (client_code),
    CONSTRAINT fk_clients_country_id      FOREIGN KEY (country_id)      REFERENCES countries (country_id),
    CONSTRAINT fk_clients_port_id         FOREIGN KEY (port_id)         REFERENCES ports (port_id),
    CONSTRAINT fk_clients_payment_term_id FOREIGN KEY (payment_term_id) REFERENCES payment_terms (payment_term_id),
    CONSTRAINT fk_clients_currency_id     FOREIGN KEY (currency_id)     REFERENCES currencies (currency_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX idx_clients_client_name ON clients (client_name);
CREATE INDEX idx_clients_client_status ON clients (client_status);
CREATE INDEX idx_clients_country_id ON clients (country_id);
CREATE INDEX idx_clients_department_id ON clients (department_id);

-- ------------------------------------------------------------
-- 7. items (품목)
-- ------------------------------------------------------------
CREATE TABLE items (
    item_id         INT            NOT NULL AUTO_INCREMENT,
    item_code       VARCHAR(50)    NOT NULL,
    item_name       VARCHAR(100)   NOT NULL,
    item_name_kr    VARCHAR(100)   DEFAULT NULL,
    item_spec       VARCHAR(200)   DEFAULT NULL,
    item_unit       VARCHAR(50)    DEFAULT NULL,
    item_pack_unit  VARCHAR(50)    DEFAULT NULL,
    item_unit_price DECIMAL(15,2)  DEFAULT NULL,
    item_weight     DECIMAL(10,3)  DEFAULT NULL,
    item_hs_code    VARCHAR(20)    DEFAULT NULL,
    item_category   VARCHAR(100)   DEFAULT NULL,
    item_status     ENUM('active','inactive') NOT NULL DEFAULT 'active',
    item_reg_date   DATE           DEFAULT NULL,
    created_at      TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (item_id),
    UNIQUE KEY uk_items_item_code (item_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX idx_items_item_name ON items (item_name);
CREATE INDEX idx_items_item_category ON items (item_category);
CREATE INDEX idx_items_item_status ON items (item_status);
CREATE INDEX idx_items_item_hs_code ON items (item_hs_code);

-- ------------------------------------------------------------
-- 8. buyers (거래처 담당자)
-- ------------------------------------------------------------
CREATE TABLE buyers (
    buyer_id       INT          NOT NULL AUTO_INCREMENT,
    client_id      INT          NOT NULL,
    buyer_name     VARCHAR(100) NOT NULL,
    buyer_position VARCHAR(100) DEFAULT NULL,
    buyer_email    VARCHAR(255) DEFAULT NULL,
    buyer_tel      VARCHAR(50)  DEFAULT NULL,
    created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (buyer_id),
    CONSTRAINT fk_buyers_client_id FOREIGN KEY (client_id) REFERENCES clients (client_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX idx_buyers_client_id ON buyers (client_id);
CREATE INDEX idx_buyers_buyer_name ON buyers (buyer_name);
