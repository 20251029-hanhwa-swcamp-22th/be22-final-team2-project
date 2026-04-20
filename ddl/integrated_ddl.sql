-- ============================================================
-- Integrated DDL (All services — auth + master + activity + document)
-- 조직 계층: departments → teams → users / clients
-- 사용자/거래처는 team_id 만 보유하며 부서는 team → department 로 해소
-- ============================================================

-- ============ AUTH ============
CREATE TABLE positions (
    position_id INT NOT NULL AUTO_INCREMENT,
    position_name VARCHAR(50) NOT NULL,
    position_level INT NOT NULL,
    created_at DATETIME,
    PRIMARY KEY (position_id),
    CONSTRAINT uk_position_name UNIQUE (position_name)
);

CREATE TABLE departments (
    department_id INT NOT NULL AUTO_INCREMENT,
    department_name VARCHAR(100) NOT NULL,
    created_at DATETIME,
    PRIMARY KEY (department_id),
    CONSTRAINT uk_department_name UNIQUE (department_name)
);

CREATE TABLE teams (
    team_id INT NOT NULL AUTO_INCREMENT,
    team_name VARCHAR(100) NOT NULL,
    department_id INT NOT NULL,
    created_at DATETIME,
    PRIMARY KEY (team_id),
    CONSTRAINT uk_team_name_per_dept UNIQUE (department_id, team_name)
);

CREATE TABLE users (
    user_id INT NOT NULL AUTO_INCREMENT,
    employee_no VARCHAR(20) NOT NULL,
    user_name VARCHAR(100) NOT NULL,
    user_email VARCHAR(255) NOT NULL,
    user_pw VARCHAR(255) NOT NULL,
    user_role VARCHAR(20) NOT NULL,
    team_id INT,
    position_id INT,
    user_status VARCHAR(20) NOT NULL,
    created_at DATETIME,
    updated_at DATETIME,
    PRIMARY KEY (user_id),
    CONSTRAINT uk_users_employee_no UNIQUE (employee_no),
    CONSTRAINT uk_users_user_email UNIQUE (user_email)
);

CREATE TABLE company (
    company_id INT NOT NULL AUTO_INCREMENT,
    company_name VARCHAR(200) NOT NULL,
    company_address_en VARCHAR(500),
    company_address_kr VARCHAR(500),
    company_tel VARCHAR(50),
    company_fax VARCHAR(50),
    company_email VARCHAR(255),
    company_website VARCHAR(255),
    company_seal_image_url VARCHAR(500),
    updated_at DATETIME,
    PRIMARY KEY (company_id)
);

CREATE TABLE refresh_tokens (
    refresh_token_id INT NOT NULL AUTO_INCREMENT,
    user_id INT NOT NULL,
    token_value VARCHAR(512) NOT NULL,
    token_expires_at DATETIME NOT NULL,
    created_at DATETIME,
    PRIMARY KEY (refresh_token_id)
);

-- ============ MASTER ============
CREATE TABLE countries (
    country_id INT NOT NULL AUTO_INCREMENT,
    country_code VARCHAR(10) NOT NULL,
    country_name VARCHAR(100) NOT NULL,
    country_name_kr VARCHAR(100),
    PRIMARY KEY (country_id),
    CONSTRAINT uk_countries_country_code UNIQUE (country_code)
);

CREATE TABLE incoterms (
    incoterm_id INT NOT NULL AUTO_INCREMENT,
    incoterm_code VARCHAR(10) NOT NULL,
    incoterm_name VARCHAR(200) NOT NULL,
    incoterm_name_kr VARCHAR(200),
    incoterm_description TEXT,
    incoterm_transport_mode VARCHAR(50),
    incoterm_seller_segments VARCHAR(50),
    incoterm_default_named_place VARCHAR(100),
    PRIMARY KEY (incoterm_id),
    CONSTRAINT uk_incoterms_code UNIQUE (incoterm_code)
);

CREATE TABLE currencies (
    currency_id INT NOT NULL AUTO_INCREMENT,
    currency_code VARCHAR(10) NOT NULL,
    currency_name VARCHAR(100) NOT NULL,
    currency_symbol VARCHAR(5),
    PRIMARY KEY (currency_id),
    CONSTRAINT uk_currencies_code UNIQUE (currency_code)
);

CREATE TABLE ports (
    port_id INT NOT NULL AUTO_INCREMENT,
    port_code VARCHAR(20) NOT NULL,
    port_name VARCHAR(100) NOT NULL,
    port_city VARCHAR(100),
    country_id INT NOT NULL,
    PRIMARY KEY (port_id),
    CONSTRAINT uk_ports_code UNIQUE (port_code)
);

CREATE TABLE payment_terms (
    payment_term_id INT NOT NULL AUTO_INCREMENT,
    payment_term_code VARCHAR(20) NOT NULL,
    payment_term_name VARCHAR(100) NOT NULL,
    payment_term_description VARCHAR(200),
    PRIMARY KEY (payment_term_id),
    CONSTRAINT uk_payment_terms_code UNIQUE (payment_term_code)
);

CREATE TABLE clients (
    client_id INT NOT NULL AUTO_INCREMENT,
    client_code VARCHAR(20) NOT NULL,
    client_name VARCHAR(100) NOT NULL,
    client_name_kr VARCHAR(100),
    country_id INT,
    client_city VARCHAR(100),
    port_id INT,
    client_address TEXT,
    client_tel VARCHAR(50),
    client_email VARCHAR(255),
    payment_term_id INT,
    currency_id INT,
    client_manager VARCHAR(100),
    team_id INT,
    client_status VARCHAR(10) NOT NULL,
    client_reg_date DATE,
    created_at DATETIME,
    updated_at DATETIME,
    PRIMARY KEY (client_id),
    CONSTRAINT uk_clients_client_code UNIQUE (client_code)
);

CREATE TABLE items (
    item_id INT NOT NULL AUTO_INCREMENT,
    item_code VARCHAR(50) NOT NULL,
    item_name VARCHAR(100) NOT NULL,
    item_name_kr VARCHAR(100),
    item_spec VARCHAR(200),
    item_width INT UNSIGNED,
    item_depth INT UNSIGNED,
    item_height INT UNSIGNED,
    item_unit VARCHAR(50),
    item_pack_unit VARCHAR(50),
    item_unit_price DECIMAL(15,2),
    item_weight DECIMAL(10,3),
    item_hs_code VARCHAR(20),
    item_category VARCHAR(100),
    item_status VARCHAR(10) NOT NULL,
    item_reg_date DATE,
    created_at DATETIME,
    updated_at DATETIME,
    PRIMARY KEY (item_id),
    CONSTRAINT uk_items_code UNIQUE (item_code)
);

CREATE TABLE buyers (
    buyer_id INT NOT NULL AUTO_INCREMENT,
    client_id INT NOT NULL,
    buyer_name VARCHAR(100) NOT NULL,
    buyer_position VARCHAR(100),
    buyer_email VARCHAR(255),
    buyer_tel VARCHAR(50),
    created_at DATETIME,
    updated_at DATETIME,
    PRIMARY KEY (buyer_id)
);

-- ============ DOCUMENTS ============
CREATE TABLE proforma_invoices (
    pi_id BIGINT NOT NULL AUTO_INCREMENT,
    pi_code VARCHAR(30) NOT NULL,
    pi_issue_date DATE NOT NULL,
    client_id INT NOT NULL,
    currency_id INT NOT NULL,
    manager_id INT NOT NULL,
    pi_status VARCHAR(30) NOT NULL,
    pi_delivery_date DATE,
    pi_incoterms_code VARCHAR(10),
    pi_named_place VARCHAR(200),
    pi_total_amount DECIMAL(15,2) NOT NULL DEFAULT 0,
    pi_client_name VARCHAR(200),
    pi_client_address TEXT,
    pi_country VARCHAR(100),
    pi_currency_code VARCHAR(10),
    pi_manager_name VARCHAR(100),
    pi_approval_status VARCHAR(20),
    pi_request_status VARCHAR(20),
    pi_approval_action VARCHAR(20),
    pi_approval_requested_by VARCHAR(100),
    pi_approval_requested_at DATETIME,
    pi_approval_review JSON,
    pi_items_snapshot JSON,
    pi_linked_documents JSON,
    pi_revision_history JSON,
    -- PI 특기사항 (자유 텍스트). pi_items.pi_item_unit_price 는 거래처 통화 기준으로 저장.
    pi_remarks TEXT,
    -- 바이어 이름 (PIC) 스냅샷. PI → PO → CI/PL 로 전이.
    pi_buyer_name VARCHAR(200),
    created_at DATETIME,
    updated_at DATETIME,
    PRIMARY KEY (pi_id),
    CONSTRAINT uk_pi_code UNIQUE (pi_code)
);

CREATE TABLE pi_items (
    pi_item_id BIGINT NOT NULL AUTO_INCREMENT,
    pi_id BIGINT NOT NULL,
    item_id INT,
    pi_item_name VARCHAR(200) NOT NULL,
    pi_item_qty INT NOT NULL DEFAULT 0,
    pi_item_unit VARCHAR(20),
    pi_item_unit_price DECIMAL(15,2) NOT NULL DEFAULT 0,
    pi_item_amount DECIMAL(15,2) NOT NULL DEFAULT 0,
    pi_item_remark TEXT,
    PRIMARY KEY (pi_item_id)
);

CREATE TABLE purchase_orders (
    po_id BIGINT NOT NULL AUTO_INCREMENT,
    po_code VARCHAR(30) NOT NULL,
    -- 엔티티 PurchaseOrder.piId 는 String 으로 proforma_invoices.pi_code 를 저장한다.
    pi_id VARCHAR(30),
    po_issue_date DATE NOT NULL,
    client_id INT NOT NULL,
    currency_id INT NOT NULL,
    manager_id INT NOT NULL,
    po_status VARCHAR(30) NOT NULL,
    po_delivery_date DATE,
    po_incoterms_code VARCHAR(10),
    po_named_place VARCHAR(200),
    po_source_delivery_date DATE,
    po_delivery_date_override BOOLEAN NOT NULL DEFAULT FALSE,
    po_total_amount DECIMAL(15,2) NOT NULL DEFAULT 0,
    po_client_name VARCHAR(200),
    po_client_address TEXT,
    po_country VARCHAR(100),
    po_currency_code VARCHAR(10),
    po_manager_name VARCHAR(100),
    po_approval_status VARCHAR(20),
    po_request_status VARCHAR(20),
    po_approval_action VARCHAR(20),
    po_approval_requested_by VARCHAR(100),
    po_approval_requested_at DATETIME,
    po_approval_review JSON,
    po_items_snapshot JSON,
    po_linked_documents JSON,
    po_revision_history JSON,
    -- PO 특기사항 및 Step C 후속 흐름 분기(담당자). 통화 정책: po_total_amount /
    -- po_items.po_item_unit_price / po_item_amount 모두 거래처 통화 기준으로 저장한다.
    po_remarks TEXT,
    po_production_route VARCHAR(20),
    po_production_assignee_id BIGINT,
    po_shipping_assignee_id BIGINT,
    -- 바이어 이름 (PIC) 스냅샷. PI 에서 승계.
    po_buyer_name VARCHAR(200),
    created_at DATETIME,
    updated_at DATETIME,
    PRIMARY KEY (po_id),
    CONSTRAINT uk_po_code UNIQUE (po_code)
);

CREATE TABLE po_items (
    po_item_id BIGINT NOT NULL AUTO_INCREMENT,
    po_id BIGINT NOT NULL,
    item_id INT,
    po_item_name VARCHAR(200) NOT NULL,
    po_item_qty INT NOT NULL DEFAULT 0,
    po_item_unit VARCHAR(20),
    po_item_unit_price DECIMAL(15,2) NOT NULL DEFAULT 0,
    po_item_amount DECIMAL(15,2) NOT NULL DEFAULT 0,
    po_item_remark TEXT,
    -- 개당 중량 kg (Issue D — PL 총중량 집계 소스)
    po_item_weight DECIMAL(10,3),
    PRIMARY KEY (po_item_id)
);

CREATE TABLE commercial_invoices (
    ci_id BIGINT NOT NULL AUTO_INCREMENT,
    ci_code VARCHAR(30) NOT NULL,
    po_id BIGINT NOT NULL,
    ci_invoice_date DATE NOT NULL,
    client_id INT NOT NULL,
    currency_id INT NOT NULL,
    ci_total_amount DECIMAL(15,2) NOT NULL DEFAULT 0,
    ci_status VARCHAR(20) NOT NULL,
    ci_client_name VARCHAR(200),
    ci_client_address TEXT,
    ci_country VARCHAR(100),
    ci_currency_code VARCHAR(10),
    ci_payment_terms VARCHAR(100),
    ci_port_of_discharge VARCHAR(200),
    ci_buyer VARCHAR(100),
    ci_items_snapshot JSON,
    ci_linked_documents JSON,
    created_at DATETIME,
    PRIMARY KEY (ci_id),
    CONSTRAINT uk_ci_code UNIQUE (ci_code)
);

CREATE TABLE packing_lists (
    pl_id BIGINT NOT NULL AUTO_INCREMENT,
    pl_code VARCHAR(30) NOT NULL,
    po_id BIGINT NOT NULL,
    pl_invoice_date DATE NOT NULL,
    client_id INT NOT NULL,
    pl_gross_weight DECIMAL(38,2),
    pl_status VARCHAR(20) NOT NULL,
    pl_client_name VARCHAR(200),
    pl_client_address TEXT,
    pl_country VARCHAR(100),
    pl_payment_terms VARCHAR(100),
    pl_port_of_discharge VARCHAR(200),
    pl_buyer VARCHAR(100),
    pl_items_snapshot JSON,
    pl_linked_documents JSON,
    created_at DATETIME,
    PRIMARY KEY (pl_id),
    CONSTRAINT uk_pl_code UNIQUE (pl_code)
);

CREATE TABLE production_orders (
    production_order_id BIGINT NOT NULL AUTO_INCREMENT,
    production_order_code VARCHAR(30) NOT NULL,
    po_id BIGINT NOT NULL,
    production_issue_date DATE NOT NULL,
    client_id INT NOT NULL,
    manager_id INT,
    production_status VARCHAR(20) NOT NULL,
    production_due_date DATE,
    production_client_name VARCHAR(200),
    production_country VARCHAR(100),
    production_manager_name VARCHAR(100),
    production_item_name VARCHAR(200),
    production_linked_documents JSON,
    -- PO 품목 스냅샷 JSON(거래처 통화 기준). MO 전용 items 테이블이 없어 PO 에서 전이된 스냅샷을 그대로 보관.
    production_items_snapshot TEXT,
    created_at DATETIME,
    updated_at DATETIME,
    PRIMARY KEY (production_order_id),
    CONSTRAINT uk_production_order_code UNIQUE (production_order_code)
);

CREATE TABLE shipment_orders (
    shipment_order_id BIGINT NOT NULL AUTO_INCREMENT,
    shipment_order_code VARCHAR(30) NOT NULL,
    po_id BIGINT NOT NULL,
    shipment_issue_date DATE NOT NULL,
    client_id INT NOT NULL,
    manager_id INT,
    shipment_status VARCHAR(20) NOT NULL,
    shipment_due_date DATE,
    shipment_client_name VARCHAR(200),
    shipment_country VARCHAR(100),
    shipment_manager_name VARCHAR(100),
    shipment_item_name VARCHAR(200),
    shipment_linked_documents JSON,
    created_at DATETIME,
    updated_at DATETIME,
    PRIMARY KEY (shipment_order_id),
    CONSTRAINT uk_shipment_order_code UNIQUE (shipment_order_code)
);

CREATE TABLE approval_requests (
    approval_request_id INT NOT NULL AUTO_INCREMENT,
    approval_document_type VARCHAR(10) NOT NULL,
    approval_document_id VARCHAR(30) NOT NULL,
    approval_request_type VARCHAR(20) NOT NULL,
    approval_requester_id INT NOT NULL,
    approval_approver_id INT NOT NULL,
    approval_comment TEXT,
    approval_reason TEXT,
    approval_status VARCHAR(10) NOT NULL,
    approval_review_snapshot JSON,
    approval_requested_at DATETIME,
    approval_reviewed_at DATETIME,
    PRIMARY KEY (approval_request_id)
);

CREATE TABLE collections (
    collection_id BIGINT NOT NULL AUTO_INCREMENT,
    po_id BIGINT NOT NULL,
    client_id INT NOT NULL,
    manager_id INT NOT NULL,
    currency_id INT NOT NULL,
    collection_sales_amount DECIMAL(15,2) NOT NULL DEFAULT 0,
    collection_issue_date DATE NOT NULL,
    collection_completed_date DATE,
    collection_status VARCHAR(20) NOT NULL,
    created_at DATETIME,
    updated_at DATETIME,
    PRIMARY KEY (collection_id)
);

CREATE TABLE shipments (
    shipment_id BIGINT NOT NULL AUTO_INCREMENT,
    po_id BIGINT NOT NULL,
    shipment_order_id BIGINT NOT NULL,
    client_id INT NOT NULL,
    shipment_request_date DATE,
    shipment_due_date DATE,
    shipment_status VARCHAR(20) NOT NULL,
    created_at DATETIME,
    updated_at DATETIME,
    PRIMARY KEY (shipment_id)
);

CREATE TABLE docs_revision (
    docs_revision_id BIGINT NOT NULL AUTO_INCREMENT,
    doc_type VARCHAR(50) NOT NULL,
    doc_id BIGINT NOT NULL,
    snapshot_data JSON NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (docs_revision_id),
    INDEX idx_docs_revision_doc (doc_type, doc_id)
);

-- ============ ACTIVITY ============
CREATE TABLE activities (
    activity_id INT NOT NULL AUTO_INCREMENT,
    client_id INT NOT NULL,
    po_id VARCHAR(30),
    activity_author_id INT NOT NULL,
    activity_date DATE NOT NULL,
    activity_type VARCHAR(20) NOT NULL,
    activity_title VARCHAR(100) NOT NULL,
    activity_content TEXT,
    activity_priority VARCHAR(10),
    activity_schedule_from DATE,
    activity_schedule_to DATE,
    created_at DATETIME,
    updated_at DATETIME,
    PRIMARY KEY (activity_id)
);

CREATE TABLE contacts (
    contact_id INT NOT NULL AUTO_INCREMENT,
    client_id INT NOT NULL,
    writer_id INT NOT NULL,
    contact_name VARCHAR(100) NOT NULL,
    contact_position VARCHAR(100),
    contact_email VARCHAR(255),
    contact_tel VARCHAR(50),
    created_at DATETIME,
    updated_at DATETIME,
    PRIMARY KEY (contact_id)
);

CREATE TABLE email_logs (
    email_log_id INT NOT NULL AUTO_INCREMENT,
    client_id INT NOT NULL,
    po_id VARCHAR(30),
    email_title VARCHAR(200) NOT NULL,
    email_recipient_name VARCHAR(100),
    email_recipient_email VARCHAR(255) NOT NULL,
    email_sender_id INT NOT NULL,
    email_status VARCHAR(10) NOT NULL,
    email_sent_at DATETIME,
    created_at DATETIME,
    PRIMARY KEY (email_log_id)
);

CREATE TABLE email_log_types (
    email_log_type_id INT NOT NULL AUTO_INCREMENT,
    email_log_id INT NOT NULL,
    email_doc_type VARCHAR(20) NOT NULL,
    PRIMARY KEY (email_log_type_id)
);

CREATE TABLE email_log_attachments (
    email_log_attachment_id INT NOT NULL AUTO_INCREMENT,
    email_log_id INT NOT NULL,
    email_attachment_filename VARCHAR(255) NOT NULL,
    email_attachment_s3_key VARCHAR(500),
    PRIMARY KEY (email_log_attachment_id)
);

CREATE TABLE activity_packages (
    package_id INT NOT NULL AUTO_INCREMENT,
    package_title VARCHAR(100) NOT NULL,
    package_description TEXT,
    po_id VARCHAR(30),
    creator_id INT NOT NULL,
    date_from DATE,
    date_to DATE,
    created_at DATETIME,
    updated_at DATETIME,
    PRIMARY KEY (package_id)
);

CREATE TABLE activity_package_viewers (
    package_viewer_id INT NOT NULL AUTO_INCREMENT,
    package_id INT NOT NULL,
    user_id INT NOT NULL,
    PRIMARY KEY (package_viewer_id),
    CONSTRAINT uk_package_viewer UNIQUE (package_id, user_id)
);

CREATE TABLE activity_package_items (
    package_item_id INT NOT NULL AUTO_INCREMENT,
    package_id INT NOT NULL,
    activity_id INT NOT NULL,
    PRIMARY KEY (package_item_id),
    CONSTRAINT uk_package_activity UNIQUE (package_id, activity_id)
);

-- ============ FOREIGN KEYS ============
ALTER TABLE teams ADD CONSTRAINT fk_teams_department FOREIGN KEY (department_id) REFERENCES departments (department_id);
ALTER TABLE users ADD CONSTRAINT fk_users_team FOREIGN KEY (team_id) REFERENCES teams (team_id);
ALTER TABLE users ADD CONSTRAINT fk_users_position FOREIGN KEY (position_id) REFERENCES positions (position_id);
ALTER TABLE refresh_tokens ADD CONSTRAINT fk_refresh_tokens_user FOREIGN KEY (user_id) REFERENCES users (user_id);

ALTER TABLE ports ADD CONSTRAINT fk_ports_country FOREIGN KEY (country_id) REFERENCES countries (country_id);
ALTER TABLE clients ADD CONSTRAINT fk_clients_country FOREIGN KEY (country_id) REFERENCES countries (country_id);
ALTER TABLE clients ADD CONSTRAINT fk_clients_port FOREIGN KEY (port_id) REFERENCES ports (port_id);
ALTER TABLE clients ADD CONSTRAINT fk_clients_payment_term FOREIGN KEY (payment_term_id) REFERENCES payment_terms (payment_term_id);
ALTER TABLE clients ADD CONSTRAINT fk_clients_currency FOREIGN KEY (currency_id) REFERENCES currencies (currency_id);
ALTER TABLE clients ADD CONSTRAINT fk_clients_team FOREIGN KEY (team_id) REFERENCES teams (team_id);
ALTER TABLE buyers ADD CONSTRAINT fk_buyers_client FOREIGN KEY (client_id) REFERENCES clients (client_id);

ALTER TABLE pi_items ADD CONSTRAINT fk_pi_items_pi FOREIGN KEY (pi_id) REFERENCES proforma_invoices (pi_id);
ALTER TABLE pi_items ADD CONSTRAINT fk_pi_items_item FOREIGN KEY (item_id) REFERENCES items (item_id);
ALTER TABLE proforma_invoices ADD CONSTRAINT fk_pi_client FOREIGN KEY (client_id) REFERENCES clients (client_id);
ALTER TABLE proforma_invoices ADD CONSTRAINT fk_pi_currency FOREIGN KEY (currency_id) REFERENCES currencies (currency_id);
ALTER TABLE proforma_invoices ADD CONSTRAINT fk_pi_manager FOREIGN KEY (manager_id) REFERENCES users (user_id);

-- pi_id 는 VARCHAR(30) 로 proforma_invoices.pi_code (UNIQUE) 를 참조한다.
ALTER TABLE purchase_orders ADD CONSTRAINT fk_po_pi FOREIGN KEY (pi_id) REFERENCES proforma_invoices (pi_code);
ALTER TABLE purchase_orders ADD CONSTRAINT fk_po_client FOREIGN KEY (client_id) REFERENCES clients (client_id);
ALTER TABLE purchase_orders ADD CONSTRAINT fk_po_currency FOREIGN KEY (currency_id) REFERENCES currencies (currency_id);
ALTER TABLE purchase_orders ADD CONSTRAINT fk_po_manager FOREIGN KEY (manager_id) REFERENCES users (user_id);
ALTER TABLE po_items ADD CONSTRAINT fk_po_items_po FOREIGN KEY (po_id) REFERENCES purchase_orders (po_id);
ALTER TABLE po_items ADD CONSTRAINT fk_po_items_item FOREIGN KEY (item_id) REFERENCES items (item_id);

ALTER TABLE commercial_invoices ADD CONSTRAINT fk_ci_po FOREIGN KEY (po_id) REFERENCES purchase_orders (po_id);
ALTER TABLE commercial_invoices ADD CONSTRAINT fk_ci_client FOREIGN KEY (client_id) REFERENCES clients (client_id);
ALTER TABLE commercial_invoices ADD CONSTRAINT fk_ci_currency FOREIGN KEY (currency_id) REFERENCES currencies (currency_id);
ALTER TABLE packing_lists ADD CONSTRAINT fk_pl_po FOREIGN KEY (po_id) REFERENCES purchase_orders (po_id);
ALTER TABLE packing_lists ADD CONSTRAINT fk_pl_client FOREIGN KEY (client_id) REFERENCES clients (client_id);

ALTER TABLE production_orders ADD CONSTRAINT fk_prod_po FOREIGN KEY (po_id) REFERENCES purchase_orders (po_id);
ALTER TABLE production_orders ADD CONSTRAINT fk_prod_client FOREIGN KEY (client_id) REFERENCES clients (client_id);
ALTER TABLE production_orders ADD CONSTRAINT fk_prod_manager FOREIGN KEY (manager_id) REFERENCES users (user_id);
ALTER TABLE shipment_orders ADD CONSTRAINT fk_ship_po FOREIGN KEY (po_id) REFERENCES purchase_orders (po_id);
ALTER TABLE shipment_orders ADD CONSTRAINT fk_ship_client FOREIGN KEY (client_id) REFERENCES clients (client_id);
ALTER TABLE shipment_orders ADD CONSTRAINT fk_ship_manager FOREIGN KEY (manager_id) REFERENCES users (user_id);

ALTER TABLE approval_requests ADD CONSTRAINT fk_appr_requester FOREIGN KEY (approval_requester_id) REFERENCES users (user_id);
ALTER TABLE approval_requests ADD CONSTRAINT fk_appr_approver FOREIGN KEY (approval_approver_id) REFERENCES users (user_id);

ALTER TABLE collections ADD CONSTRAINT fk_collections_po FOREIGN KEY (po_id) REFERENCES purchase_orders (po_id);
ALTER TABLE collections ADD CONSTRAINT fk_collections_client FOREIGN KEY (client_id) REFERENCES clients (client_id);
ALTER TABLE collections ADD CONSTRAINT fk_collections_manager FOREIGN KEY (manager_id) REFERENCES users (user_id);
ALTER TABLE collections ADD CONSTRAINT fk_collections_currency FOREIGN KEY (currency_id) REFERENCES currencies (currency_id);

ALTER TABLE shipments ADD CONSTRAINT fk_shipments_po FOREIGN KEY (po_id) REFERENCES purchase_orders (po_id);
ALTER TABLE shipments ADD CONSTRAINT fk_shipments_ship_order FOREIGN KEY (shipment_order_id) REFERENCES shipment_orders (shipment_order_id);
ALTER TABLE shipments ADD CONSTRAINT fk_shipments_client FOREIGN KEY (client_id) REFERENCES clients (client_id);

ALTER TABLE activities ADD CONSTRAINT fk_activities_client FOREIGN KEY (client_id) REFERENCES clients (client_id);
ALTER TABLE activities ADD CONSTRAINT fk_activities_author FOREIGN KEY (activity_author_id) REFERENCES users (user_id);

ALTER TABLE contacts ADD CONSTRAINT fk_contacts_client FOREIGN KEY (client_id) REFERENCES clients (client_id);
ALTER TABLE contacts ADD CONSTRAINT fk_contacts_writer FOREIGN KEY (writer_id) REFERENCES users (user_id);

ALTER TABLE email_logs ADD CONSTRAINT fk_email_logs_client FOREIGN KEY (client_id) REFERENCES clients (client_id);
ALTER TABLE email_logs ADD CONSTRAINT fk_email_logs_sender FOREIGN KEY (email_sender_id) REFERENCES users (user_id);
ALTER TABLE email_log_types ADD CONSTRAINT fk_email_log_types_log FOREIGN KEY (email_log_id) REFERENCES email_logs (email_log_id);
ALTER TABLE email_log_attachments ADD CONSTRAINT fk_email_log_attachments_log FOREIGN KEY (email_log_id) REFERENCES email_logs (email_log_id);

ALTER TABLE activity_packages ADD CONSTRAINT fk_packages_creator FOREIGN KEY (creator_id) REFERENCES users (user_id);
ALTER TABLE activity_package_viewers ADD CONSTRAINT fk_package_viewers_package FOREIGN KEY (package_id) REFERENCES activity_packages (package_id);
ALTER TABLE activity_package_viewers ADD CONSTRAINT fk_package_viewers_user FOREIGN KEY (user_id) REFERENCES users (user_id);
ALTER TABLE activity_package_items ADD CONSTRAINT fk_package_items_package FOREIGN KEY (package_id) REFERENCES activity_packages (package_id);
ALTER TABLE activity_package_items ADD CONSTRAINT fk_package_items_activity FOREIGN KEY (activity_id) REFERENCES activities (activity_id);
