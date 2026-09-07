<?php
/**
 * Store Fulfillment & Emergency Issue Management Service
 */

require_once __DIR__ . '/../core/Database.php';
require_once __DIR__ . '/../core/Logger.php';
require_once __DIR__ . '/TimeService.php';
require_once __DIR__ . '/RequisitionService.php';
require_once __DIR__ . '/OneSignalService.php';

class StoreService {
    /**
     * Fetch list of users who have requisitions today (for horizontal Store Panel selector)
     */
    public static function getUsersWithRequisitions(string $date = ''): array {
        $targetDate = $date ?: date('Y-m-d');
        
        $sql = "SELECT u.id, u.employee_code, u.name, d.name AS department_name,
                       r.id AS requisition_id, r.requisition_no, r.status AS master_status,
                       COUNT(i.id) AS total_items,
                       SUM(CASE WHEN i.status = 'PENDING' THEN 1 ELSE 0 END) AS pending_count,
                       SUM(CASE WHEN i.status = 'ISSUED' THEN 1 ELSE 0 END) AS issued_count,
                       SUM(CASE WHEN i.status = 'PARTIALLY_ISSUED' THEN 1 ELSE 0 END) AS partial_count,
                       SUM(CASE WHEN i.status = 'NOT_AVAILABLE' THEN 1 ELSE 0 END) AS not_available_count
                FROM users u
                LEFT JOIN departments d ON u.department_id = d.id
                JOIN requisitions r ON u.id = r.user_id AND r.requisition_date = :req_date
                LEFT JOIN requisition_subs s ON r.id = s.requisition_id
                LEFT JOIN requisition_items i ON s.id = i.sub_requisition_id
                WHERE u.status = 'ACTIVE'
                GROUP BY u.id, r.id
                ORDER BY pending_count DESC, u.name ASC";

        return Database::query($sql, [':req_date' => $targetDate]);
    }

    /**
     * Process Store Action on a Requisition Item
     * Action types:
     * - FULL_ISSUE: issued_quantity = requested_quantity, status = 'ISSUED'
     * - PARTIAL_ISSUE: issued_quantity = $issuedQty, status = 'PARTIALLY_ISSUED'
     * - NOT_AVAILABLE: issued_quantity = 0.00, status = 'NOT_AVAILABLE'
     */
    public static function processItemAction(
        int $storeUserId,
        int $itemId,
        string $actionType,
        float $issuedQty = 0,
        ?string $remark = null
    ): array {
        return Database::transaction(function (PDO $db) use ($storeUserId, $itemId, $actionType, $issuedQty, $remark) {
            // Find item with row-level lock
            $sql = "SELECT i.*, s.requisition_id, s.tally_export_status, r.requisition_date, r.requisition_no, r.user_id,
                           u.name AS user_name, m.name AS material_name, l.name AS location_name
                    FROM requisition_items i
                    JOIN requisition_subs s ON i.sub_requisition_id = s.id
                    JOIN requisitions r ON s.requisition_id = r.id
                    JOIN users u ON r.user_id = u.id
                    JOIN materials m ON i.material_id = m.id
                    JOIN locations l ON s.location_id = l.id
                    WHERE i.id = :id FOR UPDATE";

            $stmt = $db->prepare($sql);
            $stmt->execute([':id' => $itemId]);
            $item = $stmt->fetch();

            if (!$item) {
                throw new Exception("Requisition item not found.");
            }

            $reqDate = $item['requisition_date'];

            // 1. Authoritative Store Window / Override validation
            if (!TimeService::isStoreEditAllowed($reqDate)) {
                throw new Exception("Store editing window has closed for date [{$reqDate}]. Editing requires an active Admin Date Override.");
            }

            $reqQty = (float) $item['requested_quantity'];
            $unitRate = (float) $item['unit_rate'];

            // Determine new status, issued quantity, and amount
            $newStatus = 'PENDING';
            $finalIssuedQty = 0.0;

            switch ($actionType) {
                case 'FULL_ISSUE':
                    $finalIssuedQty = $reqQty;
                    $newStatus = 'ISSUED';
                    break;

                case 'PARTIAL_ISSUE':
                    if ($issuedQty <= 0 || $issuedQty >= $reqQty) {
                        throw new Exception("For Partial Issue, issued quantity must be greater than 0 and less than requested quantity ({$reqQty}).");
                    }
                    $finalIssuedQty = $issuedQty;
                    $newStatus = 'PARTIALLY_ISSUED';
                    break;

                case 'NOT_AVAILABLE':
                    $finalIssuedQty = 0.0;
                    $newStatus = 'NOT_AVAILABLE';
                    break;

                default:
                    throw new Exception("Invalid action type [{$actionType}].");
            }

            $amount = round($finalIssuedQty * $unitRate, 2);

            $oldData = [
                'status'          => $item['status'],
                'issued_quantity' => (float) $item['issued_quantity'],
                'amount'          => (float) $item['amount'],
                'remark'          => $item['remark'],
                'store_action_by' => $item['store_action_by'],
                'store_action_at' => $item['store_action_at']
            ];

            // Update item record preserving user remark intact
            $updSql = "UPDATE requisition_items 
                       SET issued_quantity = :issued_qty,
                           amount = :amount,
                           status = :status,
                           store_remark = :store_remark,
                           store_action_by = :store_uid,
                           store_action_at = NOW(),
                           updated_at = NOW()
                       WHERE id = :id";

            $updStmt = $db->prepare($updSql);
            $updStmt->execute([
                ':issued_qty'    => $finalIssuedQty,
                ':amount'        => $amount,
                ':status'        => $newStatus,
                ':store_remark'  => $remark,
                ':store_uid'     => $storeUserId,
                ':id'            => $itemId
            ]);

            // Adjust physical stock in materials table based on delta
            $oldIssuedQty = (float) ($item['issued_quantity'] ?? 0);
            $stockDelta = $finalIssuedQty - $oldIssuedQty;
            if ($stockDelta != 0) {
                $stockUpd = $db->prepare("UPDATE materials SET current_stock = current_stock - :delta, updated_at = NOW() WHERE id = :mat_id");
                $stockUpd->execute([
                    ':delta'  => $stockDelta,
                    ':mat_id' => (int) $item['material_id']
                ]);
            }

            // If sub-requisition was previously exported, flag as EXPORTED_MODIFIED
            if ($item['tally_export_status'] === 'EXPORTED') {
                $subUpd = $db->prepare("UPDATE requisition_subs SET tally_export_status = 'EXPORTED_MODIFIED' WHERE id = :sub_id");
                $subUpd->execute([':sub_id' => $item['sub_requisition_id']]);
            }

            // Recalculate parent statuses
            RequisitionService::refreshStatuses($db, (int) $item['requisition_id']);

            Logger::logActivity($storeUserId, "STORE_ACTION_{$actionType}", 'requisition_items', (string) $itemId, $oldData, [
                'status'          => $newStatus,
                'issued_quantity' => $finalIssuedQty,
                'amount'          => $amount,
                'action_by'       => $storeUserId
            ]);

            // Dispatch 1-to-1 Push Notification via OneSignal strictly to this requester
            try {
                $requesterId = (int) ($item['user_id'] ?? 0);
                if ($requesterId > 0) {
                    $matName = $item['material_name'] ?? 'Material';
                    $locName = $item['location_name'] ?? 'Site';
                    $unit = $item['unit_snapshot'] ?? '';
                    $storeRemark = !empty($remark) ? trim($remark) : '';

                    // Clean quantity display (e.g. 20 instead of 20.00)
                    $cleanIssuedQty = (floor($finalIssuedQty) == $finalIssuedQty) ? (int)$finalIssuedQty : $finalIssuedQty;
                    $cleanReqQty = (floor($reqQty) == $reqQty) ? (int)$reqQty : $reqQty;

                    if ($actionType === 'FULL_ISSUE') {
                        $accentColor = 'FF16A34A'; // Emerald Green
                        $notifTitle = "✅ Material Issue Ho Gaya! • {$locName}";
                        $notifMsg = "Store se aapka {$cleanIssuedQty} {$unit} {$matName} issue kar diya gaya hai. Kripya counter se collect kar lein.";
                        $voiceText = "Store se aapka {$cleanIssuedQty} {$unit} {$matName} issue ho gaya hai, kripya counter se collect kar lein.";
                    } elseif ($actionType === 'PARTIAL_ISSUE') {
                        $accentColor = 'FFEA580C'; // Amber Orange
                        $notifTitle = "⚡ Partial Issue: {$matName} ({$cleanIssuedQty}/{$cleanReqQty} {$unit})";
                        $notifMsg = "Aapke {$cleanReqQty} me se {$cleanIssuedQty} {$unit} issue hua hai." . ($storeRemark ? " (Store Note: {$storeRemark})" : "");
                        $voiceText = "Dhyan dein! {$matName} {$cleanReqQty} me se sirf {$cleanIssuedQty} {$unit} issue hua hai." . ($storeRemark ? " Store Note: {$storeRemark}" : "");
                    } else {
                        $accentColor = 'FFDC2626'; // Red
                        $notifTitle = "❌ Stock Me Nahi Hai: {$matName}";
                        $notifMsg = "{$matName} filhal store me available nahi hai." . ($storeRemark ? " (Store Note: {$storeRemark})" : "");
                        $voiceText = "Alert! {$matName} store me available nahi hai." . ($storeRemark ? " Note: {$storeRemark}" : "");
                    }

                    OneSignalService::sendToUser($requesterId, $notifTitle, $notifMsg, [
                        'screen'         => 'my_requisition',
                        'requisition_id' => (int) $item['requisition_id'],
                        'item_id'        => $itemId,
                        'voice_text'     => $voiceText,
                        'status'         => $newStatus
                    ], $accentColor);
                }
            } catch (Throwable $notifErr) {
                error_log("[OneSignal] Notification send failed: " . $notifErr->getMessage());
            }

            return [
                'item_id'         => $itemId,
                'status'          => $newStatus,
                'issued_quantity' => $finalIssuedQty,
                'amount'          => $amount,
                'is_locked'       => true
            ];
        });
    }

    /**
     * Create an Emergency Issue transaction from Store Panel
     */
    public static function createEmergencyIssue(
        int $storeUserId,
        int $targetUserId,
        int $materialId,
        float $quantity,
        int $locationId,
        string $reason,
        ?string $remark = null
    ): array {
        if ($quantity <= 0) {
            throw new Exception("Quantity must be greater than 0.");
        }
        if (empty(trim($reason))) {
            throw new Exception("Emergency reason is mandatory.");
        }

        return Database::transaction(function (PDO $db) use ($storeUserId, $targetUserId, $materialId, $quantity, $locationId, $reason, $remark) {
            // Verify Material
            $mat = Database::queryOne("SELECT * FROM materials WHERE id = :id AND status != 'INACTIVE'", [':id' => $materialId]);
            if (!$mat) {
                throw new Exception("Selected material is invalid.");
            }

            // Verify Location
            $loc = Database::queryOne("SELECT * FROM locations WHERE id = :id AND status = 'ACTIVE'", [':id' => $locationId]);
            if (!$loc) {
                throw new Exception("Selected location is invalid.");
            }

            // Verify User
            $user = Database::queryOne("SELECT * FROM users WHERE id = :id AND status = 'ACTIVE'", [':id' => $targetUserId]);
            if (!$user) {
                throw new Exception("Selected user is invalid.");
            }

            $today = date('Y-m-d');
            $unitRate = (float) $mat['default_rate'];
            $amount = round($quantity * $unitRate, 2);

            // 1. Link or create in user's master requisition
            $master = RequisitionService::getOrCreateMasterRequisition($db, $targetUserId, $today);
            $sub = RequisitionService::getOrCreateSubRequisition($db, (int) $master['id'], $master['requisition_no'], $locationId);

            // 2. Insert item into requisition_items as pre-ISSUED emergency item
            $itemSql = "INSERT INTO requisition_items (
                            sub_requisition_id, material_id, material_name_snapshot, unit_snapshot,
                            requested_quantity, issued_quantity, unit_rate, amount, remark,
                            status, is_emergency, store_action_by, store_action_at, created_at
                        ) VALUES (
                            :sub_id, :mat_id, :mat_name, :unit,
                            :req_qty, :iss_qty, :rate, :amount, :remark,
                            'ISSUED', 1, :store_uid, NOW(), NOW()
                        )";

            $itemStmt = $db->prepare($itemSql);
            $itemStmt->execute([
                ':sub_id'    => $sub['id'],
                ':mat_id'    => $materialId,
                ':mat_name'  => $mat['name'],
                ':unit'      => $mat['unit'],
                ':req_qty'   => $quantity,
                ':iss_qty'   => $quantity,
                ':rate'      => $unitRate,
                ':amount'    => $amount,
                ':remark'    => $remark ? "[EMERGENCY] {$remark}" : "[EMERGENCY] {$reason}",
                ':store_uid' => $storeUserId
            ]);
            $itemId = (int) $db->lastInsertId();

            // 3. Record in emergency_issues register
            $emergSql = "INSERT INTO emergency_issues (
                            user_id, material_id, material_name_snapshot, quantity, unit,
                            unit_rate, amount, location_id, remark, reason,
                            requisition_id, requisition_item_id, issued_by, issued_at, status, created_at
                         ) VALUES (
                            :uid, :mat_id, :mat_name, :qty, :unit,
                            :rate, :amount, :loc_id, :remark, :reason,
                            :req_id, :item_id, :store_uid, NOW(), 'LINKED_TO_REQUISITION', NOW()
                         )";

            $emergStmt = $db->prepare($emergSql);
            $emergStmt->execute([
                ':uid'       => $targetUserId,
                ':mat_id'    => $materialId,
                ':mat_name'  => $mat['name'],
                ':qty'       => $quantity,
                ':unit'      => $mat['unit'],
                ':rate'      => $unitRate,
                ':amount'    => $amount,
                ':loc_id'    => $locationId,
                ':remark'    => $remark,
                ':reason'    => $reason,
                ':req_id'    => $master['id'],
                ':item_id'   => $itemId,
                ':store_uid' => $storeUserId
            ]);
            $emergId = (int) $db->lastInsertId();

            // 4. Deduct physical stock in materials table
            $stockUpd = $db->prepare("UPDATE materials SET current_stock = current_stock - :qty, updated_at = NOW() WHERE id = :mat_id");
            $stockUpd->execute([
                ':qty'    => $quantity,
                ':mat_id' => $materialId
            ]);

            // Refresh Statuses
            RequisitionService::refreshStatuses($db, (int) $master['id']);

            Logger::logActivity($storeUserId, 'EMERGENCY_ISSUE_CREATED', 'emergency_issues', (string) $emergId, null, [
                'target_user'        => $user['name'],
                'material_name'      => $mat['name'],
                'quantity'           => $quantity,
                'sub_requisition_no' => $sub['sub_requisition_no']
            ]);

            // Dispatch 1-to-1 Push Notification via OneSignal strictly to this recipient
            try {
                $cleanQty = (floor($quantity) == $quantity) ? (int)$quantity : $quantity;
                $notifTitle = "🚨 Emergency Material Handover";
                $notifMsg = "Store ne aapke naam par {$cleanQty} {$mat['unit']} {$mat['name']} emergency issue kiya hai ({$loc['name']}).";
                $voiceText = "Emergency Alert! Store ne aapke naam par {$cleanQty} {$mat['unit']} {$mat['name']} emergency issue kiya hai.";

                OneSignalService::sendToUser($targetUserId, $notifTitle, $notifMsg, [
                    'screen'         => 'my_requisition',
                    'requisition_id' => (int) $master['id'],
                    'item_id'        => $itemId,
                    'voice_text'     => $voiceText,
                    'status'         => 'ISSUED'
                ], 'FFE11D48');
            } catch (Throwable $notifErr) {
                error_log("[OneSignal] Emergency notification send failed: " . $notifErr->getMessage());
            }

            return [
                'emergency_id'       => $emergId,
                'requisition_item_id'=> $itemId,
                'master_requisition' => $master['requisition_no'],
                'sub_requisition_no' => $sub['sub_requisition_no'],
                'location_name'      => $loc['name'],
                'amount'             => $amount
            ];
        });
    }

    /**
     * Create Multi-Item / Bulk Emergency Issue transaction
     */
    public static function createEmergencyIssueBulk(
        int $storeUserId,
        int $targetUserId,
        int $locationId,
        string $reason,
        array $items,
        ?string $remark = null
    ): array {
        if (empty($items)) {
            throw new Exception("Please add at least one material to issue.");
        }
        if (empty(trim($reason))) {
            throw new Exception("Emergency reason is mandatory.");
        }

        return Database::transaction(function (PDO $db) use ($storeUserId, $targetUserId, $locationId, $reason, $items, $remark) {
            // Verify Location
            $loc = Database::queryOne("SELECT * FROM locations WHERE id = :id AND status = 'ACTIVE'", [':id' => $locationId]);
            if (!$loc) {
                throw new Exception("Selected location is invalid.");
            }

            // Verify User
            $user = Database::queryOne("SELECT * FROM users WHERE id = :id AND status = 'ACTIVE'", [':id' => $targetUserId]);
            if (!$user) {
                throw new Exception("Selected recipient employee is invalid.");
            }

            $today = date('Y-m-d');

            // 1. Link or create in user's master requisition
            $master = RequisitionService::getOrCreateMasterRequisition($db, $targetUserId, $today);
            $sub = RequisitionService::getOrCreateSubRequisition($db, (int) $master['id'], $master['requisition_no'], $locationId);

            $itemSql = "INSERT INTO requisition_items (
                            sub_requisition_id, material_id, material_name_snapshot, unit_snapshot,
                            requested_quantity, issued_quantity, unit_rate, amount, remark,
                            status, is_emergency, store_action_by, store_action_at, created_at
                        ) VALUES (
                            :sub_id, :mat_id, :mat_name, :unit,
                            :req_qty, :iss_qty, :rate, :amount, :remark,
                            'ISSUED', 1, :store_uid, NOW(), NOW()
                        )";
            $itemStmt = $db->prepare($itemSql);

            $emergSql = "INSERT INTO emergency_issues (
                            user_id, material_id, material_name_snapshot, quantity, unit,
                            unit_rate, amount, location_id, remark, reason,
                            requisition_id, requisition_item_id, issued_by, issued_at, status, created_at
                         ) VALUES (
                            :uid, :mat_id, :mat_name, :qty, :unit,
                            :rate, :amount, :loc_id, :remark, :reason,
                            :req_id, :item_id, :store_uid, NOW(), 'LINKED_TO_REQUISITION', NOW()
                         )";
            $emergStmt = $db->prepare($emergSql);

            $issuedSummary = [];
            $totalAmount = 0.0;
            $firstItemId = null;
            $emergIds = [];

            foreach ($items as $entry) {
                $materialId = (int)($entry['material_id'] ?? 0);
                $quantity = (float)($entry['quantity'] ?? 0);
                $itemRemark = !empty($entry['remark']) ? trim($entry['remark']) : $remark;

                if ($materialId <= 0 || $quantity <= 0) {
                    continue;
                }

                $mat = Database::queryOne("SELECT * FROM materials WHERE id = :id AND status != 'INACTIVE'", [':id' => $materialId]);
                if (!$mat) {
                    throw new Exception("Material #{$materialId} not found or inactive.");
                }

                $unitRate = (float)$mat['default_rate'];
                $amount = round($quantity * $unitRate, 2);
                $totalAmount += $amount;

                // 2. Insert into requisition_items
                $itemStmt->execute([
                    ':sub_id'    => $sub['id'],
                    ':mat_id'    => $materialId,
                    ':mat_name'  => $mat['name'],
                    ':unit'      => $mat['unit'],
                    ':req_qty'   => $quantity,
                    ':iss_qty'   => $quantity,
                    ':rate'      => $unitRate,
                    ':amount'    => $amount,
                    ':remark'    => $itemRemark ? "[EMERGENCY] {$itemRemark}" : "[EMERGENCY] {$reason}",
                    ':store_uid' => $storeUserId
                ]);
                $itemId = (int)$db->lastInsertId();
                if ($firstItemId === null) $firstItemId = $itemId;

                // 3. Insert into emergency_issues
                $emergStmt->execute([
                    ':uid'       => $targetUserId,
                    ':mat_id'    => $materialId,
                    ':mat_name'  => $mat['name'],
                    ':qty'       => $quantity,
                    ':unit'      => $mat['unit'],
                    ':rate'      => $unitRate,
                    ':amount'    => $amount,
                    ':loc_id'    => $locationId,
                    ':remark'    => $itemRemark,
                    ':reason'    => $reason,
                    ':req_id'    => $master['id'],
                    ':item_id'   => $itemId,
                    ':store_uid' => $storeUserId
                ]);
                $emergId = (int)$db->lastInsertId();
                $emergIds[] = $emergId;

                // 4. Deduct physical stock in materials table
                $stockUpd = $db->prepare("UPDATE materials SET current_stock = current_stock - :qty, updated_at = NOW() WHERE id = :mat_id");
                $stockUpd->execute([
                    ':qty'    => $quantity,
                    ':mat_id' => $materialId
                ]);

                $cleanQty = (floor($quantity) == $quantity) ? (int)$quantity : $quantity;
                $issuedSummary[] = "{$cleanQty} {$mat['unit']} {$mat['name']}";
            }

            if (empty($emergIds)) {
                throw new Exception("No valid items were issued.");
            }

            // Refresh Statuses
            RequisitionService::refreshStatuses($db, (int)$master['id']);

            Logger::logActivity($storeUserId, 'EMERGENCY_ISSUE_BULK_CREATED', 'emergency_issues', implode(',', $emergIds), null, [
                'target_user'        => $user['name'],
                'items_count'        => count($emergIds),
                'sub_requisition_no' => $sub['sub_requisition_no']
            ]);

            // Dispatch 1-to-1 Push Notification via OneSignal strictly to this recipient
            try {
                $itemText = count($issuedSummary) <= 2 
                    ? implode(', ', $issuedSummary) 
                    : count($issuedSummary) . " items (" . $issuedSummary[0] . " & more)";
                $notifTitle = "🚨 Emergency Material Handover (" . count($issuedSummary) . " Items)";
                $notifMsg = "Store ne aapke naam par emergency issue kiya hai: {$itemText} ({$loc['name']}).";
                $voiceText = "Emergency Alert! Store ne aapke naam par " . count($issuedSummary) . " materials emergency issue kiye hain.";

                OneSignalService::sendToUser($targetUserId, $notifTitle, $notifMsg, [
                    'screen'         => 'my_requisition',
                    'requisition_id' => (int)$master['id'],
                    'item_id'        => $firstItemId,
                    'voice_text'     => $voiceText,
                    'status'         => 'ISSUED'
                ], 'FFE11D48');
            } catch (Throwable $notifErr) {
                error_log("[OneSignal] Emergency notification send failed: " . $notifErr->getMessage());
            }

            return [
                'emergency_ids'      => $emergIds,
                'items_count'        => count($emergIds),
                'master_requisition' => $master['requisition_no'],
                'sub_requisition_no' => $sub['sub_requisition_no'],
                'location_name'      => $loc['name'],
                'total_amount'       => $totalAmount
            ];
        });
    }

    /**
     * Get Emergency Issues history
     */
    public static function getEmergencyHistory(int $page = 1, int $limit = 20): array {
        $offset = ($page - 1) * $limit;
        $totalRow = Database::queryOne("SELECT COUNT(*) AS total FROM emergency_issues");
        $totalRecords = (int) ($totalRow['total'] ?? 0);

        $sql = "SELECT e.*, u.name AS user_name, u.employee_code,
                       l.name AS location_name, m.code AS material_code,
                       st.name AS issued_by_name, r.requisition_no
                FROM emergency_issues e
                JOIN users u ON e.user_id = u.id
                JOIN locations l ON e.location_id = l.id
                JOIN materials m ON e.material_id = m.id
                JOIN users st ON e.issued_by = st.id
                LEFT JOIN requisitions r ON e.requisition_id = r.id
                ORDER BY e.issued_at DESC, e.id DESC
                LIMIT :limit OFFSET :offset";

        $stmt = Database::getConnection()->prepare($sql);
        $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
        $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
        $stmt->execute();
        $items = $stmt->fetchAll();

        return [
            'current_page'  => $page,
            'per_page'      => $limit,
            'total_records' => $totalRecords,
            'total_pages'   => ceil($totalRecords / $limit),
            'items'         => $items
        ];
    }
}
