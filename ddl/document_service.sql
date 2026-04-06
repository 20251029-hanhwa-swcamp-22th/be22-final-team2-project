-- ============================================================
-- Document Service DDL (v4)
-- 서비스 설명: 무역 문서(견적~출하) 및 현황 관련 테이블
--   - proforma_invoices: 견적송장 (PI)       — PK: PI2025001
--   - pi_items: PI 품목
--   - purchase_orders: 발주서 (PO)           — PK: PO2025001
--   - po_items: PO 품목
--   - commercial_invoices: 상업송장 (CI)     — PK: CI2025001
--   - packing_lists: 포장명세서 (PL)         — PK: PL2025001
--   - production_orders: 생산지시서          — PK: PRD2025001
--   - shipment_orders: 출하지시서            — PK: SH2025001
--   - approval_requests: 결재 요청
--   - collections: 매출·수금 현황
--   - shipments: 출하현황                    — PK: SHP2025001
-- Engine: InnoDB | Charset: utf8mb4_unicode_ci
-- ============================================================

-- 의존성 역순으로 DROP
DROP TABLE IF EXISTS shipments;
DROP TABLE IF EXISTS collections;
DROP TABLE IF EXISTS approval_requests;
DROP TABLE IF EXISTS shipment_orders;
DROP TABLE IF EXISTS production_orders;
DROP TABLE IF EXISTS packing_lists;
DROP TABLE IF EXISTS commercial_invoices;
DROP TABLE IF EXISTS po_items;
DROP TABLE IF EXISTS purchase_orders;
DROP TABLE IF EXISTS pi_items;
DROP TABLE IF EXISTS proforma_invoices;

-- ------------------------------------------------------------
-- 1. proforma_invoices (견적송장 PI)
-- ------------------------------------------------------------
CREATE TABLE proforma_invoices (
    pi_id                   VARCHAR(30)     NOT NULL,                   -- 문서번호: PI2025001
    pi_issue_date           DATE            NOT NULL,
    client_id               INT             NOT NULL,                   -- REFERENCES master.clients(id)
    currency_id             INT             NOT NULL,                   -- REFERENCES master.currencies(id)
    manager_id              INT             NOT NULL,                   -- REFERENCES auth.users(id)
    pi_status               ENUM('draft','confirmed','pending_approval','rejected','deletion_requested','registration_requested','modification_requested','cancelled')
                                            NOT NULL DEFAULT 'draft',
    pi_delivery_date        DATE            NULL,
    pi_incoterms_code       VARCHAR(10)     NULL,
    pi_named_place          VARCHAR(200)    NULL,
    pi_total_amount         DECIMAL(15,2)   NOT NULL DEFAULT 0,

    -- 스냅샷 (화면 표시용)
    pi_client_name          VARCHAR(200)    NULL,
    pi_client_address       TEXT            NULL,
    pi_country              VARCHAR(100)    NULL,
    pi_currency_code        VARCHAR(10)     NULL,
    pi_manager_name         VARCHAR(100)    NULL,

    -- 결재 메타데이터
    pi_approval_status      ENUM('pending','approved','rejected') NULL,
    pi_request_status       ENUM('registration','modification','deletion') NULL,
    pi_approval_action      ENUM('register','modify','delete') NULL,
    pi_approval_requested_by VARCHAR(100)                       NULL,
    pi_approval_requested_at TIMESTAMP                          NULL,
    pi_approval_review      JSON                               NULL COMMENT '결재 검토 스냅샷',

    -- JSON 컬럼
    pi_items_snapshot        JSON          NULL COMMENT '품목 스냅샷 (PDF/상세용)',
    pi_linked_documents      JSON          NULL COMMENT '연결 문서 목록 [{id, type, status}]',
    pi_revision_history      JSON          NULL COMMENT '변경 이력',

    created_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (pi_id),
    INDEX idx_pi_status (pi_status),
    INDEX idx_pi_issue_date (pi_issue_date),
    INDEX idx_pi_client_id (client_id),
    INDEX idx_pi_manager_id (manager_id),
    INDEX idx_pi_approval_status (pi_approval_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 2. pi_items (PI 품목)
-- ------------------------------------------------------------
CREATE TABLE pi_items (
    pi_item_id      INT            NOT NULL AUTO_INCREMENT,
    pi_id           VARCHAR(30)    NOT NULL,
    item_id         INT            NULL,                             -- REFERENCES master.items(id)
    pi_item_name    VARCHAR(200)   NOT NULL,
    pi_item_qty     INT            NOT NULL DEFAULT 0,
    pi_item_unit    VARCHAR(20)    NULL,
    pi_item_unit_price DECIMAL(15,2) NOT NULL DEFAULT 0,
    pi_item_amount  DECIMAL(15,2)  NOT NULL DEFAULT 0,
    pi_item_remark  TEXT           NULL,

    PRIMARY KEY (pi_item_id),
    INDEX idx_pi_items_pi_id (pi_id),
    CONSTRAINT fk_pi_items_pi FOREIGN KEY (pi_id) REFERENCES proforma_invoices (pi_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 3. purchase_orders (발주서 PO)
-- ------------------------------------------------------------
CREATE TABLE purchase_orders (
    po_id                       VARCHAR(30)     NOT NULL,            -- 문서번호: PO2025001
    pi_id                       VARCHAR(30)     NULL,
    po_issue_date               DATE            NOT NULL,
    client_id                   INT             NOT NULL,            -- REFERENCES master.clients(id)
    currency_id                 INT             NOT NULL,            -- REFERENCES master.currencies(id)
    manager_id                  INT             NOT NULL,            -- REFERENCES auth.users(id)
    po_status                   ENUM('draft','confirmed','pending_approval','rejected','deletion_requested','registration_requested','modification_requested','cancelled')
                                                NOT NULL DEFAULT 'draft',
    po_delivery_date            DATE            NULL,
    po_incoterms_code           VARCHAR(10)     NULL,
    po_named_place              VARCHAR(200)    NULL,
    po_source_delivery_date     DATE            NULL,
    po_delivery_date_override   BOOLEAN         NOT NULL DEFAULT FALSE,
    po_total_amount             DECIMAL(15,2)   NOT NULL DEFAULT 0,

    -- 스냅샷 (화면 표시용)
    po_client_name              VARCHAR(200)    NULL,
    po_client_address           TEXT            NULL,
    po_country                  VARCHAR(100)    NULL,
    po_currency_code            VARCHAR(10)     NULL,
    po_manager_name             VARCHAR(100)    NULL,

    -- 결재 메타데이터
    po_approval_status          ENUM('pending','approved','rejected') NULL,
    po_request_status           ENUM('registration','modification','deletion') NULL,
    po_approval_action          ENUM('register','modify','delete') NULL,
    po_approval_requested_by    VARCHAR(100)                       NULL,
    po_approval_requested_at    TIMESTAMP                          NULL,
    po_approval_review          JSON                               NULL COMMENT '결재 검토 스냅샷',

    -- JSON 컬럼
    po_items_snapshot            JSON          NULL COMMENT '품목 스냅샷 (PDF/상세용)',
    po_linked_documents          JSON          NULL COMMENT '연결 문서 목록 [{id, type, status}]',
    po_revision_history          JSON          NULL COMMENT '변경 이력',

    created_at                  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at                  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (po_id),
    INDEX idx_po_status (po_status),
    INDEX idx_po_issue_date (po_issue_date),
    INDEX idx_po_client_id (client_id),
    INDEX idx_po_manager_id (manager_id),
    INDEX idx_po_pi_id (pi_id),
    INDEX idx_po_approval_status (po_approval_status),
    CONSTRAINT fk_po_pi FOREIGN KEY (pi_id) REFERENCES proforma_invoices (pi_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 4. po_items (PO 품목)
-- ------------------------------------------------------------
CREATE TABLE po_items (
    po_item_id      INT            NOT NULL AUTO_INCREMENT,
    po_id           VARCHAR(30)    NOT NULL,
    item_id         INT            NULL,                             -- REFERENCES master.items(id)
    po_item_name    VARCHAR(200)   NOT NULL,
    po_item_qty     INT            NOT NULL DEFAULT 0,
    po_item_unit    VARCHAR(20)    NULL,
    po_item_unit_price DECIMAL(15,2) NOT NULL DEFAULT 0,
    po_item_amount  DECIMAL(15,2)  NOT NULL DEFAULT 0,
    po_item_remark  TEXT           NULL,

    PRIMARY KEY (po_item_id),
    INDEX idx_po_items_po_id (po_id),
    CONSTRAINT fk_po_items_po FOREIGN KEY (po_id) REFERENCES purchase_orders (po_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 5. commercial_invoices (상업송장 CI)
-- ------------------------------------------------------------
CREATE TABLE commercial_invoices (
    ci_id                 VARCHAR(30)     NOT NULL,                 -- 문서번호: CI2025001
    po_id                 VARCHAR(30)     NOT NULL,
    ci_invoice_date       DATE            NOT NULL,
    client_id             INT             NOT NULL,                 -- REFERENCES master.clients(id)
    currency_id           INT             NOT NULL,                 -- REFERENCES master.currencies(id)
    ci_total_amount       DECIMAL(15,2)   NOT NULL DEFAULT 0,
    ci_status             ENUM('pending','completed') NOT NULL DEFAULT 'pending',

    -- 출력용 스냅샷
    ci_client_name        VARCHAR(200)    NULL,
    ci_client_address     TEXT            NULL,
    ci_country            VARCHAR(100)    NULL,
    ci_currency_code      VARCHAR(10)     NULL,
    ci_payment_terms      VARCHAR(100)    NULL,
    ci_port_of_discharge  VARCHAR(200)    NULL,
    ci_buyer              VARCHAR(100)    NULL,
    ci_items_snapshot     JSON            NULL COMMENT '품목 스냅샷 (PDF/출력용)',
    ci_linked_documents   JSON            NULL COMMENT '연결 문서 목록 [{id, type, status}]',

    created_at            TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (ci_id),
    INDEX idx_ci_po_id (po_id),
    INDEX idx_ci_client_id (client_id),
    INDEX idx_ci_invoice_date (ci_invoice_date),
    CONSTRAINT fk_ci_po FOREIGN KEY (po_id) REFERENCES purchase_orders (po_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 6. packing_lists (포장명세서 PL)
-- ------------------------------------------------------------
CREATE TABLE packing_lists (
    pl_id                 VARCHAR(30)     NOT NULL,                 -- 문서번호: PL2025001
    po_id                 VARCHAR(30)     NOT NULL,
    pl_invoice_date       DATE            NOT NULL,
    client_id             INT             NOT NULL,                 -- REFERENCES master.clients(id)
    pl_gross_weight       DECIMAL(10,3)   NULL,
    pl_status             ENUM('pending','completed') NOT NULL DEFAULT 'pending',

    -- 출력용 스냅샷
    pl_client_name        VARCHAR(200)    NULL,
    pl_client_address     TEXT            NULL,
    pl_country            VARCHAR(100)    NULL,
    pl_payment_terms      VARCHAR(100)    NULL,
    pl_port_of_discharge  VARCHAR(200)    NULL,
    pl_buyer              VARCHAR(100)    NULL,
    pl_items_snapshot     JSON            NULL COMMENT '품목 스냅샷 (PDF/출력용)',
    pl_linked_documents   JSON            NULL COMMENT '연결 문서 목록 [{id, type, status}]',

    created_at            TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (pl_id),
    INDEX idx_pl_po_id (po_id),
    INDEX idx_pl_client_id (client_id),
    CONSTRAINT fk_pl_po FOREIGN KEY (po_id) REFERENCES purchase_orders (po_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 7. production_orders (생산지시서)
-- ------------------------------------------------------------
CREATE TABLE production_orders (
    production_order_id      VARCHAR(30)     NOT NULL,                  -- 문서번호: PRD2025001
    po_id                    VARCHAR(30)     NOT NULL,
    production_issue_date    DATE            NOT NULL,
    client_id                INT             NOT NULL,                  -- REFERENCES master.clients(id)
    manager_id               INT             NULL,                      -- REFERENCES auth.users(id)
    production_status        ENUM('in_progress','completed') NOT NULL DEFAULT 'in_progress',
    production_due_date      DATE            NULL,

    -- 스냅샷
    production_client_name   VARCHAR(200)    NULL,
    production_country       VARCHAR(100)    NULL,
    production_manager_name  VARCHAR(100)    NULL,
    production_item_name     VARCHAR(200)    NULL,
    production_linked_documents JSON         NULL COMMENT '연결 문서 목록 [{id, type, status}]',

    created_at               TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at               TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (production_order_id),
    INDEX idx_prod_po_id (po_id),
    INDEX idx_prod_status (production_status),
    INDEX idx_prod_client_id (client_id),
    INDEX idx_prod_issue_date (production_issue_date),
    CONSTRAINT fk_prod_po FOREIGN KEY (po_id) REFERENCES purchase_orders (po_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 8. shipment_orders (출하지시서)
-- ------------------------------------------------------------
CREATE TABLE shipment_orders (
    shipment_order_id        VARCHAR(30)     NOT NULL,                  -- 문서번호: SH2025001
    po_id                    VARCHAR(30)     NOT NULL,
    shipment_issue_date      DATE            NOT NULL,
    client_id                INT             NOT NULL,                  -- REFERENCES master.clients(id)
    manager_id               INT             NULL,                      -- REFERENCES auth.users(id)
    shipment_status          ENUM('preparing','completed') NOT NULL DEFAULT 'preparing',
    shipment_due_date        DATE            NULL,

    -- 스냅샷
    shipment_client_name     VARCHAR(200)    NULL,
    shipment_country         VARCHAR(100)    NULL,
    shipment_manager_name    VARCHAR(100)    NULL,
    shipment_item_name       VARCHAR(200)    NULL,
    shipment_linked_documents JSON           NULL COMMENT '연결 문서 목록 [{id, type, status}]',

    created_at               TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at               TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (shipment_order_id),
    INDEX idx_ship_po_id (po_id),
    INDEX idx_ship_status (shipment_status),
    INDEX idx_ship_client_id (client_id),
    INDEX idx_ship_issue_date (shipment_issue_date),
    CONSTRAINT fk_ship_po FOREIGN KEY (po_id) REFERENCES purchase_orders (po_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 9. approval_requests (결재 요청)
-- ------------------------------------------------------------
CREATE TABLE approval_requests (
    approval_request_id     INT                                  NOT NULL AUTO_INCREMENT,
    approval_document_type  ENUM('PI','PO')                      NOT NULL,
    approval_document_id    VARCHAR(30)                          NOT NULL,
    approval_request_type   ENUM('registration','modification','deletion') NOT NULL,
    approval_requester_id   INT                                  NOT NULL, -- REFERENCES auth.users(id)
    approval_approver_id    INT                                  NOT NULL, -- REFERENCES auth.users(id)
    approval_comment        TEXT                                     NULL,
    approval_status         ENUM('pending','approved','rejected')   NOT NULL DEFAULT 'pending',
    approval_review_snapshot JSON                                 NULL,
    approval_requested_at   TIMESTAMP                            NOT NULL DEFAULT CURRENT_TIMESTAMP,
    approval_reviewed_at    TIMESTAMP                            NULL,

    PRIMARY KEY (approval_request_id),
    INDEX idx_appr_document (approval_document_type, approval_document_id),
    INDEX idx_appr_requester_id (approval_requester_id),
    INDEX idx_appr_approver_id (approval_approver_id),
    INDEX idx_appr_status (approval_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 10. collections (매출·수금 현황)
-- ------------------------------------------------------------
CREATE TABLE collections (
    collection_id           INT             NOT NULL AUTO_INCREMENT,
    po_id                   VARCHAR(30)     NOT NULL,
    client_id               INT             NOT NULL,                   -- REFERENCES master.clients(id)
    manager_id              INT             NOT NULL,                   -- REFERENCES auth.users(id)
    currency_id             INT             NOT NULL,                   -- REFERENCES master.currencies(id)
    collection_sales_amount DECIMAL(15,2)   NOT NULL DEFAULT 0,
    collection_issue_date   DATE            NOT NULL,
    collection_completed_date DATE          NULL,
    collection_status       ENUM('unpaid','paid') NOT NULL DEFAULT 'unpaid',

    created_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (collection_id),
    INDEX idx_collections_po_id (po_id),
    INDEX idx_collections_client_id (client_id),
    INDEX idx_collections_manager_id (manager_id),
    INDEX idx_collections_status (collection_status),
    INDEX idx_collections_issue_date (collection_issue_date),
    CONSTRAINT fk_collections_po FOREIGN KEY (po_id) REFERENCES purchase_orders (po_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 11. shipments (출하현황)
-- ------------------------------------------------------------
CREATE TABLE shipments (
    shipment_id           INT             NOT NULL AUTO_INCREMENT,
    po_id                 VARCHAR(30)     NOT NULL,
    shipment_order_id     VARCHAR(30)     NOT NULL,
    client_id             INT             NOT NULL,                 -- REFERENCES master.clients(id)
    shipment_request_date DATE            NULL,
    shipment_due_date     DATE            NULL,
    shipment_status       ENUM('preparing','completed') NOT NULL DEFAULT 'preparing',

    created_at            TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at            TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (shipment_id),
    INDEX idx_shipments_po_id (po_id),
    INDEX idx_shipments_shipment_order_id (shipment_order_id),
    INDEX idx_shipments_client_id (client_id),
    INDEX idx_shipments_status (shipment_status),
    INDEX idx_shipments_due_date (shipment_due_date),
    CONSTRAINT fk_shipments_po FOREIGN KEY (po_id) REFERENCES purchase_orders (po_id),
    CONSTRAINT fk_shipments_ship_order FOREIGN KEY (shipment_order_id) REFERENCES shipment_orders (shipment_order_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
