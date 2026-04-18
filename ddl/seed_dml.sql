-- ============================================================
-- Seed DML — 전 서비스 정합성 있는 샘플 데이터
-- 실행 순서: integrated_ddl.sql 이후
-- 조직: departments(4) → teams(부서별 2팀) → users(팀 할당)
-- 비즈니스: clients → buyers / items → PI → PO → CI/PL/생산/출하지시서 → collections/shipments
-- 활동: activities / contacts / email_logs / activity_packages
-- ============================================================

-- 기존 데이터 제거 (FK 역순)
DELETE FROM activity_package_items;
DELETE FROM activity_package_viewers;
DELETE FROM activity_packages;
DELETE FROM email_log_attachments;
DELETE FROM email_log_types;
DELETE FROM email_logs;
DELETE FROM contacts;
DELETE FROM activities;
DELETE FROM shipments;
DELETE FROM collections;
DELETE FROM approval_requests;
DELETE FROM shipment_orders;
DELETE FROM production_orders;
DELETE FROM packing_lists;
DELETE FROM commercial_invoices;
DELETE FROM po_items;
DELETE FROM purchase_orders;
DELETE FROM pi_items;
DELETE FROM proforma_invoices;
DELETE FROM buyers;
DELETE FROM items;
DELETE FROM clients;
DELETE FROM payment_terms;
DELETE FROM ports;
DELETE FROM currencies;
DELETE FROM incoterms;
DELETE FROM countries;
DELETE FROM refresh_tokens;
DELETE FROM company;
DELETE FROM users;
DELETE FROM teams;
DELETE FROM departments;
DELETE FROM positions;

-- ============================================================
-- 1. 자사정보 (company)
-- ============================================================
INSERT INTO company (company_id, company_name, company_address_en, company_address_kr, company_tel, company_fax, company_email, company_website, updated_at) VALUES
(1, 'SalesBoost Co., Ltd.',
 '123 Teheran-ro, Gangnam-gu, Seoul, Republic of Korea',
 '서울특별시 강남구 테헤란로 123',
 '+82-2-1234-5678', '+82-2-1234-5679',
 'contact@salesboost.co.kr', 'https://www.salesboost.co.kr', NOW());

-- ============================================================
-- 2. 직급 (positions)
-- ============================================================
INSERT INTO positions (position_id, position_name, position_level, created_at) VALUES
(1, '사원',   1, NOW()),
(2, '대리',   2, NOW()),
(3, '과장',   3, NOW()),
(4, '차장',   4, NOW()),
(5, '부장',   5, NOW()),
(6, '이사',   6, NOW()),
(7, '대표이사', 7, NOW());

-- ============================================================
-- 3. 부서 (departments)
-- ============================================================
INSERT INTO departments (department_id, department_name, created_at) VALUES
(1, '영업부',   NOW()),
(2, '생산부',   NOW()),
(3, '출하부',   NOW()),
(4, '관리부',   NOW());

-- ============================================================
-- 4. 팀 (teams) — 부서별 2팀
-- ============================================================
INSERT INTO teams (team_id, team_name, department_id, created_at) VALUES
(1, '영업1팀',   1, NOW()),
(2, '영업2팀',   1, NOW()),
(3, '생산1팀',   2, NOW()),
(4, '생산2팀',   2, NOW()),
(5, '출하1팀',   3, NOW()),
(6, '출하2팀',   3, NOW()),
(7, '관리1팀',   4, NOW()),
(8, '관리2팀',   4, NOW());

-- ============================================================
-- 5. 사용자 (users) — team_id 로 조직 결정
--    user_pw: bcrypt of 'password123'
-- ============================================================
INSERT INTO users (user_id, employee_no, user_name, user_email, user_pw, user_role, team_id, position_id, user_status, created_at, updated_at) VALUES
-- admin
(1, '26030101', '최관리', 'admin@hanwha.com',
 '$2a$10$N9qo8uLOickgx2ZMRZoMye.IjdQRJqZvr4V.0w9CZu0xmOxSWJQ7C',
 'admin', 7, 7, 'active', NOW(), NOW()),
-- 영업부
(2, '26030102', '김영업', 'kim.sales@hanwha.com',
 '$2a$10$N9qo8uLOickgx2ZMRZoMye.IjdQRJqZvr4V.0w9CZu0xmOxSWJQ7C',
 'sales', 1, 5, 'active', NOW(), NOW()),
(3, '26030103', '이영업', 'lee.sales@hanwha.com',
 '$2a$10$N9qo8uLOickgx2ZMRZoMye.IjdQRJqZvr4V.0w9CZu0xmOxSWJQ7C',
 'sales', 1, 3, 'active', NOW(), NOW()),
(4, '26030104', '박영업', 'park.sales@hanwha.com',
 '$2a$10$N9qo8uLOickgx2ZMRZoMye.IjdQRJqZvr4V.0w9CZu0xmOxSWJQ7C',
 'sales', 2, 3, 'active', NOW(), NOW()),
(5, '26030105', '최영업', 'choi.sales@hanwha.com',
 '$2a$10$N9qo8uLOickgx2ZMRZoMye.IjdQRJqZvr4V.0w9CZu0xmOxSWJQ7C',
 'sales', 2, 2, 'active', NOW(), NOW()),
-- 생산부
(6, '26030201', '김생산', 'kim.prod@hanwha.com',
 '$2a$10$N9qo8uLOickgx2ZMRZoMye.IjdQRJqZvr4V.0w9CZu0xmOxSWJQ7C',
 'production', 3, 5, 'active', NOW(), NOW()),
(7, '26030202', '최생산', 'choi.prod@hanwha.com',
 '$2a$10$N9qo8uLOickgx2ZMRZoMye.IjdQRJqZvr4V.0w9CZu0xmOxSWJQ7C',
 'production', 3, 3, 'active', NOW(), NOW()),
(8, '26030203', '박생산', 'park.prod@hanwha.com',
 '$2a$10$N9qo8uLOickgx2ZMRZoMye.IjdQRJqZvr4V.0w9CZu0xmOxSWJQ7C',
 'production', 4, 2, 'active', NOW(), NOW()),
-- 출하부
(9,  '26030301', '정출하', 'jung.ship@hanwha.com',
 '$2a$10$N9qo8uLOickgx2ZMRZoMye.IjdQRJqZvr4V.0w9CZu0xmOxSWJQ7C',
 'shipping', 5, 5, 'active', NOW(), NOW()),
(10, '26030302', '이출하', 'lee.ship@hanwha.com',
 '$2a$10$N9qo8uLOickgx2ZMRZoMye.IjdQRJqZvr4V.0w9CZu0xmOxSWJQ7C',
 'shipping', 5, 3, 'active', NOW(), NOW()),
(11, '26030303', '박출하', 'park.ship@hanwha.com',
 '$2a$10$N9qo8uLOickgx2ZMRZoMye.IjdQRJqZvr4V.0w9CZu0xmOxSWJQ7C',
 'shipping', 6, 2, 'active', NOW(), NOW());

-- ============================================================
-- 6. 마스터 기준정보
-- ============================================================
INSERT INTO countries (country_id, country_code, country_name, country_name_kr) VALUES
(1, 'KR', 'Republic of Korea', '대한민국'),
(2, 'US', 'United States', '미국'),
(3, 'JP', 'Japan', '일본'),
(4, 'CN', 'China', '중국'),
(5, 'DE', 'Germany', '독일'),
(6, 'VN', 'Vietnam', '베트남');

INSERT INTO incoterms (incoterm_id, incoterm_code, incoterm_name, incoterm_name_kr, incoterm_transport_mode, incoterm_seller_segments, incoterm_default_named_place) VALUES
(1, 'EXW', 'Ex Works',                   '공장인도조건',       'ANY', 'MIN', 'Seller factory'),
(2, 'FOB', 'Free On Board',               '본선인도조건',       'SEA', 'MID', 'Port of loading'),
(3, 'CIF', 'Cost Insurance and Freight',  '운임보험료포함인도', 'SEA', 'MID', 'Port of discharge'),
(4, 'DDP', 'Delivered Duty Paid',         '관세지급반입인도',   'ANY', 'MAX', 'Buyer premises');

INSERT INTO currencies (currency_id, currency_code, currency_name, currency_symbol) VALUES
(1, 'KRW', '대한민국 원', '₩'),
(2, 'USD', '미국 달러',   '$'),
(3, 'JPY', '일본 엔',     '¥'),
(4, 'EUR', '유로',        '€'),
(5, 'CNY', '중국 위안',   '¥');

INSERT INTO ports (port_id, port_code, port_name, port_city, country_id) VALUES
(1, 'KRPUS', 'Busan Port',     'Busan',     1),
(2, 'KRINC', 'Incheon Port',   'Incheon',   1),
(3, 'USLAX', 'Los Angeles',    'Los Angeles', 2),
(4, 'USNYC', 'New York',       'New York',    2),
(5, 'JPTYO', 'Tokyo Port',     'Tokyo',     3),
(6, 'CNSHA', 'Shanghai',       'Shanghai',  4),
(7, 'DEHAM', 'Hamburg',        'Hamburg',   5),
(8, 'VNSGN', 'Ho Chi Minh',    'Ho Chi Minh', 6);

INSERT INTO payment_terms (payment_term_id, payment_term_code, payment_term_name, payment_term_description) VALUES
(1, 'TT_ADV',   'T/T in Advance',        '선입금 T/T'),
(2, 'TT_30',    'T/T 30 days',            '출하 후 30일 T/T'),
(3, 'LC_AT_SIGHT', 'L/C at sight',        '일람불 신용장'),
(4, 'LC_60',    'L/C 60 days',            '기한부 신용장 60일'),
(5, 'DP',       'D/P',                    'Documents against Payment'),
(6, 'DA_30',    'D/A 30 days',            'Documents against Acceptance 30일');

-- ============================================================
-- 7. 거래처 (clients) — team_id 로 담당 팀 지정
-- ============================================================
INSERT INTO clients (client_id, client_code, client_name, client_name_kr, country_id, client_city, port_id, client_address, client_tel, client_email, payment_term_id, currency_id, client_manager, team_id, client_status, client_reg_date, created_at, updated_at) VALUES
(1, 'CL0001', 'Acme Global Inc.',       '에이씨엠이 글로벌', 2, 'Los Angeles', 3,
 '100 Sunset Blvd, Los Angeles, CA 90028, USA', '+1-213-555-0100', 'order@acme-global.com',
 2, 2, 'John Smith', 1, 'active', '2025-01-15', NOW(), NOW()),

(2, 'CL0002', 'Tokyo Trading Co.',       '도쿄트레이딩',     3, 'Tokyo', 5,
 '2-1 Marunouchi, Chiyoda-ku, Tokyo, Japan', '+81-3-5555-0200', 'info@tokyo-trading.co.jp',
 3, 3, '타나카 히로시', 1, 'active', '2025-02-01', NOW(), NOW()),

(3, 'CL0003', 'Shanghai Imports Ltd.',  '상하이임포트',     4, 'Shanghai', 6,
 '888 Nanjing Rd, Huangpu, Shanghai, China', '+86-21-5555-0300', 'sales@shanghai-imp.cn',
 4, 5, '王 伟', 2, 'active', '2025-02-10', NOW(), NOW()),

(4, 'CL0004', 'Berlin Trade GmbH',      '베를린트레이드',   5, 'Hamburg', 7,
 'Hafenstraße 1, 20359 Hamburg, Germany', '+49-40-5555-0400', 'kontakt@berlin-trade.de',
 3, 4, 'Hans Müller', 2, 'active', '2025-03-01', NOW(), NOW()),

(5, 'CL0005', 'Saigon Partners',        '사이공파트너스',   6, 'Ho Chi Minh', 8,
 '15 Nguyen Hue, District 1, Ho Chi Minh City, Vietnam', '+84-28-5555-0500', 'contact@saigon-partners.vn',
 2, 2, 'Nguyen Van A', 1, 'inactive', '2024-11-10', NOW(), NOW());

-- ============================================================
-- 8. 바이어 (buyers)
-- ============================================================
INSERT INTO buyers (buyer_id, client_id, buyer_name, buyer_position, buyer_email, buyer_tel, created_at, updated_at) VALUES
(1, 1, 'John Smith',     '팀장', 'john.smith@acme-global.com', '+1-213-555-0101', NOW(), NOW()),
(2, 1, 'Mary Johnson',   '팀원', 'mary.j@acme-global.com',     '+1-213-555-0102', NOW(), NOW()),
(3, 2, '타나카 히로시',  '팀장', 'tanaka@tokyo-trading.co.jp',  '+81-3-5555-0201', NOW(), NOW()),
(4, 2, '사토 유키',      '팀원', 'sato@tokyo-trading.co.jp',    '+81-3-5555-0202', NOW(), NOW()),
(5, 3, '王 伟',          '팀장', 'wang.wei@shanghai-imp.cn',    '+86-21-5555-0301', NOW(), NOW()),
(6, 4, 'Hans Müller',    '팀장', 'hans.m@berlin-trade.de',      '+49-40-5555-0401', NOW(), NOW()),
(7, 5, 'Nguyen Van A',   '팀장', 'nguyen.a@saigon-partners.vn', '+84-28-5555-0501', NOW(), NOW());

-- ============================================================
-- 9. 품목 (items)
-- ============================================================
INSERT INTO items (item_id, item_code, item_name, item_name_kr, item_spec, item_width, item_depth, item_height, item_unit, item_pack_unit, item_unit_price, item_weight, item_hs_code, item_category, item_status, item_reg_date, created_at, updated_at) VALUES
(1, 'ITM0001', 'Office Desk A1',  '사무용 책상 A1',   '1400 × 700 × 720 mm', 1400, 700, 720, 'EA',     'CTN', 150.00, 25.500, '940330', '가구', 'active', '2025-01-10', NOW(), NOW()),
(2, 'ITM0002', 'Office Chair B2', '사무용 의자 B2',   '600 × 600 × 1100 mm',  600, 600, 1100, 'EA',    'CTN',  85.00, 12.300, '940130', '가구', 'active', '2025-01-10', NOW(), NOW()),
(3, 'ITM0003', 'Bookshelf C3',    '책장 C3',          '900 × 300 × 1800 mm',  900, 300, 1800, 'EA',    'CTN', 120.00, 30.000, '940340', '가구', 'active', '2025-01-15', NOW(), NOW()),
(4, 'ITM0004', 'Meeting Table D4','회의 테이블 D4',   '2400 × 1200 × 720 mm', 2400, 1200, 720, 'EA',   'CTN', 450.00, 68.000, '940360', '가구', 'active', '2025-01-20', NOW(), NOW()),
(5, 'ITM0005', 'Filing Cabinet E5','서류함 E5',        '800 × 450 × 1320 mm',   800, 450, 1320, 'EA',   'CTN', 180.00, 35.000, '940320', '가구', 'active', '2025-02-01', NOW(), NOW());

-- ============================================================
-- 10. PI — 견적송장
-- ============================================================
INSERT INTO proforma_invoices (pi_id, pi_code, pi_issue_date, client_id, currency_id, manager_id, pi_status, pi_delivery_date, pi_incoterms_code, pi_named_place, pi_total_amount, pi_client_name, pi_client_address, pi_country, pi_currency_code, pi_manager_name, created_at, updated_at) VALUES
(1, 'PI250001', '2025-03-01', 1, 2, 2, 'confirmed', '2025-04-15', 'FOB', 'Busan Port',
 15000.00, 'Acme Global Inc.', '100 Sunset Blvd, Los Angeles, CA 90028, USA', 'United States', 'USD', '김영업', NOW(), NOW()),
(2, 'PI250002', '2025-03-05', 2, 3, 3, 'confirmed', '2025-04-20', 'CIF', 'Tokyo Port',
 510000.00, 'Tokyo Trading Co.', '2-1 Marunouchi, Chiyoda-ku, Tokyo, Japan', 'Japan', 'JPY', '이영업', NOW(), NOW()),
(3, 'PI250003', '2025-03-10', 3, 5, 4, 'draft', '2025-05-01', 'FOB', 'Shanghai Port',
 48000.00, 'Shanghai Imports Ltd.', '888 Nanjing Rd, Huangpu, Shanghai, China', 'China', 'CNY', '박영업', NOW(), NOW());

INSERT INTO pi_items (pi_item_id, pi_id, item_id, pi_item_name, pi_item_qty, pi_item_unit, pi_item_unit_price, pi_item_amount, pi_item_remark) VALUES
(1, 1, 1, 'Office Desk A1',   50, 'EA', 150.00,  7500.00, NULL),
(2, 1, 2, 'Office Chair B2',  50, 'EA',  85.00,  4250.00, NULL),
(3, 1, 3, 'Bookshelf C3',     25, 'EA', 120.00,  3000.00, NULL),
(4, 1, 5, 'Filing Cabinet E5', 0, 'EA', 180.00,   250.00, 'sample'),
(5, 2, 4, 'Meeting Table D4', 10, 'EA', 45000.00, 450000.00, NULL),
(6, 2, 1, 'Office Desk A1',    4, 'EA', 15000.00,  60000.00, NULL),
(7, 3, 2, 'Office Chair B2', 200, 'EA',   180.00,  36000.00, NULL),
(8, 3, 5, 'Filing Cabinet E5', 30, 'EA',   400.00,  12000.00, NULL);

-- ============================================================
-- 11. PO — 발주서
-- ============================================================
-- pi_id 는 VARCHAR(30) 으로 proforma_invoices.pi_code 를 참조 (fk_po_pi → pi_code).
-- po_delivery_date_override NOT NULL 필수.
INSERT INTO purchase_orders (po_id, po_code, pi_id, po_issue_date, client_id, currency_id, manager_id, po_status, po_delivery_date, po_incoterms_code, po_named_place, po_delivery_date_override, po_total_amount, po_client_name, po_client_address, po_country, po_currency_code, po_manager_name, created_at, updated_at) VALUES
(1, 'PO250001', 'PI250001', '2025-03-15', 1, 2, 2, 'confirmed', '2025-04-15', 'FOB', 'Busan Port', FALSE,
 15000.00, 'Acme Global Inc.', '100 Sunset Blvd, Los Angeles, CA 90028, USA', 'United States', 'USD', '김영업', NOW(), NOW()),
(2, 'PO250002', 'PI250002', '2025-03-20', 2, 3, 3, 'confirmed', '2025-04-20', 'CIF', 'Tokyo Port', FALSE,
 510000.00, 'Tokyo Trading Co.', '2-1 Marunouchi, Chiyoda-ku, Tokyo, Japan', 'Japan', 'JPY', '이영업', NOW(), NOW());

INSERT INTO po_items (po_item_id, po_id, item_id, po_item_name, po_item_qty, po_item_unit, po_item_unit_price, po_item_amount, po_item_remark) VALUES
(1, 1, 1, 'Office Desk A1',   50, 'EA',  150.00,   7500.00, NULL),
(2, 1, 2, 'Office Chair B2',  50, 'EA',   85.00,   4250.00, NULL),
(3, 1, 3, 'Bookshelf C3',     25, 'EA',  120.00,   3000.00, NULL),
(4, 1, 5, 'Filing Cabinet E5', 1, 'EA',  180.00,    250.00, 'sample'),
(5, 2, 4, 'Meeting Table D4', 10, 'EA', 45000.00, 450000.00, NULL),
(6, 2, 1, 'Office Desk A1',    4, 'EA', 15000.00,  60000.00, NULL);

-- ============================================================
-- 12. CI / PL — 상업송장 / 포장명세서
-- ============================================================
INSERT INTO commercial_invoices (ci_id, ci_code, po_id, ci_invoice_date, client_id, currency_id, ci_total_amount, ci_status, ci_client_name, ci_client_address, ci_country, ci_currency_code, ci_payment_terms, ci_port_of_discharge, ci_buyer, created_at) VALUES
(1, 'CI250001', 1, '2025-04-10', 1, 2, 15000.00, 'issued',
 'Acme Global Inc.', '100 Sunset Blvd, Los Angeles, CA 90028, USA', 'United States', 'USD',
 'T/T 30 days', 'Los Angeles', 'John Smith', NOW());

INSERT INTO packing_lists (pl_id, pl_code, po_id, pl_invoice_date, client_id, pl_gross_weight, pl_status, pl_client_name, pl_client_address, pl_country, pl_payment_terms, pl_port_of_discharge, pl_buyer, created_at) VALUES
(1, 'PL250001', 1, '2025-04-10', 1, 2485.00, 'issued',
 'Acme Global Inc.', '100 Sunset Blvd, Los Angeles, CA 90028, USA', 'United States',
 'T/T 30 days', 'Los Angeles', 'John Smith', NOW());

-- ============================================================
-- 13. 생산지시서 / 출하지시서
-- ============================================================
INSERT INTO production_orders (production_order_id, production_order_code, po_id, production_issue_date, client_id, manager_id, production_status, production_due_date, production_client_name, production_country, production_manager_name, production_item_name, created_at, updated_at) VALUES
(1, 'MO250001', 1, '2025-03-20', 1, 6, 'completed',  '2025-04-05', 'Acme Global Inc.',   'United States', '김생산', 'Office Desk A1 외 3건', NOW(), NOW()),
(2, 'MO250002', 2, '2025-03-25', 2, 7, 'in_progress','2025-04-10', 'Tokyo Trading Co.',  'Japan',         '최생산', 'Meeting Table D4 외 1건', NOW(), NOW());

INSERT INTO shipment_orders (shipment_order_id, shipment_order_code, po_id, shipment_issue_date, client_id, manager_id, shipment_status, shipment_due_date, shipment_client_name, shipment_country, shipment_manager_name, shipment_item_name, created_at, updated_at) VALUES
(1, 'SO250001', 1, '2025-04-06', 1, 9,  'completed', '2025-04-15', 'Acme Global Inc.',  'United States', '정출하', 'Office Desk A1 외 3건', NOW(), NOW()),
(2, 'SO250002', 2, '2025-04-11', 2, 10, 'preparing', '2025-04-20', 'Tokyo Trading Co.', 'Japan',         '이출하', 'Meeting Table D4 외 1건', NOW(), NOW());

-- ============================================================
-- 14. 수금현황 (collections) / 출하현황 (shipments)
-- ============================================================
INSERT INTO collections (collection_id, po_id, client_id, manager_id, currency_id, collection_sales_amount, collection_issue_date, collection_completed_date, collection_status, created_at, updated_at) VALUES
(1, 1, 1, 2, 2, 15000.00, '2025-04-10', '2025-04-25', 'paid',   NOW(), NOW()),
(2, 2, 2, 3, 3, 510000.00,'2025-04-15', NULL,         'unpaid', NOW(), NOW());

INSERT INTO shipments (shipment_id, po_id, shipment_order_id, client_id, shipment_request_date, shipment_due_date, shipment_status, created_at, updated_at) VALUES
(1, 1, 1, 1, '2025-04-06', '2025-04-15', 'completed', NOW(), NOW()),
(2, 2, 2, 2, '2025-04-11', '2025-04-20', 'preparing', NOW(), NOW());

-- ============================================================
-- 15. 결재 요청 (approval_requests)
-- ============================================================
INSERT INTO approval_requests (approval_request_id, approval_document_type, approval_document_id, approval_request_type, approval_requester_id, approval_approver_id, approval_comment, approval_status, approval_requested_at, approval_reviewed_at) VALUES
(1, 'PI', 'PI250001', 'registration', 2, 1, 'Acme PI 등록 승인 요청', 'approved', '2025-03-01 10:00:00', '2025-03-01 14:00:00'),
(2, 'PO', 'PO250001', 'registration', 2, 1, 'Acme PO 등록 승인 요청', 'approved', '2025-03-15 10:00:00', '2025-03-15 15:00:00'),
(3, 'PI', 'PI250003', 'registration', 4, 1, 'Shanghai PI 등록 승인 요청', 'pending',  '2025-03-10 11:00:00', NULL);

-- ============================================================
-- 16. 활동 (activities) — 기록
-- ============================================================
INSERT INTO activities (activity_id, client_id, po_id, activity_author_id, activity_date, activity_type, activity_title, activity_content, activity_priority, activity_schedule_from, activity_schedule_to, created_at, updated_at) VALUES
(1, 1, 'PO250001', 2, '2025-03-05', 'meeting',  'Acme 첫 미팅',        'Acme 본사 방문하여 요구사항 논의',                   NULL, NULL, NULL, NOW(), NOW()),
(2, 1, 'PO250001', 2, '2025-03-25', 'issue',    '통관 지연 리스크',    'LA 세관 통관 지연 이슈 — 대비책 필요',                'high', NULL, NULL, NOW(), NOW()),
(3, 1, 'PO250001', 2, '2025-04-02', 'memo',     '생산 진행 확인',      '생산팀과 일정 확인 완료',                             NULL, NULL, NULL, NOW(), NOW()),
(4, 2, 'PO250002', 3, '2025-03-10', 'meeting',  '도쿄트레이딩 방문',   '신제품 소개 및 견적 논의',                            NULL, NULL, NULL, NOW(), NOW()),
(5, 2, 'PO250002', 3, '2025-04-15', 'schedule', '도쿄 출장 예정',      '최종 계약 체결을 위한 출장',                         'normal', '2025-04-20', '2025-04-22', NOW(), NOW()),
(6, 3, NULL,         4, '2025-03-08', 'meeting', 'Shanghai 화상회의',   '온라인 화상회의 진행',                                NULL, NULL, NULL, NOW(), NOW());

-- ============================================================
-- 17. 컨택리스트 (contacts) — 바이어와 연동 (영업 담당자별)
-- ============================================================
-- contacts 는 cross-DB FK 금지 원칙으로 client_id 컬럼 제거됨 (루트@0790ca5).
-- writer 기준 개인 컨택. 바이어와 연결은 이메일 중복/동일명 등으로 느슨하게 유지.
INSERT INTO contacts (contact_id, writer_id, contact_name, contact_position, contact_email, contact_tel, created_at, updated_at) VALUES
-- Acme (영업1팀 담당) — 담당자 2, 3
(1, 2, 'John Smith',    '팀장', 'john.smith@acme-global.com', '+1-213-555-0101', NOW(), NOW()),
(2, 2, 'Mary Johnson',  '팀원', 'mary.j@acme-global.com',     '+1-213-555-0102', NOW(), NOW()),
(3, 3, 'John Smith',    '팀장', 'john.smith@acme-global.com', '+1-213-555-0101', NOW(), NOW()),
(4, 3, 'Mary Johnson',  '팀원', 'mary.j@acme-global.com',     '+1-213-555-0102', NOW(), NOW()),
-- Tokyo Trading (영업1팀) — 담당자 2, 3
(5, 2, '타나카 히로시', '팀장', 'tanaka@tokyo-trading.co.jp', '+81-3-5555-0201', NOW(), NOW()),
(6, 2, '사토 유키',     '팀원', 'sato@tokyo-trading.co.jp',   '+81-3-5555-0202', NOW(), NOW()),
(7, 3, '타나카 히로시', '팀장', 'tanaka@tokyo-trading.co.jp', '+81-3-5555-0201', NOW(), NOW()),
(8, 3, '사토 유키',     '팀원', 'sato@tokyo-trading.co.jp',   '+81-3-5555-0202', NOW(), NOW()),
-- Shanghai (영업2팀) — 담당자 4, 5
(9,  4, '王 伟', '팀장', 'wang.wei@shanghai-imp.cn', '+86-21-5555-0301', NOW(), NOW()),
(10, 5, '王 伟', '팀장', 'wang.wei@shanghai-imp.cn', '+86-21-5555-0301', NOW(), NOW()),
-- Berlin (영업2팀) — 담당자 4, 5
(11, 4, 'Hans Müller', '팀장', 'hans.m@berlin-trade.de', '+49-40-5555-0401', NOW(), NOW()),
(12, 5, 'Hans Müller', '팀장', 'hans.m@berlin-trade.de', '+49-40-5555-0401', NOW(), NOW());

-- ============================================================
-- 18. 이메일 발송 이력
-- ============================================================
INSERT INTO email_logs (email_log_id, client_id, po_id, email_title, email_recipient_name, email_recipient_email, email_sender_id, email_status, email_sent_at, created_at) VALUES
(1, 1, 'PO250001', 'PI PO250001 송부 드립니다', 'John Smith',    'john.smith@acme-global.com',  2, 'sent', '2025-03-02 09:00:00', NOW()),
(2, 1, 'PO250001', 'CI/PL 송부',                 'John Smith',    'john.smith@acme-global.com',  2, 'sent', '2025-04-10 14:00:00', NOW()),
(3, 2, 'PO250002', 'PI PI250002 안내',          '타나카 히로시', 'tanaka@tokyo-trading.co.jp',  3, 'sent', '2025-03-06 10:00:00', NOW());

INSERT INTO email_log_types (email_log_type_id, email_log_id, email_doc_type) VALUES
(1, 1, 'PI'),
(2, 2, 'CI'),
(3, 2, 'PL'),
(4, 3, 'PI');

INSERT INTO email_log_attachments (email_log_attachment_id, email_log_id, email_attachment_filename, email_attachment_s3_key) VALUES
(1, 1, 'PI250001.pdf',       'email/2025/03/PI250001.pdf'),
(2, 2, 'CI250001.pdf',       'email/2025/04/CI250001.pdf'),
(3, 2, 'PL250001.pdf',       'email/2025/04/PL250001.pdf'),
(4, 3, 'PI250002.pdf',       'email/2025/03/PI250002.pdf');

-- ============================================================
-- 19. 기록패키지 (activity_packages)
-- ============================================================
INSERT INTO activity_packages (package_id, package_title, package_description, po_id, creator_id, date_from, date_to, created_at, updated_at) VALUES
(1, 'Acme PO250001 진행내역', 'Acme 발주 건 초기 미팅부터 통관 이슈까지', 'PO250001', 2, '2025-03-01', '2025-04-15', NOW(), NOW()),
(2, 'Tokyo Trading 상담 이력', '도쿄트레이딩 신규 개발 과정',              'PO250002', 3, '2025-03-01', '2025-04-20', NOW(), NOW());

INSERT INTO activity_package_items (package_item_id, package_id, activity_id) VALUES
(1, 1, 1),
(2, 1, 2),
(3, 1, 3),
(4, 2, 4),
(5, 2, 5);

INSERT INTO activity_package_viewers (package_viewer_id, package_id, user_id) VALUES
(1, 1, 1),  -- admin
(2, 1, 3),  -- 이영업(같은 팀)
(3, 2, 1),  -- admin
(4, 2, 2);  -- 김영업(같은 팀)
