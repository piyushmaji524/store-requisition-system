-- ============================================================
-- REQUISITION MANAGEMENT SYSTEM - SEED DATA
-- Default Admin, Store User, Sample Users, Locations, Materials, Settings
-- Default Password for all initial users: password123
-- Password Hash: $2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi
-- ============================================================

USE u435643473_reqisition;

-- ------------------------------------------------------------
-- 1. DEPARTMENTS
-- ------------------------------------------------------------
INSERT INTO departments (id, name, status) VALUES
(1, 'Administration', 'ACTIVE'),
(2, 'Store & Inventory', 'ACTIVE'),
(3, 'Civil & Maintenance', 'ACTIVE'),
(4, 'Electrical & Plumbing', 'ACTIVE'),
(5, 'Housekeeping', 'ACTIVE')
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- ------------------------------------------------------------
-- 2. SYSTEM SETTINGS
-- ------------------------------------------------------------
INSERT INTO settings (setting_key, setting_value, description) VALUES
('APP_NAME', 'Store Requisition Management System', 'Application display title'),
('TIMEZONE', 'Asia/Kolkata', 'Authoritative business logic timezone'),
('USER_REQUEST_START', '06:00', 'Daily start time for user requests (HH:mm IST)'),
('USER_REQUEST_END', '20:00', 'Daily cut-off time for user requests (HH:mm IST)'),
('STORE_EDIT_END', '21:00', 'Daily cut-off time for store fulfillment edits (HH:mm IST)'),
('ADMIN_OVERRIDE_HOURS', '2', 'Standard duration in hours for admin past date overrides'),
('DEFAULT_SALES_LEDGER', 'SALE', 'Default sales ledger for Tally voucher generation'),
('SUB_REQ_SUFFIX_MODE', 'SEQUENTIAL', 'Mode for sub requisition suffix: SEQUENTIAL (01, 02) or LOCATION_CODE')
ON DUPLICATE KEY UPDATE setting_value=VALUES(setting_value);

-- ------------------------------------------------------------
-- 3. USERS (Pass: password123)
-- ------------------------------------------------------------
INSERT INTO users (id, employee_code, name, mobile, email, password_hash, role, department_id, status) VALUES
(1, 'EMP-001', 'System Super Admin', '9876543210', 'admin@store.local', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'SUPER_ADMIN', 1, 'ACTIVE'),
(2, 'EMP-002', 'Store Manager', '9876543211', 'store@store.local', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'STORE_USER', 2, 'ACTIVE'),
(3, 'EMP-101', 'Tapas Ji', '9876543220', 'tapas@store.local', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'REQUISITION_USER', 3, 'ACTIVE'),
(4, 'EMP-102', 'Amit Kumar', '9876543221', 'amit@store.local', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'REQUISITION_USER', 3, 'ACTIVE'),
(5, 'EMP-103', 'Ramesh Singh', '9876543222', 'ramesh@store.local', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'REQUISITION_USER', 4, 'ACTIVE'),
(6, 'EMP-104', 'Suresh Yadav', '9876543223', 'suresh@store.local', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'REQUISITION_USER', 5, 'ACTIVE'),
(7, 'EMP-105', 'Pooja Sharma', '9876543224', 'pooja@store.local', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'REQUISITION_USER', 5, 'ACTIVE'),
(8, 'EMP-106', 'Vikram Pal', '9876543225', 'vikram@store.local', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'REQUISITION_USER', 4, 'ACTIVE')
ON DUPLICATE KEY UPDATE name=VALUES(name), role=VALUES(role);

-- ------------------------------------------------------------
-- 4. LOCATIONS MASTER (With Tally Ledger Mapping)
-- ------------------------------------------------------------
INSERT INTO locations (id, name, code, tally_ledger_name, tally_ledger_code, status) VALUES
(1, 'Dharamshala Maintenance', 'LOC-01', 'Dharamshala Maintenance', 'LED-DH-01', 'ACTIVE'),
(2, 'Shimla Site', 'LOC-02', 'Shimla Site', 'LED-SH-02', 'ACTIVE'),
(3, 'Chandigarh Office', 'LOC-03', 'Chandigarh Office', 'LED-CH-03', 'ACTIVE'),
(4, 'Main Complex Maintenance', 'LOC-04', 'Main Complex Maintenance', 'LED-MC-04', 'ACTIVE'),
(5, 'Staff Quarters Maintenance', 'LOC-05', 'Staff Quarters Maintenance', 'LED-SQ-05', 'ACTIVE')
ON DUPLICATE KEY UPDATE name=VALUES(name), tally_ledger_name=VALUES(tally_ledger_name);

-- ------------------------------------------------------------
-- 5. MATERIAL CATEGORIES
-- ------------------------------------------------------------
INSERT INTO material_categories (id, name, status) VALUES
(1, 'Civil & Building Materials', 'ACTIVE'),
(2, 'Cleaning & Housekeeping Supplies', 'ACTIVE'),
(3, 'Electricals & Wiring', 'ACTIVE'),
(4, 'Plumbing & Sanitation', 'ACTIVE'),
(5, 'Safety & Protective Gear', 'ACTIVE')
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- ------------------------------------------------------------
-- 6. MATERIALS MASTER (With default rates & Tally item codes)
-- ------------------------------------------------------------
INSERT INTO materials (id, name, code, category_id, unit, default_rate, tally_item_name, tally_item_code, status) VALUES
(1, 'Cement OPC 53 Grade', 'MAT-001', 1, 'Bag', 380.00, 'Cement OPC 53 Grade', 'TL-CEM-53', 'ACTIVE'),
(2, 'Cement PPC', 'MAT-002', 1, 'Bag', 350.00, 'Cement PPC', 'TL-CEM-PPC', 'ACTIVE'),
(3, 'Cement White', 'MAT-003', 1, 'Bag', 550.00, 'Cement White', 'TL-CEM-WHT', 'ACTIVE'),
(4, 'Green Phenyl', 'MAT-004', 2, 'Ltr', 200.00, 'Green Phenyl', 'TL-PHN-GRN', 'ACTIVE'),
(5, 'White Phenyl', 'MAT-005', 2, 'Ltr', 180.00, 'White Phenyl', 'TL-PHN-WHT', 'ACTIVE'),
(6, 'Room Freshner', 'MAT-006', 2, 'Ltr', 350.00, 'Room Freshner', 'TL-RM-FSH', 'ACTIVE'),
(7, 'Collin Glass Cleaner', 'MAT-007', 2, 'Ltr', 80.00, 'Collin', 'TL-CLN-80', 'ACTIVE'),
(8, 'Nariyal Jhadu', 'MAT-008', 2, 'Pcs', 40.00, 'Nariyal Jhadu', 'TL-JHD-NAR', 'ACTIVE'),
(9, 'Phool Jhadu', 'MAT-009', 2, 'Pcs', 65.00, 'Phool Jhadu', 'TL-JHD-PHL', 'ACTIVE'),
(10, 'Safety Gloves Heavy Duty', 'MAT-010', 5, 'Pcs', 50.00, 'Gloves', 'TL-GLV-50', 'ACTIVE'),
(11, 'PVC Pipe 1 inch (10ft)', 'MAT-011', 4, 'Pcs', 120.00, 'Pipe 1 inch', 'TL-PIP-1IN', 'ACTIVE'),
(12, 'LED Bulb 12W White', 'MAT-012', 3, 'Pcs', 95.00, 'LED Bulb 12W', 'TL-BLB-12W', 'ACTIVE')
ON DUPLICATE KEY UPDATE name=VALUES(name), default_rate=VALUES(default_rate);
