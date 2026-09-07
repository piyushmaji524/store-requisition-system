<?php
/**
 * Core Requisition Management Service
 * Manages Master Requisition, Location Sub-Requisitions, Item lifecycles, and Snapshots
 */

require_once __DIR__ . '/../core/Database.php';
require_once __DIR__ . '/../core/Logger.php';
require_once __DIR__ . '/TimeService.php';
require_once __DIR__ . '/SequenceService.php';
require_once __DIR__ . '/OneSignalService.php';

class RequisitionService {
    /**
     * Get or create user's Master Requisition for a given date
     * Strictly enforces: One User + One Date = One Master Requisition
     */
    public static function getOrCreateMasterRequisition(PDO $db, int $userId, string $date): array {
        $cleanDate = date('Y-m-d', strtotime($date));

        // Check if master requisition already exists for this user and date
        $stmt = $db->prepare("SELECT * FROM requisitions WHERE user_id = :user_id AND requisition_date = :req_date LIMIT 1 FOR UPDATE");
        $stmt->execute([':user_id' => $userId, ':req_date' => $cleanDate]);
        $existing = $stmt->fetch();

        if ($existing) {
            return $existing;
        }

        // Generate next sequence number safely
        $reqNo = SequenceService::generateMasterRequisitionNo($db, $cleanDate);

        $insStmt = $db->prepare("INSERT INTO requisitions (requisition_no, user_id, requisition_date, status, created_at)
                                 VALUES (:no, :uid, :date, 'OPEN', NOW())");
        $insStmt->execute([
            ':no'   => $reqNo,
            ':uid'  => $userId,
            ':date' => $cleanDate
        ]);

        $newId = (int) $db->lastInsertId();

        Logger::logActivity($userId, 'CREATE_MASTER_REQUISITION', 'requisitions', (string) $newId, null, [
            'requisition_no'   => $reqNo,
            'requisition_date' => $cleanDate
        ]);

        return [
            'id'               => $newId,
            'requisition_no'   => $reqNo,
            'user_id'          => $userId,
            'requisition_date' => $cleanDate,
            'status'           => 'OPEN'
        ];
    }

    /**
     * Get or create Location Sub-Requisition under a Master Requisition
     * Strictly enforces: Same Master Requisition + Same Location = Same Sub-Requisition
     */
    public static function getOrCreateSubRequisition(PDO $db, int $requisitionId, string $masterReqNo, int $locationId): array {
        // Check if sub-requisition exists for this location
        $stmt = $db->prepare("SELECT * FROM requisition_subs WHERE requisition_id = :req_id AND location_id = :loc_id LIMIT 1 FOR UPDATE");
        $stmt->execute([':req_id' => $requisitionId, ':loc_id' => $locationId]);
        $existing = $stmt->fetch();

        if ($existing) {
            return $existing;
        }

        // Try inserting with generated unique number, retry if duplicate key occurs
        for ($attempts = 0; $attempts < 5; $attempts++) {
            $subNo = SequenceService::generateSubRequisitionNo($db, $requisitionId, $masterReqNo, $locationId);

            try {
                $insStmt = $db->prepare("INSERT INTO requisition_subs (requisition_id, sub_requisition_no, location_id, status, tally_export_status, created_at)
                                         VALUES (:req_id, :sub_no, :loc_id, 'OPEN', 'NOT_EXPORTED', NOW())");
                $insStmt->execute([
                    ':req_id' => $requisitionId,
                    ':sub_no' => $subNo,
                    ':loc_id' => $locationId
                ]);

                $subId = (int) $db->lastInsertId();

                return [
                    'id'                  => $subId,
                    'requisition_id'      => $requisitionId,
                    'sub_requisition_no'  => $subNo,
                    'location_id'         => $locationId,
                    'status'              => 'OPEN',
                    'tally_export_status' => 'NOT_EXPORTED'
                ];
            } catch (PDOException $e) {
                // If duplicate, re-check if location already got created concurrently
                $recheck = $db->prepare("SELECT * FROM requisition_subs WHERE requisition_id = :req_id AND location_id = :loc_id LIMIT 1 FOR UPDATE");
                $recheck->execute([':req_id' => $requisitionId, ':loc_id' => $locationId]);
                $reExisting = $recheck->fetch();
                if ($reExisting) {
                    return $reExisting;
                }

                // If error code is 23000 (duplicate entry), loop to generate the next number
                if ($e->getCode() === '23000' || (isset($e->errorInfo[1]) && $e->errorInfo[1] == 1062)) {
                    continue;
                }
                throw $e;
            }
        }

        throw new Exception("Unable to generate unique sub-requisition number after multiple attempts.");
    }

    /**
     * Add Item to user's daily requisition
     */
    public static function addItem(
        int $userId,
        int $materialId,
        float $quantity,
        int $locationId,
        ?string $remark = null,
        bool $isEmergency = false
    ): array {
        // 1. Authoritative window validation
        if (!$isEmergency && !TimeService::isUserRequestWindowOpen()) {
            throw new Exception("Requisition window is closed. Item submission allowed only between 06:00 AM and 08:00 PM IST.");
        }

        if ($quantity <= 0) {
            throw new Exception("Quantity must be greater than 0.");
        }

        return Database::transaction(function (PDO $db) use ($userId, $materialId, $quantity, $locationId, $remark, $isEmergency) {
            // Verify Material exists and capture snapshot
            $matStmt = $db->prepare("SELECT * FROM materials WHERE id = :id AND status != 'INACTIVE' LIMIT 1");
            $matStmt->execute([':id' => $materialId]);
            $material = $matStmt->fetch();
            if (!$material) {
                throw new Exception("Selected material is invalid or inactive.");
            }

            // Verify Location exists
            $locStmt = $db->prepare("SELECT * FROM locations WHERE id = :id AND status = 'ACTIVE' LIMIT 1");
            $locStmt->execute([':id' => $locationId]);
            $location = $locStmt->fetch();
            if (!$location) {
                throw new Exception("Selected location is invalid or inactive.");
            }

            // Today's date in IST
            $today = date('Y-m-d');

            // 1. Master Requisition
            $master = self::getOrCreateMasterRequisition($db, $userId, $today);

            // 2. Sub Requisition (Location-wise)
            $sub = self::getOrCreateSubRequisition($db, (int) $master['id'], $master['requisition_no'], $locationId);

            // 3. Insert Requisition Item with Snapshot data
            $defaultRate = (float) $material['default_rate'];
            $itemSql = "INSERT INTO requisition_items (
                            sub_requisition_id, material_id, material_name_snapshot, unit_snapshot,
                            requested_quantity, issued_quantity, unit_rate, amount, remark,
                            status, is_emergency, created_at
                        ) VALUES (
                            :sub_id, :mat_id, :mat_name, :unit,
                            :req_qty, 0.00, :rate, 0.00, :remark,
                            'PENDING', :is_emergency, NOW()
                        )";

            $itemStmt = $db->prepare($itemSql);
            $itemStmt->execute([
                ':sub_id'       => $sub['id'],
                ':mat_id'       => $materialId,
                ':mat_name'     => $material['name'],
                ':unit'         => $material['unit'],
                ':req_qty'      => $quantity,
                ':rate'         => $defaultRate,
                ':remark'       => $remark,
                ':is_emergency' => $isEmergency ? 1 : 0
            ]);

            $itemId = (int) $db->lastInsertId();

            // Refresh Statuses
            self::refreshStatuses($db, (int) $master['id']);

            Logger::logActivity($userId, 'USER_ADDED_ITEM', 'requisition_items', (string) $itemId, null, [
                'material_name'      => $material['name'],
                'requested_quantity' => $quantity,
                'location_name'      => $location['name'],
                'sub_requisition_no' => $sub['sub_requisition_no']
            ]);

            // Notify Store Keepers in real-time
            try {
                $uStmt = $db->prepare("SELECT name, employee_code FROM users WHERE id = :id LIMIT 1");
                $uStmt->execute([':id' => $userId]);
                $userRow = $uStmt->fetch(PDO::FETCH_ASSOC);
                $userName = $userRow['name'] ?? 'Employee';
                $cleanQty = (floor($quantity) == $quantity) ? (int)$quantity : $quantity;
                
                $notifTitle = "📥 Nayi Requisition Aayi! • {$location['name']}";
                $notifMsg = "{$userName} ne {$cleanQty} {$material['unit']} {$material['name']} ki request bheji hai ({$sub['sub_requisition_no']}).";
                $voiceText = "Dhyan dein! {$userName} ne {$location['name']} ke liye {$material['name']} ki requisition bheji hai.";

                OneSignalService::sendToRole('STORE_USER', $notifTitle, $notifMsg, [
                    'screen'         => 'feed',
                    'requisition_id' => (int) $master['id'],
                    'item_id'        => $itemId,
                    'voice_text'     => $voiceText,
                    'type'           => 'NEW_REQUISITION'
                ], 'FF2563EB');
            } catch (Throwable $e) {
                error_log("[StoreAlert] Error notifying store: " . $e->getMessage());
            }

            return [
                'item_id'            => $itemId,
                'master_req_no'      => $master['requisition_no'],
                'sub_req_no'         => $sub['sub_requisition_no'],
                'material_name'      => $material['name'],
                'unit'               => $material['unit'],
                'requested_quantity' => $quantity,
                'location_name'      => $location['name'],
                'status'             => 'PENDING'
            ];
        });
    }

    /**
     * Update pending item (User action)
     */
    public static function updatePendingItem(
        int $userId,
        int $itemId,
        float $quantity,
        int $locationId,
        ?string $remark = null
    ): array {
        if (!TimeService::isUserRequestWindowOpen()) {
            throw new Exception("Requisition window is closed. Editing is allowed only between 06:00 AM and 08:00 PM IST.");
        }

        if ($quantity <= 0) {
            throw new Exception("Quantity must be greater than 0.");
        }

        return Database::transaction(function (PDO $db) use ($userId, $itemId, $quantity, $locationId, $remark) {
            // Find item with row lock
            $sql = "SELECT i.*, s.requisition_id, s.location_id AS current_location_id, r.user_id, r.requisition_no
                    FROM requisition_items i
                    JOIN requisition_subs s ON i.sub_requisition_id = s.id
                    JOIN requisitions r ON s.requisition_id = r.id
                    WHERE i.id = :id FOR UPDATE";
            
            $stmt = $db->prepare($sql);
            $stmt->execute([':id' => $itemId]);
            $item = $stmt->fetch();

            if (!$item) {
                throw new Exception("Item not found.");
            }

            if ((int) $item['user_id'] !== $userId) {
                throw new Exception("Unauthorized to edit this item.");
            }

            // Lock Check: If store action has already been taken
            if ($item['store_action_at'] !== null || $item['status'] !== 'PENDING') {
                throw new Exception("This item is locked because Store has already taken action on it.");
            }

            $oldData = [
                'quantity'    => $item['requested_quantity'],
                'location_id' => $item['current_location_id'],
                'remark'      => $item['remark']
            ];

            $targetSubId = (int) $item['sub_requisition_id'];

            // If location changed, move item to appropriate sub-requisition
            if ((int) $locationId !== (int) $item['current_location_id']) {
                $targetSub = self::getOrCreateSubRequisition($db, (int) $item['requisition_id'], $item['requisition_no'], $locationId);
                $targetSubId = (int) $targetSub['id'];
            }

            // Update item
            $updSql = "UPDATE requisition_items 
                       SET sub_requisition_id = :sub_id,
                           requested_quantity = :qty,
                           remark = :remark,
                           updated_at = NOW()
                       WHERE id = :id";
            $updStmt = $db->prepare($updSql);
            $updStmt->execute([
                ':sub_id' => $targetSubId,
                ':qty'    => $quantity,
                ':remark' => $remark,
                ':id'     => $itemId
            ]);

            // Clean up empty old sub-requisition if needed
            self::cleanupEmptySubRequisition($db, (int) $item['sub_requisition_id']);

            // Refresh Statuses
            self::refreshStatuses($db, (int) $item['requisition_id']);

            Logger::logActivity($userId, 'USER_EDITED_ITEM', 'requisition_items', (string) $itemId, $oldData, [
                'quantity'    => $quantity,
                'location_id' => $locationId,
                'remark'      => $remark
            ]);

            return ['success' => true, 'item_id' => $itemId];
        });
    }

    /**
     * Delete pending item (User action)
     */
    public static function deletePendingItem(int $userId, int $itemId): bool {
        if (!TimeService::isUserRequestWindowOpen()) {
            throw new Exception("Requisition window is closed. Item deletion is allowed only between 06:00 AM and 08:00 PM IST.");
        }

        return Database::transaction(function (PDO $db) use ($userId, $itemId) {
            $sql = "SELECT i.*, s.requisition_id, r.user_id
                    FROM requisition_items i
                    JOIN requisition_subs s ON i.sub_requisition_id = s.id
                    JOIN requisitions r ON s.requisition_id = r.id
                    WHERE i.id = :id FOR UPDATE";
            
            $stmt = $db->prepare($sql);
            $stmt->execute([':id' => $itemId]);
            $item = $stmt->fetch();

            if (!$item) {
                throw new Exception("Item not found.");
            }

            if ((int) $item['user_id'] !== $userId) {
                throw new Exception("Unauthorized to delete this item.");
            }

            if ($item['store_action_at'] !== null || $item['status'] !== 'PENDING') {
                throw new Exception("This item is locked because Store has already taken action.");
            }

            $delStmt = $db->prepare("DELETE FROM requisition_items WHERE id = :id");
            $delStmt->execute([':id' => $itemId]);

            self::cleanupEmptySubRequisition($db, (int) $item['sub_requisition_id']);
            self::refreshStatuses($db, (int) $item['requisition_id']);

            Logger::logActivity($userId, 'USER_DELETED_ITEM', 'requisition_items', (string) $itemId, [
                'material_name' => $item['material_name_snapshot'],
                'quantity'      => $item['requested_quantity']
            ], null);

            return true;
        });
    }

    /**
     * Delete empty sub-requisition if no items remain
     */
    private static function cleanupEmptySubRequisition(PDO $db, int $subId): void {
        $countStmt = $db->prepare("SELECT COUNT(*) AS total FROM requisition_items WHERE sub_requisition_id = :id");
        $countStmt->execute([':id' => $subId]);
        $row = $countStmt->fetch();
        if (((int) ($row['total'] ?? 0)) === 0) {
            $delStmt = $db->prepare("DELETE FROM requisition_subs WHERE id = :id");
            $delStmt->execute([':id' => $subId]);
        }
    }

    /**
     * Refresh Aggregate Statuses for Sub-Requisitions and Master Requisition
     */
    public static function refreshStatuses(PDO $db, int $requisitionId): void {
        // 1. Update each Sub-Requisition status
        $subsStmt = $db->prepare("SELECT id FROM requisition_subs WHERE requisition_id = :id");
        $subsStmt->execute([':id' => $requisitionId]);
        $subs = $subsStmt->fetchAll();

        foreach ($subs as $sub) {
            $subId = (int) $sub['id'];
            $itemsStmt = $db->prepare("SELECT status FROM requisition_items WHERE sub_requisition_id = :id");
            $itemsStmt->execute([':id' => $subId]);
            $items = $itemsStmt->fetchAll();

            $total = count($items);
            if ($total === 0) {
                continue;
            }

            $pendingCount = 0;
            $processedCount = 0;

            foreach ($items as $item) {
                if ($item['status'] === 'PENDING') {
                    $pendingCount++;
                } else {
                    $processedCount++;
                }
            }

            $subStatus = 'OPEN';
            if ($pendingCount === 0) {
                $subStatus = 'COMPLETED';
            } elseif ($processedCount > 0) {
                $subStatus = 'PARTIALLY_PROCESSED';
            }

            $updSub = $db->prepare("UPDATE requisition_subs SET status = :status WHERE id = :id");
            $updSub->execute([':status' => $subStatus, ':id' => $subId]);
        }

        // 2. Update Master Requisition status
        $allSubItemsStmt = $db->prepare("SELECT i.status 
                                         FROM requisition_items i
                                         JOIN requisition_subs s ON i.sub_requisition_id = s.id
                                         WHERE s.requisition_id = :req_id");
        $allSubItemsStmt->execute([':req_id' => $requisitionId]);
        $allItems = $allSubItemsStmt->fetchAll();

        $masterStatus = 'OPEN';
        if (count($allItems) > 0) {
            $pending = 0;
            $processed = 0;
            foreach ($allItems as $it) {
                if ($it['status'] === 'PENDING') {
                    $pending++;
                } else {
                    $processed++;
                }
            }

            if ($pending === 0) {
                $masterStatus = 'COMPLETED';
            } elseif ($processed > 0) {
                $masterStatus = 'PARTIALLY_PROCESSED';
            }
        }

        $updMaster = $db->prepare("UPDATE requisitions SET status = :status WHERE id = :id");
        $updMaster->execute([':status' => $masterStatus, ':id' => $requisitionId]);
    }

    /**
     * Get complete hierarchy of Today's Master Requisition for user
     */
    public static function getTodayRequisition(int $userId): ?array {
        $today = date('Y-m-d');
        $master = Database::queryOne("SELECT * FROM requisitions WHERE user_id = :uid AND requisition_date = :date LIMIT 1", [
            ':uid'  => $userId,
            ':date' => $today
        ]);

        if (!$master) {
            return null;
        }

        return self::formatFullRequisition((int) $master['id']);
    }

    /**
     * Helper to fetch full structured requisition tree (Master -> Subs -> Items)
     */
    public static function formatFullRequisition(int $requisitionId): ?array {
        $master = Database::queryOne("SELECT r.*, u.name AS user_name, u.employee_code, d.name AS department_name
                                      FROM requisitions r
                                      JOIN users u ON r.user_id = u.id
                                      LEFT JOIN departments d ON u.department_id = d.id
                                      WHERE r.id = :id", [':id' => $requisitionId]);
        if (!$master) {
            return null;
        }

        $subs = Database::query("SELECT s.*, l.name AS location_name, l.code AS location_code, l.tally_ledger_name
                                 FROM requisition_subs s
                                 JOIN locations l ON s.location_id = l.id
                                 WHERE s.requisition_id = :id
                                 ORDER BY s.id ASC", [':id' => $requisitionId]);

        $subList = [];
        $totalItems = 0;
        $totalIssued = 0;
        $pendingCount = 0;
        $issuedCount = 0;
        $partialCount = 0;
        $notAvailableCount = 0;

        foreach ($subs as $sub) {
            $items = Database::query("SELECT i.*, m.code AS material_code, u.name AS store_action_by_name
                                     FROM requisition_items i
                                     LEFT JOIN materials m ON i.material_id = m.id
                                     LEFT JOIN users u ON i.store_action_by = u.id
                                     WHERE i.sub_requisition_id = :sub_id
                                     ORDER BY i.id DESC", [':sub_id' => $sub['id']]);

            $formattedItems = [];
            foreach ($items as $item) {
                $isLocked = ($item['store_action_at'] !== null);
                $formattedItems[] = [
                    'id'                     => (int) $item['id'],
                    'material_id'            => (int) $item['material_id'],
                    'material_name'          => $item['material_name_snapshot'],
                    'material_code'          => $item['material_code'],
                    'unit'                   => $item['unit_snapshot'],
                    'requested_quantity'     => (float) $item['requested_quantity'],
                    'issued_quantity'        => (float) $item['issued_quantity'],
                    'unit_rate'              => (float) $item['unit_rate'],
                    'amount'                 => (float) $item['amount'],
                    'remark'                 => $item['remark'],
                    'store_remark'           => $item['store_remark'],
                    'status'                 => $item['status'],
                    'is_locked'              => $isLocked,
                    'is_emergency'           => (bool) $item['is_emergency'],
                    'store_action_by_name'   => $item['store_action_by_name'],
                    'store_action_at'        => $item['store_action_at']
                ];

                $totalItems++;
                $totalIssued += (float) $item['issued_quantity'];

                match ($item['status']) {
                    'PENDING'          => $pendingCount++,
                    'ISSUED'           => $issuedCount++,
                    'PARTIALLY_ISSUED' => $partialCount++,
                    'NOT_AVAILABLE'    => $notAvailableCount++,
                    default            => null
                };
            }

            $subList[] = [
                'id'                  => (int) $sub['id'],
                'sub_requisition_no'  => $sub['sub_requisition_no'],
                'location_id'         => (int) $sub['location_id'],
                'location_name'       => $sub['location_name'],
                'location_code'       => $sub['location_code'],
                'tally_ledger_name'   => $sub['tally_ledger_name'],
                'status'              => $sub['status'],
                'tally_export_status' => $sub['tally_export_status'],
                'items'               => $formattedItems
            ];
        }

        $master['stats'] = [
            'total_items'        => $totalItems,
            'total_issued_qty'   => $totalIssued,
            'pending_count'      => $pendingCount,
            'issued_count'       => $issuedCount,
            'partial_count'      => $partialCount,
            'not_available_count'=> $notAvailableCount
        ];
        $master['sub_requisitions'] = $subList;

        return $master;
    }

    /**
     * User Requisition History
     */
    public static function getUserHistory(int $userId, int $page = 1, int $limit = 20): array {
        $offset = max(0, ($page - 1) * $limit);

        $countSql = "SELECT COUNT(*) AS total FROM requisitions WHERE user_id = :uid";
        $totalRow = Database::queryOne($countSql, [':uid' => $userId]);
        $totalRecords = (int) ($totalRow['total'] ?? 0);

        $sql = "SELECT r.id, r.requisition_no, r.requisition_date, r.status, r.created_at,
                       COUNT(DISTINCT s.id) AS total_sub_requisitions,
                       COUNT(i.id) AS total_items,
                       COALESCE(SUM(i.issued_quantity), 0) AS total_issued_qty,
                       COALESCE(SUM(CASE WHEN i.status = 'PENDING' THEN 1 ELSE 0 END), 0) AS pending_count
                FROM requisitions r
                LEFT JOIN requisition_subs s ON r.id = s.requisition_id
                LEFT JOIN requisition_items i ON s.id = i.sub_requisition_id
                WHERE r.user_id = :uid
                GROUP BY r.id, r.requisition_no, r.requisition_date, r.status, r.created_at
                ORDER BY r.requisition_date DESC, r.id DESC
                LIMIT " . (int)$limit . " OFFSET " . (int)$offset;

        $rows = Database::query($sql, [':uid' => $userId]);

        $formattedRows = [];
        if ($rows) {
            foreach ($rows as $r) {
                $formattedRows[] = [
                    'id'                     => (int) $r['id'],
                    'requisition_no'         => (string) $r['requisition_no'],
                    'requisition_date'       => (string) $r['requisition_date'],
                    'status'                 => (string) $r['status'],
                    'created_at'             => (string) $r['created_at'],
                    'total_sub_requisitions' => (int) $r['total_sub_requisitions'],
                    'total_items'            => (int) $r['total_items'],
                    'total_issued_qty'       => (float) $r['total_issued_qty'],
                    'pending_count'          => (int) $r['pending_count'],
                ];
            }
        }

        return [
            'current_page'  => $page,
            'per_page'      => $limit,
            'total_records' => $totalRecords,
            'total_pages'   => $totalRecords > 0 ? (int)ceil($totalRecords / $limit) : 1,
            'items'         => $formattedRows
        ];
    }
}
