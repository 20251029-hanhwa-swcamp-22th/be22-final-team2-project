CREATE TABLE positions (
    position_id INT NOT NULL,
    position_name VARCHAR(50) NOT NULL,
    position_level INT NOT NULL,
    created_at DATETIME,
    PRIMARY KEY (position_id)
);

CREATE TABLE departments (
    department_id INT NOT NULL,
    department_name VARCHAR(50) NOT NULL,
    created_at DATETIME,
    PRIMARY KEY (department_id)
);

CREATE TABLE users (
    user_id INT NOT NULL,
    employee_no VARCHAR(20) NOT NULL,
    user_name VARCHAR(50) NOT NULL,
    user_email VARCHAR(100) NOT NULL,
    user_pw VARCHAR(255) NOT NULL,
    user_role VARCHAR(20) NOT NULL,
    department_id INT,
    position_id INT,
    user_status VARCHAR(10) NOT NULL,
    created_at DATETIME,
    updated_at DATETIME,
    PRIMARY KEY (user_id)
);

CREATE TABLE company (
    company_id INT NOT NULL,
    company_name VARCHAR(100) NOT NULL,
    company_address_en VARCHAR(255),
    company_address_kr VARCHAR(255),
    company_tel VARCHAR(30),
    company_fax VARCHAR(30),
    company_email VARCHAR(100),
    company_website VARCHAR(255),
    company_seal_image_url VARCHAR(255),
    updated_at DATETIME,
    PRIMARY KEY (company_id)
);

CREATE TABLE refresh_tokens (
    refresh_token_id INT NOT NULL,
    user_id INT NOT NULL,
    token_value VARCHAR(255) NOT NULL,
    token_expires_at DATETIME NOT NULL,
    created_at DATETIME,
    PRIMARY KEY (refresh_token_id)
);

CREATE TABLE countries (
    country_id INT NOT NULL,
    country_code VARCHAR(10) NOT NULL,
    country_name VARCHAR(100) NOT NULL,
    country_name_kr VARCHAR(100),
    PRIMARY KEY (country_id)
);

CREATE TABLE incoterms (
    incoterm_id INT NOT NULL,
    incoterm_code VARCHAR(10) NOT NULL,
    incoterm_name VARCHAR(50) NOT NULL,
    incoterm_name_kr VARCHAR(50),
    incoterm_description VARCHAR(255),
    incoterm_transport_mode VARCHAR(50),
    incoterm_seller_segments VARCHAR(255),
    incoterm_default_named_place VARCHAR(100),
    PRIMARY KEY (incoterm_id)
);

CREATE TABLE currencies (
    currency_id INT NOT NULL,
    currency_code VARCHAR(10) NOT NULL,
    currency_name VARCHAR(50) NOT NULL,
    currency_symbol VARCHAR(10),
    PRIMARY KEY (currency_id)
);

CREATE TABLE ports (
    port_id INT NOT NULL,
    port_code VARCHAR(20) NOT NULL,
    port_name VARCHAR(100) NOT NULL,
    port_city VARCHAR(100),
    country_id INT,
    PRIMARY KEY (port_id)
);

CREATE TABLE payment_terms (
    payment_term_id INT NOT NULL,
    payment_term_code VARCHAR(20) NOT NULL,
    payment_term_name VARCHAR(100) NOT NULL,
    payment_term_description VARCHAR(255),
    PRIMARY KEY (payment_term_id)
);

CREATE TABLE clients (
    client_id INT NOT NULL,
    client_code VARCHAR(20) NOT NULL,
    client_name VARCHAR(100) NOT NULL,
    client_name_kr VARCHAR(100),
    country_id INT,
    client_city VARCHAR(100),
    port_id INT,
    client_address VARCHAR(255),
    client_tel VARCHAR(30),
    client_email VARCHAR(100),
    payment_term_id INT,
    currency_id INT,
    client_manager VARCHAR(50),
    department_id INT,
    client_status VARCHAR(10) NOT NULL,
    client_reg_date DATE,
    created_at DATETIME,
    updated_at DATETIME,
    PRIMARY KEY (client_id)
);

CREATE TABLE items (
    item_id INT NOT NULL,
    item_code VARCHAR(20) NOT NULL,
    item_name VARCHAR(100) NOT NULL,
    item_name_kr VARCHAR(100),
    item_spec VARCHAR(255),
    item_unit VARCHAR(20),
    item_pack_unit VARCHAR(20),
    item_unit_price BIGINT,
    item_weight BIGINT,
    item_hs_code VARCHAR(20),
    item_category VARCHAR(50),
    item_status VARCHAR(10) NOT NULL,
    item_reg_date DATE,
    created_at DATETIME,
    updated_at DATETIME,
    PRIMARY KEY (item_id)
);

CREATE TABLE buyers (
    buyer_id INT NOT NULL,
    client_id INT NOT NULL,
    buyer_name VARCHAR(50) NOT NULL,
    buyer_position VARCHAR(50),
    buyer_email VARCHAR(100),
    buyer_tel VARCHAR(30),
    created_at DATETIME,
    updated_at DATETIME,
    PRIMARY KEY (buyer_id)
);

CREATE TABLE proforma_invoices (
    pi_id VARCHAR(20) NOT NULL,
    pi_issue_date DATE,
    client_id INT,
    currency_id INT,
    manager_id INT,
    pi_status VARCHAR(20) NOT NULL,
    pi_delivery_date DATE,
    pi_incoterms_code VARCHAR(10),
    pi_named_place VARCHAR(100),
    pi_total_amount BIGINT,
    pi_client_name VARCHAR(100),
    pi_client_address VARCHAR(255),
    pi_country VARCHAR(100),
    pi_currency_code VARCHAR(10),
    pi_manager_name VARCHAR(50),
    pi_approval_status VARCHAR(10),
    pi_request_status VARCHAR(20),
    pi_approval_action VARCHAR(10),
    pi_approval_requested_by VARCHAR(50),
    pi_approval_requested_at DATETIME,
    pi_approval_review VARCHAR(255),
    pi_items_snapshot VARCHAR(255),
    pi_linked_documents VARCHAR(255),
    pi_revision_history VARCHAR(255),
    created_at DATETIME,
    updated_at DATETIME,
    PRIMARY KEY (pi_id)
);

CREATE TABLE pi_items (
    pi_item_id INT NOT NULL,
    pi_id VARCHAR(20) NOT NULL,
    item_id INT,
    pi_item_name VARCHAR(100),
    pi_item_qty INT,
    pi_item_unit VARCHAR(20),
    pi_item_unit_price BIGINT,
    pi_item_amount BIGINT,
    pi_item_remark VARCHAR(255),
    PRIMARY KEY (pi_item_id)
);

CREATE TABLE purchase_orders (
    po_id VARCHAR(20) NOT NULL,
    pi_id VARCHAR(20),
    po_issue_date DATE,
    client_id INT,
    currency_id INT,
    manager_id INT,
    po_status VARCHAR(20) NOT NULL,
    po_delivery_date DATE,
    po_incoterms_code VARCHAR(10),
    po_named_place VARCHAR(100),
    po_source_delivery_date DATE,
    po_delivery_date_override INT,
    po_total_amount BIGINT,
    po_client_name VARCHAR(100),
    po_client_address VARCHAR(255),
    po_country VARCHAR(100),
    po_currency_code VARCHAR(10),
    po_manager_name VARCHAR(50),
    po_approval_status VARCHAR(10),
    po_request_status VARCHAR(20),
    po_approval_action VARCHAR(10),
    po_approval_requested_by VARCHAR(50),
    po_approval_requested_at DATETIME,
    po_approval_review VARCHAR(255),
    po_items_snapshot VARCHAR(255),
    po_linked_documents VARCHAR(255),
    po_revision_history VARCHAR(255),
    created_at DATETIME,
    updated_at DATETIME,
    PRIMARY KEY (po_id)
);

CREATE TABLE po_items (
    po_item_id INT NOT NULL,
    po_id VARCHAR(20) NOT NULL,
    item_id INT,
    po_item_name VARCHAR(100),
    po_item_qty INT,
    po_item_unit VARCHAR(20),
    po_item_unit_price BIGINT,
    po_item_amount BIGINT,
    po_item_remark VARCHAR(255),
    PRIMARY KEY (po_item_id)
);

CREATE TABLE commercial_invoices (
    ci_id VARCHAR(20) NOT NULL,
    po_id VARCHAR(20),
    ci_invoice_date DATE,
    client_id INT,
    currency_id INT,
    ci_total_amount BIGINT,
    ci_status VARCHAR(20) NOT NULL,
    ci_client_name VARCHAR(100),
    ci_client_address VARCHAR(255),
    ci_country VARCHAR(100),
    ci_currency_code VARCHAR(10),
    ci_payment_terms VARCHAR(100),
    ci_port_of_discharge VARCHAR(100),
    ci_buyer VARCHAR(100),
    ci_items_snapshot VARCHAR(255),
    ci_linked_documents VARCHAR(255),
    created_at DATETIME,
    PRIMARY KEY (ci_id)
);

CREATE TABLE packing_lists (
    pl_id VARCHAR(20) NOT NULL,
    po_id VARCHAR(20),
    pl_invoice_date DATE,
    client_id INT,
    pl_gross_weight BIGINT,
    pl_status VARCHAR(20) NOT NULL,
    pl_client_name VARCHAR(100),
    pl_client_address VARCHAR(255),
    pl_country VARCHAR(100),
    pl_payment_terms VARCHAR(100),
    pl_port_of_discharge VARCHAR(100),
    pl_buyer VARCHAR(100),
    pl_items_snapshot VARCHAR(255),
    pl_linked_documents VARCHAR(255),
    created_at DATETIME,
    PRIMARY KEY (pl_id)
);

CREATE TABLE production_orders (
    production_order_id VARCHAR(20) NOT NULL,
    po_id VARCHAR(20),
    production_issue_date DATE,
    client_id INT,
    manager_id INT,
    production_status VARCHAR(20) NOT NULL,
    production_due_date DATE,
    production_client_name VARCHAR(100),
    production_country VARCHAR(100),
    production_manager_name VARCHAR(50),
    production_item_name VARCHAR(100),
    production_linked_documents VARCHAR(255),
    created_at DATETIME,
    updated_at DATETIME,
    PRIMARY KEY (production_order_id)
);

CREATE TABLE shipment_orders (
    shipment_order_id VARCHAR(20) NOT NULL,
    po_id VARCHAR(20),
    shipment_issue_date DATE,
    client_id INT,
    manager_id INT,
    shipment_status VARCHAR(20) NOT NULL,
    shipment_due_date DATE,
    shipment_client_name VARCHAR(100),
    shipment_country VARCHAR(100),
    shipment_manager_name VARCHAR(50),
    shipment_item_name VARCHAR(100),
    shipment_linked_documents VARCHAR(255),
    created_at DATETIME,
    updated_at DATETIME,
    PRIMARY KEY (shipment_order_id)
);

CREATE TABLE approval_requests (
    approval_request_id INT NOT NULL,
    approval_document_type VARCHAR(10) NOT NULL,
    approval_document_id VARCHAR(20) NOT NULL,
    approval_request_type VARCHAR(20) NOT NULL,
    approval_requester_id INT NOT NULL,
    approval_approver_id INT,
    approval_status VARCHAR(10) NOT NULL,
    approval_review_snapshot VARCHAR(255),
    approval_requested_at DATETIME,
    approval_reviewed_at DATETIME,
    PRIMARY KEY (approval_request_id)
);

CREATE TABLE collections (
    collection_id INT NOT NULL,
    po_id VARCHAR(20),
    client_id INT,
    manager_id INT,
    currency_id INT,
    collection_sales_amount BIGINT,
    collection_issue_date DATE,
    collection_completed_date DATE,
    collection_status VARCHAR(20) NOT NULL,
    created_at DATETIME,
    updated_at DATETIME,
    PRIMARY KEY (collection_id)
);

CREATE TABLE shipments (
    shipment_id INT NOT NULL,
    po_id VARCHAR(20),
    shipment_order_id VARCHAR(20),
    client_id INT,
    shipment_request_date DATE,
    shipment_due_date DATE,
    shipment_status VARCHAR(20) NOT NULL,
    created_at DATETIME,
    updated_at DATETIME,
    PRIMARY KEY (shipment_id)
);

CREATE TABLE activities (
    activity_id INT NOT NULL,
    client_id INT,
    po_id VARCHAR(20),
    activity_author_id INT,
    activity_date DATE,
    activity_type VARCHAR(20) NOT NULL,
    activity_title VARCHAR(200) NOT NULL,
    activity_content VARCHAR(255),
    activity_priority VARCHAR(10) NOT NULL,
    activity_schedule_from DATE,
    activity_schedule_to DATE,
    created_at DATETIME,
    updated_at DATETIME,
    PRIMARY KEY (activity_id)
);

CREATE TABLE contacts (
    contact_id INT NOT NULL,
    client_id INT NOT NULL,
    writer_id INT NOT NULL,
    contact_name VARCHAR(50) NOT NULL,
    contact_position VARCHAR(50),
    contact_email VARCHAR(100),
    contact_tel VARCHAR(30),
    created_at DATETIME,
    updated_at DATETIME,
    PRIMARY KEY (contact_id)
);

CREATE TABLE email_logs (
    email_log_id INT NOT NULL,
    client_id INT,
    po_id VARCHAR(20),
    email_title VARCHAR(200),
    email_recipient_name VARCHAR(50),
    email_recipient_email VARCHAR(100),
    email_sender_id INT,
    email_status VARCHAR(10) NOT NULL,
    email_sent_at DATETIME,
    created_at DATETIME,
    PRIMARY KEY (email_log_id)
);

CREATE TABLE email_log_types (
    email_log_type_id INT NOT NULL,
    email_log_id INT NOT NULL,
    email_doc_type VARCHAR(10) NOT NULL,
    PRIMARY KEY (email_log_type_id)
);

CREATE TABLE email_log_attachments (
    email_log_attachment_id INT NOT NULL,
    email_log_id INT NOT NULL,
    email_attachment_filename VARCHAR(255) NOT NULL,
    PRIMARY KEY (email_log_attachment_id)
);

CREATE TABLE activity_packages (
    package_id INT NOT NULL,
    package_title VARCHAR(100) NOT NULL,
    package_description VARCHAR(255),
    po_id VARCHAR(20),
    creator_id INT NOT NULL,
    created_at DATETIME,
    updated_at DATETIME,
    PRIMARY KEY (package_id)
);

CREATE TABLE activity_package_viewers (
    package_viewer_id INT NOT NULL,
    package_id INT NOT NULL,
    user_id INT NOT NULL,
    PRIMARY KEY (package_viewer_id)
);

CREATE TABLE activity_package_items (
    package_item_id INT NOT NULL,
    package_id INT NOT NULL,
    activity_id INT NOT NULL,
    PRIMARY KEY (package_item_id)
);

ALTER TABLE users ADD FOREIGN KEY (department_id) REFERENCES departments (department_id);
ALTER TABLE users ADD FOREIGN KEY (position_id) REFERENCES positions (position_id);
ALTER TABLE refresh_tokens ADD FOREIGN KEY (user_id) REFERENCES users (user_id);
ALTER TABLE ports ADD FOREIGN KEY (country_id) REFERENCES countries (country_id);
ALTER TABLE clients ADD FOREIGN KEY (country_id) REFERENCES countries (country_id);
ALTER TABLE clients ADD FOREIGN KEY (port_id) REFERENCES ports (port_id);
ALTER TABLE clients ADD FOREIGN KEY (payment_term_id) REFERENCES payment_terms (payment_term_id);
ALTER TABLE clients ADD FOREIGN KEY (currency_id) REFERENCES currencies (currency_id);
ALTER TABLE clients ADD FOREIGN KEY (department_id) REFERENCES departments (department_id);
ALTER TABLE buyers ADD FOREIGN KEY (client_id) REFERENCES clients (client_id);
ALTER TABLE pi_items ADD FOREIGN KEY (pi_id) REFERENCES proforma_invoices (pi_id);
ALTER TABLE pi_items ADD FOREIGN KEY (item_id) REFERENCES items (item_id);
ALTER TABLE purchase_orders ADD FOREIGN KEY (pi_id) REFERENCES proforma_invoices (pi_id);
ALTER TABLE po_items ADD FOREIGN KEY (po_id) REFERENCES purchase_orders (po_id);
ALTER TABLE po_items ADD FOREIGN KEY (item_id) REFERENCES items (item_id);
ALTER TABLE commercial_invoices ADD FOREIGN KEY (po_id) REFERENCES purchase_orders (po_id);
ALTER TABLE packing_lists ADD FOREIGN KEY (po_id) REFERENCES purchase_orders (po_id);
ALTER TABLE production_orders ADD FOREIGN KEY (po_id) REFERENCES purchase_orders (po_id);
ALTER TABLE shipment_orders ADD FOREIGN KEY (po_id) REFERENCES purchase_orders (po_id);
ALTER TABLE collections ADD FOREIGN KEY (po_id) REFERENCES purchase_orders (po_id);
ALTER TABLE shipments ADD FOREIGN KEY (po_id) REFERENCES purchase_orders (po_id);
ALTER TABLE shipments ADD FOREIGN KEY (shipment_order_id) REFERENCES shipment_orders (shipment_order_id);
ALTER TABLE proforma_invoices ADD FOREIGN KEY (client_id) REFERENCES clients (client_id);
ALTER TABLE proforma_invoices ADD FOREIGN KEY (currency_id) REFERENCES currencies (currency_id);
ALTER TABLE proforma_invoices ADD FOREIGN KEY (manager_id) REFERENCES users (user_id);
ALTER TABLE purchase_orders ADD FOREIGN KEY (client_id) REFERENCES clients (client_id);
ALTER TABLE purchase_orders ADD FOREIGN KEY (currency_id) REFERENCES currencies (currency_id);
ALTER TABLE purchase_orders ADD FOREIGN KEY (manager_id) REFERENCES users (user_id);
ALTER TABLE commercial_invoices ADD FOREIGN KEY (client_id) REFERENCES clients (client_id);
ALTER TABLE commercial_invoices ADD FOREIGN KEY (currency_id) REFERENCES currencies (currency_id);
ALTER TABLE packing_lists ADD FOREIGN KEY (client_id) REFERENCES clients (client_id);
ALTER TABLE production_orders ADD FOREIGN KEY (client_id) REFERENCES clients (client_id);
ALTER TABLE production_orders ADD FOREIGN KEY (manager_id) REFERENCES users (user_id);
ALTER TABLE shipment_orders ADD FOREIGN KEY (client_id) REFERENCES clients (client_id);
ALTER TABLE shipment_orders ADD FOREIGN KEY (manager_id) REFERENCES users (user_id);
ALTER TABLE approval_requests ADD FOREIGN KEY (approval_requester_id) REFERENCES users (user_id);
ALTER TABLE approval_requests ADD FOREIGN KEY (approval_approver_id) REFERENCES users (user_id);
ALTER TABLE collections ADD FOREIGN KEY (client_id) REFERENCES clients (client_id);
ALTER TABLE collections ADD FOREIGN KEY (manager_id) REFERENCES users (user_id);
ALTER TABLE collections ADD FOREIGN KEY (currency_id) REFERENCES currencies (currency_id);
ALTER TABLE shipments ADD FOREIGN KEY (client_id) REFERENCES clients (client_id);
ALTER TABLE activities ADD FOREIGN KEY (client_id) REFERENCES clients (client_id);
ALTER TABLE activities ADD FOREIGN KEY (po_id) REFERENCES purchase_orders (po_id);
ALTER TABLE activities ADD FOREIGN KEY (activity_author_id) REFERENCES users (user_id);
ALTER TABLE contacts ADD FOREIGN KEY (client_id) REFERENCES clients (client_id);
ALTER TABLE contacts ADD FOREIGN KEY (writer_id) REFERENCES users (user_id);
ALTER TABLE email_logs ADD FOREIGN KEY (client_id) REFERENCES clients (client_id);
ALTER TABLE email_logs ADD FOREIGN KEY (po_id) REFERENCES purchase_orders (po_id);
ALTER TABLE email_logs ADD FOREIGN KEY (email_sender_id) REFERENCES users (user_id);
ALTER TABLE email_log_types ADD FOREIGN KEY (email_log_id) REFERENCES email_logs (email_log_id);
ALTER TABLE email_log_attachments ADD FOREIGN KEY (email_log_id) REFERENCES email_logs (email_log_id);
ALTER TABLE activity_packages ADD FOREIGN KEY (creator_id) REFERENCES users (user_id);
ALTER TABLE activity_packages ADD FOREIGN KEY (po_id) REFERENCES purchase_orders (po_id);
ALTER TABLE activity_package_viewers ADD FOREIGN KEY (package_id) REFERENCES activity_packages (package_id);
ALTER TABLE activity_package_viewers ADD FOREIGN KEY (user_id) REFERENCES users (user_id);
ALTER TABLE activity_package_items ADD FOREIGN KEY (package_id) REFERENCES activity_packages (package_id);
ALTER TABLE activity_package_items ADD FOREIGN KEY (activity_id) REFERENCES activities (activity_id);
