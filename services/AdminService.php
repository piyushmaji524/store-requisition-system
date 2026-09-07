<?php
/**
 * Admin Business Logic Service
 * Master data CRUD, Metrics, Date Overrides, and Reports
 */

require_once __DIR__ . '/../core/Database.php';
require_once __DIR__ . '/../core/Logger.php';
require_once __DIR__ . '/TimeService.php';

class AdminService {
    /**
     * Get Admin Dashboard Metrics with flexible date filters & presets
     */
    public static function getDashboardMetrics(?string $dateFrom = null, ?string $dateTo = null): array {
        $where = [];
        $params = [];

        if (!empty($dateFrom) && !empty($dateTo)) {
            if ($dateFrom === $dateTo) {
                $where[] = "r.requisition_date = :req_date";
                $params[':req_date'] = $dateFrom;
            } else {
                $where[] = "r.requisition_date BETWEEN :date_from AND :date_to";
                $params[':date_from'] = $dateFrom;
                $params[':date_to'] = $dateTo;
            }
        } elseif (!empty($dateFrom)) {
            $where[] = "r.requisition_date >= :date_from";
            $params[':date_from'] = $dateFrom;
        } elseif (!empty($dateTo)) {
            $where[] = "r.requisition_date <= :date_to";
            $params[':date_to'] = $dateTo;
        }

        $whereSql = !empty($where) ? ("WHERE " . implode(" AND ", $where)) : "";

        // Total requisitions
        $reqsRow = Database::queryOne("SELECT COUNT(*) AS total FROM requisitions r {$whereSql}", $params);
        
        // Total sub requisitions
        $subsRow = Database::queryOne("SELECT COUNT(*) AS total 
                                         FROM requisition_subs s 
                                         JOIN requisitions r ON s.requisition_id = r.id 
                                         {$whereSql}", $params);

        // Item status breakdown
        $itemStats = Database::queryOne("SELECT 
                                            COUNT(i.id) AS total_items,
                                            COALESCE(SUM(i.issued_quantity), 0) AS total_issued_qty,
                                            SUM(CASE WHEN i.status = 'PENDING' THEN 1 ELSE 0 END) AS pending_items,
                                            SUM(CASE WHEN i.status = 'ISSUED' THEN 1 ELSE 0 END) AS issued_items,
                                            SUM(CASE WHEN i.status = 'PARTIALLY_ISSUED' THEN 1 ELSE 0 END) AS partial_items,
                                            SUM(CASE WHEN i.status = 'NOT_AVAILABLE' THEN 1 ELSE 0 END) AS not_available_items
                                         FROM requisition_items i
                                         JOIN requisition_subs s ON i.sub_requisition_id = s.id
                                         JOIN requisitions r ON s.requisition_id = r.id
                                         {$whereSql}", $params);

        // Tally export count
        $tallyWhere = !empty($where) ? ($whereSql . " AND s.tally_export_status = 'EXPORTED'") : "WHERE s.tally_export_status = 'EXPORTED'";
        $tallyStats = Database::queryOne("SELECT COUNT(*) AS exported_count 
                                          FROM requisition_subs s
                                          JOIN requisitions r ON s.requisition_id = r.id
                                          {$tallyWhere}", $params);

        // Total Valuation
        $valRow = Database::queryOne("SELECT COALESCE(SUM(CASE WHEN i.amount > 0 THEN i.amount ELSE (i.issued_quantity * i.unit_rate) END), 0) AS total_val 
                                      FROM requisition_items i 
                                      JOIN requisition_subs s ON i.sub_requisition_id = s.id 
                                      JOIN requisitions r ON s.requisition_id = r.id 
                                      {$whereSql}", $params);

        // Active Date Overrides count
        $activeOverrides = Database::queryOne("SELECT COUNT(*) AS total FROM admin_date_overrides WHERE status = 'OPEN' AND expires_at > NOW()");

        return [
            'date_from'              => $dateFrom,
            'date_to'                => $dateTo,
            'total_master_reqs'      => (int) ($reqsRow['total'] ?? 0),
            'total_sub_reqs'         => (int) ($subsRow['total'] ?? 0),
            'total_items'            => (int) ($itemStats['total_items'] ?? 0),
            'total_issued_qty'       => (float) ($itemStats['total_issued_qty'] ?? 0),
            'total_valuation'        => (float) ($valRow['total_val'] ?? 0.0),
            'pending_items'          => (int) ($itemStats['pending_items'] ?? 0),
            'issued_items'           => (int) ($itemStats['issued_items'] ?? 0),
            'partial_items'          => (int) ($itemStats['partial_items'] ?? 0),
            'not_available_items'    => (int) ($itemStats['not_available_items'] ?? 0),
            'tally_exported_subs'    => (int) ($tallyStats['exported_count'] ?? 0),
            'active_overrides_count' => (int) ($activeOverrides['total'] ?? 0)
        ];
    }

    /**
     * Create an Admin Date Override for a Past Date
     */
    public static function createDateOverride(int $adminUserId, string $overrideDate, string $reason, ?int $durationHours = null): array {
        $cleanDate = date('Y-m-d', strtotime($overrideDate));
        $now = TimeService::now();
        $todayStr = $now->format('Y-m-d');

        if ($durationHours === null || $durationHours <= 0) {
            $durationHours = (int) Config::get('ADMIN_OVERRIDE_HOURS', 2);
        }

        if (empty(trim($reason))) {
            throw new Exception("Reason for date override is required.");
        }

        // Close any existing active override for this date first
        Database::execute("UPDATE admin_date_overrides 
                           SET status = 'FORCE_CLOSED', closed_at = NOW() 
                           WHERE override_date = :date AND status = 'OPEN'", [':date' => $cleanDate]);

        $openedAt = $now->format('Y-m-d H:i:s');
        $expiresAt = $now->modify("+{$durationHours} hours")->format('Y-m-d H:i:s');

        $sql = "INSERT INTO admin_date_overrides (override_date, opened_by, opened_at, expires_at, reason, status, created_at)
                VALUES (:date, :admin_id, :opened_at, :expires_at, :reason, 'OPEN', NOW())";

        Database::execute($sql, [
            ':date'      => $cleanDate,
            ':admin_id'  => $adminUserId,
            ':opened_at' => $openedAt,
            ':expires_at'=> $expiresAt,
            ':reason'    => $reason
        ]);

        $overrideId = Database::lastInsertId();

        Logger::logActivity($adminUserId, 'ADMIN_DATE_OVERRIDE_CREATED', 'admin_date_overrides', (string) $overrideId, null, [
            'override_date' => $cleanDate,
            'opened_at'     => $openedAt,
            'expires_at'    => $expiresAt,
            'reason'        => $reason
        ]);

        return [
            'id'            => $overrideId,
            'override_date' => $cleanDate,
            'opened_at'     => $openedAt,
            'expires_at'    => $expiresAt,
            'status'        => 'OPEN',
            'reason'        => $reason
        ];
    }

    /**
     * Force close an active date override
     */
    public static function closeDateOverride(int $adminUserId, int $overrideId): bool {
        $override = Database::queryOne("SELECT * FROM admin_date_overrides WHERE id = :id", [':id' => $overrideId]);
        if (!$override) {
            throw new Exception("Override record not found.");
        }

        Database::execute("UPDATE admin_date_overrides SET status = 'FORCE_CLOSED', closed_at = NOW() WHERE id = :id", [':id' => $overrideId]);

        Logger::logActivity($adminUserId, 'ADMIN_DATE_OVERRIDE_FORCE_CLOSED', 'admin_date_overrides', (string) $overrideId, [
            'status' => $override['status']
        ], ['status' => 'FORCE_CLOSED']);

        return true;
    }

    /**
     * List recent date overrides
     */
    public static function listDateOverrides(int $limit = 20): array {
        $sql = "SELECT o.*, u.name AS opened_by_name,
                       CASE 
                           WHEN o.status = 'OPEN' AND o.expires_at <= NOW() THEN 'EXPIRED'
                           ELSE o.status 
                       END AS live_status
                FROM admin_date_overrides o
                JOIN users u ON o.opened_by = u.id
                ORDER BY o.id DESC
                LIMIT :limit";

        $stmt = Database::getConnection()->prepare($sql);
        $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
        $stmt->execute();
        return $stmt->fetchAll();
    }

    /**
     * Master Data: Create / Update User
     */
    public static function saveUser(array $data, ?int $userId = null, ?int $adminId = null): int {
        if ($userId === null) {
            // New user
            $hash = password_hash($data['password'] ?? 'password123', PASSWORD_BCRYPT);
            $sql = "INSERT INTO users (employee_code, name, mobile, email, password_hash, role, department_id, status, created_at)
                    VALUES (:code, :name, :mobile, :email, :hash, :role, :dept_id, :status, NOW())";
            Database::execute($sql, [
                ':code'    => $data['employee_code'],
                ':name'    => $data['name'],
                ':mobile'  => $data['mobile'] ?: null,
                ':email'   => $data['email'] ?: null,
                ':hash'    => $hash,
                ':role'    => $data['role'] ?? 'REQUISITION_USER',
                ':dept_id' => $data['department_id'] ?: null,
                ':status'  => $data['status'] ?? 'ACTIVE'
            ]);
            $newId = Database::lastInsertId();
            Logger::logActivity($adminId, 'USER_CREATED', 'users', (string) $newId, null, $data);
            return $newId;
        } else {
            // Update user
            $old = Database::queryOne("SELECT * FROM users WHERE id = :id", [':id' => $userId]);
            $sql = "UPDATE users 
                    SET employee_code = :code, name = :name, mobile = :mobile, email = :email,
                        role = :role, department_id = :dept_id, status = :status, updated_at = NOW()
                    WHERE id = :id";
            Database::execute($sql, [
                ':code'    => $data['employee_code'],
                ':name'    => $data['name'],
                ':mobile'  => $data['mobile'] ?: null,
                ':email'   => $data['email'] ?: null,
                ':role'    => $data['role'],
                ':dept_id' => $data['department_id'] ?: null,
                ':status'  => $data['status'],
                ':id'      => $userId
            ]);

            if (!empty($data['password'])) {
                $hash = password_hash($data['password'], PASSWORD_BCRYPT);
                Database::execute("UPDATE users SET password_hash = :hash WHERE id = :id", [':hash' => $hash, ':id' => $userId]);
            }

            Logger::logActivity($adminId, 'USER_UPDATED', 'users', (string) $userId, $old, $data);
            return $userId;
        }
    }

    /**
     * Generate next sequential Material Code (e.g. MAT-013, MAT-014...)
     */
    public static function generateNextMaterialCode(): string {
        $sql = "SELECT code FROM materials WHERE code LIKE 'MAT-%' ORDER BY id DESC";
        $rows = Database::query($sql);
        $maxNum = 0;
        foreach ($rows as $r) {
            if (preg_match('/^MAT-(\d+)$/i', trim($r['code']), $matches)) {
                $val = (int)$matches[1];
                if ($val > $maxNum) {
                    $maxNum = $val;
                }
            }
        }
        if ($maxNum === 0) {
            $countRow = Database::queryOne("SELECT COUNT(*) as cnt FROM materials");
            $maxNum = (int)($countRow['cnt'] ?? 0);
        }
        $next = $maxNum + 1;
        return 'MAT-' . str_pad((string)$next, 3, '0', STR_PAD_LEFT);
    }

    /**
     * Master Data: Create / Update Material
     */
    public static function saveMaterial(array $data, ?int $materialId = null, ?int $adminId = null): int {
        $code = !empty($data['code']) ? trim($data['code']) : self::generateNextMaterialCode();
        $tallyName = !empty($data['tally_item_name']) ? trim($data['tally_item_name']) : trim($data['name']);
        
        if ($materialId === null) {
            $sql = "INSERT INTO materials (name, code, category_id, unit, default_rate, current_stock, tally_item_name, tally_item_code, status, created_at)
                    VALUES (:name, :code, :cat_id, :unit, :rate, :stock, :t_name, :t_code, :status, NOW())";
            Database::execute($sql, [
                ':name'   => trim($data['name']),
                ':code'   => $code,
                ':cat_id' => !empty($data['category_id']) ? (int)$data['category_id'] : null,
                ':unit'   => trim($data['unit']),
                ':rate'   => (float)($data['default_rate'] ?? 0.00),
                ':stock'  => (float)($data['current_stock'] ?? 0.00),
                ':t_name' => $tallyName,
                ':t_code' => !empty($data['tally_item_code']) ? trim($data['tally_item_code']) : null,
                ':status' => $data['status'] ?? 'ACTIVE'
            ]);
            $newId = Database::lastInsertId();
            Logger::logActivity($adminId, 'MATERIAL_CREATED', 'materials', (string) $newId, null, $data);
            return $newId;
        } else {
            $old = Database::queryOne("SELECT * FROM materials WHERE id = :id", [':id' => $materialId]);
            $sql = "UPDATE materials 
                    SET name = :name, code = :code, category_id = :cat_id, unit = :unit,
                        default_rate = :rate,
                        current_stock = :stock,
                        tally_item_name = :t_name, tally_item_code = :t_code,
                        status = :status, updated_at = NOW()
                    WHERE id = :id";
            Database::execute($sql, [
                ':name'   => trim($data['name']),
                ':code'   => $code,
                ':cat_id' => !empty($data['category_id']) ? (int)$data['category_id'] : null,
                ':unit'   => trim($data['unit']),
                ':rate'   => (float)($data['default_rate'] ?? 0.00),
                ':stock'  => (float)($data['current_stock'] ?? ($old['current_stock'] ?? 0.00)),
                ':t_name' => $tallyName,
                ':t_code' => !empty($data['tally_item_code']) ? trim($data['tally_item_code']) : null,
                ':status' => $data['status'] ?? ($old['status'] ?? 'ACTIVE'),
                ':id'     => $materialId
            ]);
            Logger::logActivity($adminId, 'MATERIAL_UPDATED', 'materials', (string) $materialId, $old, $data);
            return $materialId;
        }
    }

    /**
     * Master Data: 1-Click Toggle Material Status (ACTIVE <-> INACTIVE)
     */
    public static function toggleMaterialStatus(int $materialId, int $adminId): string {
        $mat = Database::queryOne("SELECT * FROM materials WHERE id = :id", [':id' => $materialId]);
        if (!$mat) {
            throw new Exception("Material not found.");
        }
        $newStatus = ($mat['status'] === 'ACTIVE') ? 'INACTIVE' : 'ACTIVE';
        Database::execute("UPDATE materials SET status = :status, updated_at = NOW() WHERE id = :id", [
            ':status' => $newStatus,
            ':id'     => $materialId
        ]);
        Logger::logActivity($adminId, 'MATERIAL_STATUS_TOGGLED', 'materials', (string) $materialId, $mat, ['new_status' => $newStatus]);
        return $newStatus;
    }

    /**
     * Master Data: Create / Update Location
     */
    public static function saveLocation(array $data, ?int $locationId = null, ?int $adminId = null): int {
        if ($locationId === null) {
            $sql = "INSERT INTO locations (name, code, tally_ledger_name, tally_ledger_code, status, created_at)
                    VALUES (:name, :code, :t_ledger, :t_code, :status, NOW())";
            Database::execute($sql, [
                ':name'     => $data['name'],
                ':code'     => $data['code'],
                ':t_ledger' => $data['tally_ledger_name'] ?: $data['name'],
                ':t_code'   => $data['tally_ledger_code'] ?: null,
                ':status'   => $data['status'] ?? 'ACTIVE'
            ]);
            $newId = Database::lastInsertId();
            Logger::logActivity($adminId, 'LOCATION_CREATED', 'locations', (string) $newId, null, $data);
            return $newId;
        } else {
            $old = Database::queryOne("SELECT * FROM locations WHERE id = :id", [':id' => $locationId]);
            $sql = "UPDATE locations 
                    SET name = :name, code = :code, tally_ledger_name = :t_ledger,
                        tally_ledger_code = :t_code, status = :status, updated_at = NOW()
                    WHERE id = :id";
            Database::execute($sql, [
                ':name'     => $data['name'],
                ':code'     => $data['code'],
                ':t_ledger' => $data['tally_ledger_name'] ?: $data['name'],
                ':t_code'   => $data['tally_ledger_code'] ?: null,
                ':status'   => $data['status'],
                ':id'       => $locationId
            ]);
            Logger::logActivity($adminId, 'LOCATION_UPDATED', 'locations', (string) $locationId, $old, $data);
            return $locationId;
        }
    }

    /**
     * Master Data: 1-Click Toggle Location Status (ACTIVE <-> INACTIVE)
     */
    public static function toggleLocationStatus(int $locationId, int $adminId): string {
        $loc = Database::queryOne("SELECT * FROM locations WHERE id = :id", [':id' => $locationId]);
        if (!$loc) {
            throw new Exception("Location not found.");
        }
        $newStatus = ($loc['status'] === 'ACTIVE') ? 'INACTIVE' : 'ACTIVE';
        Database::execute("UPDATE locations SET status = :status, updated_at = NOW() WHERE id = :id", [
            ':status' => $newStatus,
            ':id'     => $locationId
        ]);
        Logger::logActivity($adminId, 'LOCATION_STATUS_TOGGLED', 'locations', (string) $locationId, $loc, ['new_status' => $newStatus]);
        return $newStatus;
    }

    /**
     * Master Data: 1-Click Toggle User Status (ACTIVE <-> INACTIVE)
     */
    public static function toggleUserStatus(int $userId, int $adminId): string {
        $u = Database::queryOne("SELECT * FROM users WHERE id = :id", [':id' => $userId]);
        if (!$u) {
            throw new Exception("User not found.");
        }
        $newStatus = ($u['status'] === 'ACTIVE') ? 'INACTIVE' : 'ACTIVE';
        Database::execute("UPDATE users SET status = :status, updated_at = NOW() WHERE id = :id", [
            ':status' => $newStatus,
            ':id'     => $userId
        ]);
        Logger::logActivity($adminId, 'USER_STATUS_TOGGLED', 'users', (string) $userId, $u, ['new_status' => $newStatus]);
        return $newStatus;
    }
}
