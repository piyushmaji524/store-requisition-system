-- ============================================================
-- REQUISITION MANAGEMENT SYSTEM - DATABASE SCHEMA (MySQL 8+)
-- Production Ready, Normalized, Indexed, InnoDB with FKs
-- Timezone: Asia/Kolkata (Authoritative)
-- ============================================================

CREATE DATABASE IF NOT EXISTS u435643473_reqisition 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE u435643473_reqisition;

-- ------------------------------------------------------------
-- 1. DEPARTMENTS MASTER
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS departments (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    status ENUM('ACTIVE', 'INACTIVE') NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 2. USERS MASTER
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    employee_code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    mobile VARCHAR(15) NULL UNIQUE,
    email VARCHAR(100) NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role ENUM('SUPER_ADMIN', 'ADMIN', 'STORE_USER', 'REQUISITION_USER') NOT NULL DEFAULT 'REQUISITION_USER',
    department_id INT UNSIGNED NULL,
    status ENUM('ACTIVE', 'INACTIVE') NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE SET NULL,
    INDEX idx_user_role_status (role, status),
    INDEX idx_user_mobile (mobile)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 3. PERSONAL ACCESS TOKENS (For Flutter Mobile API)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_tokens (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED NOT NULL,
    token_hash VARCHAR(64) NOT NULL UNIQUE,
    device_name VARCHAR(100) NULL,
    last_used_at TIMESTAMP NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_token_hash (token_hash),
    INDEX idx_token_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 4. LOCATIONS MASTER
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS locations (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    code VARCHAR(50) NOT NULL UNIQUE,
    tally_ledger_name VARCHAR(150) NOT NULL,
    tally_ledger_code VARCHAR(50) NULL,
    status ENUM('ACTIVE', 'INACTIVE') NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_location_code (code),
    INDEX idx_location_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 5. MATERIAL CATEGORIES
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS material_categories (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    status ENUM('ACTIVE', 'INACTIVE') NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 6. MATERIALS MASTER (With default rate & Tally mapping)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS materials (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    code VARCHAR(50) NOT NULL UNIQUE,
    category_id INT UNSIGNED NULL,
    unit VARCHAR(30) NOT NULL,
    default_rate DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    tally_item_name VARCHAR(150) NULL,
    tally_item_code VARCHAR(50) NULL,
    status ENUM('ACTIVE', 'PENDING_APPROVAL', 'INACTIVE') NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES material_categories(id) ON DELETE SET NULL,
    INDEX idx_material_code (code),
    INDEX idx_material_name (name),
    INDEX idx_material_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 7. DAILY SEQUENCE GENERATOR (Thread-safe sequence generator)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS daily_sequences (
    seq_date DATE PRIMARY KEY,
    last_seq INT UNSIGNED NOT NULL DEFAULT 0,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 8. MASTER REQUISITIONS (ONE PER USER PER DATE)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS requisitions (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    requisition_no VARCHAR(30) NOT NULL UNIQUE,
    user_id INT UNSIGNED NOT NULL,
    requisition_date DATE NOT NULL,
    status ENUM('OPEN', 'PARTIALLY_PROCESSED', 'COMPLETED', 'CLOSED') NOT NULL DEFAULT 'OPEN',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT,
    UNIQUE KEY uk_user_date (user_id, requisition_date),
    INDEX idx_req_date (requisition_date),
    INDEX idx_req_user_date (user_id, requisition_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 9. SUB REQUISITIONS (LOCATION-WISE SPLIT)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS requisition_subs (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    requisition_id INT UNSIGNED NOT NULL,
    sub_requisition_no VARCHAR(40) NOT NULL UNIQUE,
    location_id INT UNSIGNED NOT NULL,
    status ENUM('OPEN', 'PARTIALLY_PROCESSED', 'COMPLETED', 'CLOSED') NOT NULL DEFAULT 'OPEN',
    tally_export_status ENUM('NOT_EXPORTED', 'EXPORTED', 'EXPORTED_MODIFIED') NOT NULL DEFAULT 'NOT_EXPORTED',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (requisition_id) REFERENCES requisitions(id) ON DELETE CASCADE,
    FOREIGN KEY (location_id) REFERENCES locations(id) ON DELETE RESTRICT,
    UNIQUE KEY uk_requisition_location (requisition_id, location_id),
    INDEX idx_sub_req_no (sub_requisition_no),
    INDEX idx_sub_tally_status (tally_export_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 10. REQUISITION ITEMS (INDIVIDUAL MATERIALS)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS requisition_items (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    sub_requisition_id INT UNSIGNED NOT NULL,
    material_id INT UNSIGNED NOT NULL,
    material_name_snapshot VARCHAR(150) NOT NULL,
    unit_snapshot VARCHAR(30) NOT NULL,
    requested_quantity DECIMAL(10, 2) NOT NULL,
    issued_quantity DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    unit_rate DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    amount DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    remark VARCHAR(255) NULL,
    store_remark VARCHAR(255) NULL,
    status ENUM('PENDING', 'ISSUED', 'PARTIALLY_ISSUED', 'NOT_AVAILABLE', 'CANCELLED') NOT NULL DEFAULT 'PENDING',
    is_emergency TINYINT(1) NOT NULL DEFAULT 0,
    store_action_by INT UNSIGNED NULL,
    store_action_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (sub_requisition_id) REFERENCES requisition_subs(id) ON DELETE CASCADE,
    FOREIGN KEY (material_id) REFERENCES materials(id) ON DELETE RESTRICT,
    FOREIGN KEY (store_action_by) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_item_sub_status (sub_requisition_id, status),
    INDEX idx_item_status (status),
    INDEX idx_item_action_time (store_action_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 11. EMERGENCY ISSUES REGISTER
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS emergency_issues (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED NOT NULL,
    material_id INT UNSIGNED NOT NULL,
    material_name_snapshot VARCHAR(150) NOT NULL,
    quantity DECIMAL(10, 2) NOT NULL,
    unit VARCHAR(30) NOT NULL,
    unit_rate DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    amount DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    location_id INT UNSIGNED NOT NULL,
    remark VARCHAR(255) NULL,
    reason TEXT NOT NULL,
    requisition_id INT UNSIGNED NULL,
    requisition_item_id INT UNSIGNED NULL,
    issued_by INT UNSIGNED NOT NULL,
    issued_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status ENUM('RECORDED', 'LINKED_TO_REQUISITION', 'CANCELLED') NOT NULL DEFAULT 'RECORDED',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT,
    FOREIGN KEY (material_id) REFERENCES materials(id) ON DELETE RESTRICT,
    FOREIGN KEY (location_id) REFERENCES locations(id) ON DELETE RESTRICT,
    FOREIGN KEY (issued_by) REFERENCES users(id) ON DELETE RESTRICT,
    FOREIGN KEY (requisition_id) REFERENCES requisitions(id) ON DELETE SET NULL,
    FOREIGN KEY (requisition_item_id) REFERENCES requisition_items(id) ON DELETE SET NULL,
    INDEX idx_emergency_user_date (user_id, issued_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 12. ADMIN DATE OVERRIDES (2-Hour Window)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS admin_date_overrides (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    override_date DATE NOT NULL,
    opened_by INT UNSIGNED NOT NULL,
    opened_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    closed_at TIMESTAMP NULL,
    reason VARCHAR(255) NOT NULL,
    status ENUM('OPEN', 'EXPIRED', 'FORCE_CLOSED') NOT NULL DEFAULT 'OPEN',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (opened_by) REFERENCES users(id) ON DELETE RESTRICT,
    INDEX idx_override_date_status (override_date, status),
    INDEX idx_override_expiry (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 13. TALLY EXPORT BATCHES
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tally_export_batches (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    batch_id VARCHAR(50) NOT NULL UNIQUE,
    date_from DATE NOT NULL,
    date_to DATE NOT NULL,
    record_count INT UNSIGNED NOT NULL DEFAULT 0,
    file_name VARCHAR(255) NOT NULL,
    created_by INT UNSIGNED NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE RESTRICT,
    INDEX idx_batch_id (batch_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 14. TALLY EXPORT MAPPING & AUDIT LINKS
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tally_exports (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    batch_id INT UNSIGNED NOT NULL,
    sub_requisition_id INT UNSIGNED NOT NULL,
    voucher_number VARCHAR(50) NOT NULL,
    exported_by INT UNSIGNED NOT NULL,
    exported_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status ENUM('SUCCESS', 'RE_EXPORTED', 'CANCELLED') NOT NULL DEFAULT 'SUCCESS',
    FOREIGN KEY (batch_id) REFERENCES tally_export_batches(id) ON DELETE CASCADE,
    FOREIGN KEY (sub_requisition_id) REFERENCES requisition_subs(id) ON DELETE RESTRICT,
    FOREIGN KEY (exported_by) REFERENCES users(id) ON DELETE RESTRICT,
    INDEX idx_tally_sub_req (sub_requisition_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 15. ACTIVITY AUDIT LOGS
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS activity_logs (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED NULL,
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id VARCHAR(50) NULL,
    old_data JSON NULL,
    new_data JSON NULL,
    ip_address VARCHAR(45) NULL,
    user_agent VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_activity_created (created_at),
    INDEX idx_activity_user (user_id),
    INDEX idx_activity_entity (entity_type, entity_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 16. SYSTEM SETTINGS
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS settings (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    setting_key VARCHAR(100) NOT NULL UNIQUE,
    setting_value TEXT NOT NULL,
    description VARCHAR(255) NULL,
    updated_by INT UNSIGNED NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
