<?php
/**
 * REST API Front Controller & Dispatcher
 * Pure PHP REST API Engine
 */

require_once __DIR__ . '/../config/config.php';
require_once __DIR__ . '/../core/Database.php';
require_once __DIR__ . '/../core/Router.php';
require_once __DIR__ . '/../core/Request.php';
require_once __DIR__ . '/../core/Response.php';
require_once __DIR__ . '/../core/Auth.php';
require_once __DIR__ . '/../core/Logger.php';
require_once __DIR__ . '/../services/TimeService.php';
require_once __DIR__ . '/../services/SequenceService.php';
require_once __DIR__ . '/../services/RequisitionService.php';
require_once __DIR__ . '/../services/StoreService.php';
require_once __DIR__ . '/../services/AdminService.php';
require_once __DIR__ . '/../services/TallyService.php';

// ------------------------------------------------------------
// 1. AUTHENTICATION ENDPOINTS
// ------------------------------------------------------------
Router::post('/api/auth/login', function () {
    $identifier = Request::input('identifier') ?? Request::input('employee_code') ?? Request::input('email');
    $password = Request::input('password');
    $deviceName = Request::input('device_name', 'Mobile App');

    if (empty($identifier) || empty($password)) {
        Response::error('Identifier and password are required.', 'VALIDATION_ERROR', 422);
    }

    $user = Auth::attempt($identifier, $password);
    if (!$user) {
        Response::error('Invalid credentials or account is inactive.', 'INVALID_CREDENTIALS', 401);
    }

    $token = Auth::createApiToken((int) $user['id'], $deviceName);

    Logger::logActivity((int) $user['id'], 'USER_LOGIN', 'users', (string) $user['id']);

    Response::success([
        'token' => $token,
        'user'  => $user
    ], 'Login successful.');
});

Router::post('/api/auth/logout', function () {
    Auth::requireAuth();
    Auth::revokeCurrentToken();
    Response::success(null, 'Logged out successfully.');
});

Router::get('/api/auth/me', function () {
    $user = Auth::requireAuth();
    $timing = TimeService::getTimingStatus();
    Response::success([
        'user'   => $user,
        'timing' => $timing
    ]);
});

Router::post('/api/user/change-password', function () {
    $user = Auth::requireAuth();
    $currentPassword = Request::input('current_password');
    $newPassword = Request::input('new_password');
    $confirmPassword = Request::input('confirm_password');

    if (empty($currentPassword) || empty($newPassword)) {
        Response::error('Current password and new password are required.', 'VALIDATION_ERROR', 422);
    }

    if (strlen($newPassword) < 6) {
        Response::error('New password must be at least 6 characters long.', 'VALIDATION_ERROR', 422);
    }

    if (!empty($confirmPassword) && $newPassword !== $confirmPassword) {
        Response::error('New password and confirm password do not match.', 'VALIDATION_ERROR', 422);
    }

    // Verify current password from database
    $dbUser = Database::queryOne("SELECT password_hash FROM users WHERE id = :id", [':id' => $user['id']]);
    if (!$dbUser || !password_verify($currentPassword, $dbUser['password_hash'])) {
        Response::error('Current password is incorrect.', 'INVALID_PASSWORD', 400);
    }

    $newHash = password_hash($newPassword, PASSWORD_BCRYPT);
    Database::execute("UPDATE users SET password_hash = :hash, updated_at = NOW() WHERE id = :id", [
        ':hash' => $newHash,
        ':id'   => $user['id']
    ]);

    Logger::logActivity((int) $user['id'], 'USER_CHANGE_PASSWORD', 'users', (string) $user['id']);

    Response::success(null, 'Password changed successfully.');
});

Router::get('/api/user/profile-stats', function () {
    $user = Auth::requireAuth();
    $userId = (int) $user['id'];

    $totalReqs = Database::queryOne("SELECT COUNT(*) AS count FROM requisitions WHERE user_id = :uid", [':uid' => $userId]);
    $itemsStats = Database::queryOne("
        SELECT 
            COUNT(i.id) AS total_items,
            COALESCE(SUM(CASE WHEN i.status = 'ISSUED' THEN 1 ELSE 0 END), 0) AS issued_items,
            COALESCE(SUM(CASE WHEN i.status = 'PARTIALLY_ISSUED' THEN 1 ELSE 0 END), 0) AS partial_items,
            COALESCE(SUM(CASE WHEN i.status = 'NOT_AVAILABLE' THEN 1 ELSE 0 END), 0) AS not_available_items,
            COALESCE(SUM(CASE WHEN i.status = 'PENDING' THEN 1 ELSE 0 END), 0) AS pending_items,
            COALESCE(SUM(i.issued_quantity), 0) AS total_issued_qty,
            COALESCE(SUM(CASE WHEN i.is_emergency = 1 THEN 1 ELSE 0 END), 0) AS emergency_items
        FROM requisitions r
        JOIN requisition_subs s ON r.id = s.requisition_id
        JOIN requisition_items i ON s.id = i.sub_requisition_id
        WHERE r.user_id = :uid
    ", [':uid' => $userId]);

    Response::success([
        'total_requisitions'  => (int) ($totalReqs['count'] ?? 0),
        'total_items'         => (int) ($itemsStats['total_items'] ?? 0),
        'issued_items'        => (int) ($itemsStats['issued_items'] ?? 0),
        'partial_items'       => (int) ($itemsStats['partial_items'] ?? 0),
        'not_available_items' => (int) ($itemsStats['not_available_items'] ?? 0),
        'pending_items'       => (int) ($itemsStats['pending_items'] ?? 0),
        'total_issued_qty'    => (float) ($itemsStats['total_issued_qty'] ?? 0),
        'emergency_items'     => (int) ($itemsStats['emergency_items'] ?? 0),
    ]);
});

// ------------------------------------------------------------
// 2. USER APP ENDPOINTS (Flutter Android)
// ------------------------------------------------------------
Router::get('/api/user/dashboard', function () {
    $user = Auth::requireAuth();
    $timing = TimeService::getTimingStatus();
    $todayReq = RequisitionService::getTodayRequisition((int) $user['id']);

    Response::success([
        'user'                 => $user,
        'timing'               => $timing,
        'today_requisition'    => $todayReq,
        'has_today_requisition'=> ($todayReq !== null)
    ]);
});

Router::get('/api/user/materials', function () {
    Auth::requireAuth();
    $query = Request::input('q');
    
    if (!empty($query)) {
        $sql = "SELECT id, name, code, unit, default_rate 
                FROM materials 
                WHERE status = 'ACTIVE' AND (name LIKE :q1 OR code LIKE :q2) 
                ORDER BY name ASC LIMIT 50";
        $materials = Database::query($sql, [
            ':q1' => "%{$query}%",
            ':q2' => "%{$query}%"
        ]);
    } else {
        $sql = "SELECT id, name, code, unit, default_rate 
                FROM materials 
                WHERE status = 'ACTIVE' 
                ORDER BY name ASC LIMIT 100";
        $materials = Database::query($sql);
    }

    Response::success($materials);
});

Router::get('/api/user/locations', function () {
    Auth::requireAuth();
    $locations = Database::query("SELECT id, name, code FROM locations WHERE status = 'ACTIVE' ORDER BY name ASC");
    Response::success($locations);
});

Router::get('/api/user/requisition/today', function () {
    $user = Auth::requireAuth();
    $req = RequisitionService::getTodayRequisition((int) $user['id']);
    Response::success($req);
});

Router::post('/api/user/requisition/items', function () {
    $user = Auth::requireAuth();
    $materialId = (int) Request::input('material_id');
    $quantity = (float) Request::input('quantity');
    $locationId = (int) Request::input('location_id');
    $remark = Request::input('remark');

    if ($materialId <= 0 || $quantity <= 0 || $locationId <= 0) {
        Response::error('Material, valid quantity and location are required.', 'VALIDATION_ERROR', 422);
    }

    try {
        $result = RequisitionService::addItem((int) $user['id'], $materialId, $quantity, $locationId, $remark);
        Response::success($result, 'Item added successfully.', 201);
    } catch (Throwable $e) {
        Response::error($e->getMessage(), 'REQUISITION_ERROR', 400);
    }
});

Router::post('/api/user/requisition/items/bulk', function () {
    $user = Auth::requireAuth();
    $items = Request::input('items');

    if (!is_array($items) || empty($items)) {
        Response::error('Items list is required.', 'VALIDATION_ERROR', 422);
    }

    $addedResults = [];
    $errors = [];

    foreach ($items as $idx => $it) {
        $materialId = (int) ($it['material_id'] ?? 0);
        $quantity = (float) ($it['quantity'] ?? 0);
        $locationId = (int) ($it['location_id'] ?? 0);
        $remark = $it['remark'] ?? null;

        if ($materialId <= 0 || $quantity <= 0 || $locationId <= 0) {
            $errors[] = "Item #" . ($idx + 1) . " has invalid material, quantity or location.";
            continue;
        }

        try {
            $addedResults[] = RequisitionService::addItem((int) $user['id'], $materialId, $quantity, $locationId, $remark);
        } catch (Throwable $e) {
            $errors[] = "Item #" . ($idx + 1) . ": " . $e->getMessage();
        }
    }

    if (empty($addedResults) && !empty($errors)) {
        Response::error(implode(', ', $errors), 'BULK_ADD_FAILED', 400);
    }

    Response::success([
        'added_count' => count($addedResults),
        'errors'      => $errors
    ], count($addedResults) . ' items added successfully.', 201);
});

Router::get('/api/user/notifications', function () {
    $user = Auth::requireAuth();
    $sql = "SELECT i.id, i.status, i.requested_quantity, i.issued_quantity, i.unit_snapshot,
                   i.store_remark, i.store_action_at,
                   m.name AS material_name, m.code AS material_code,
                   l.name AS location_name,
                   u.name AS store_user_name
            FROM requisition_items i
            JOIN requisition_subs s ON i.sub_requisition_id = s.id
            JOIN requisitions r ON s.requisition_id = r.id
            JOIN materials m ON i.material_id = m.id
            JOIN locations l ON s.location_id = l.id
            LEFT JOIN users u ON i.store_action_by = u.id
            WHERE r.user_id = :uid AND i.store_action_at IS NOT NULL
            ORDER BY i.store_action_at DESC
            LIMIT 25";
    $notifications = Database::query($sql, [':uid' => (int) $user['id']]);
    Response::success($notifications);
});

Router::put('/api/user/requisition/items/{id}', function ($params) {
    $user = Auth::requireAuth();
    $itemId = (int) $params['id'];
    $quantity = (float) Request::input('quantity');
    $locationId = (int) Request::input('location_id');
    $remark = Request::input('remark');

    if ($quantity <= 0 || $locationId <= 0) {
        Response::error('Valid quantity and location are required.', 'VALIDATION_ERROR', 422);
    }

    try {
        $result = RequisitionService::updatePendingItem((int) $user['id'], $itemId, $quantity, $locationId, $remark);
        Response::success($result, 'Item updated successfully.');
    } catch (Throwable $e) {
        Response::error($e->getMessage(), 'ITEM_LOCKED_OR_INVALID', 400);
    }
});

Router::delete('/api/user/requisition/items/{id}', function ($params) {
    $user = Auth::requireAuth();
    $itemId = (int) $params['id'];

    try {
        RequisitionService::deletePendingItem((int) $user['id'], $itemId);
        Response::success(null, 'Item deleted successfully.');
    } catch (Throwable $e) {
        Response::error($e->getMessage(), 'DELETE_FAILED', 400);
    }
});

Router::get('/api/user/requisition/history', function () {
    $user = Auth::requireAuth();
    $page = max(1, (int) Request::input('page', 1));
    $limit = min(50, max(1, (int) Request::input('limit', 10)));
    
    $history = RequisitionService::getUserHistory((int) $user['id'], $page, $limit);
    Response::success($history);
});

Router::get('/api/user/requisition/{id}', function ($params) {
    $user = Auth::requireAuth();
    $reqId = (int) $params['id'];

    $req = RequisitionService::formatFullRequisition($reqId);
    if (!$req) {
        Response::notFound('Requisition not found.');
    }

    if ((int) $req['user_id'] !== (int) $user['id'] && !in_array($user['role'], ['SUPER_ADMIN', 'ADMIN', 'STORE_USER'])) {
        Response::forbidden('Unauthorized to view this requisition.');
    }

    Response::success($req);
});

// ------------------------------------------------------------
// 3. STORE PANEL ENDPOINTS
// ------------------------------------------------------------
Router::get('/api/store/users', function () {
    Auth::requireRole(['SUPER_ADMIN', 'ADMIN', 'STORE_USER']);
    $date = Request::input('date', date('Y-m-d'));
    $users = StoreService::getUsersWithRequisitions($date);
    $timing = TimeService::getTimingStatus($date);
    Response::success([
        'users'  => $users,
        'timing' => $timing
    ]);
});

Router::get('/api/store/requisition', function () {
    Auth::requireRole(['SUPER_ADMIN', 'ADMIN', 'STORE_USER']);
    $userId = (int) Request::input('user_id');
    $date = Request::input('date', date('Y-m-d'));

    if ($userId <= 0) {
        Response::error('User ID is required.', 'VALIDATION_ERROR', 422);
    }

    $master = Database::queryOne("SELECT id FROM requisitions WHERE user_id = :uid AND requisition_date = :date LIMIT 1", [
        ':uid'  => $userId,
        ':date' => $date
    ]);

    if (!$master) {
        Response::success(null, 'No requisition found for this user on the specified date.');
    }

    $data = RequisitionService::formatFullRequisition((int) $master['id']);
    Response::success($data);
});

Router::post('/api/store/items/{id}/issue', function ($params) {
    $storeUser = Auth::requireRole(['SUPER_ADMIN', 'ADMIN', 'STORE_USER']);
    $itemId = (int) $params['id'];
    $remark = Request::input('remark');

    try {
        $result = StoreService::processItemAction((int) $storeUser['id'], $itemId, 'FULL_ISSUE', 0, $remark);
        Response::success($result, 'Material marked as Issued.');
    } catch (Throwable $e) {
        Response::error($e->getMessage(), 'STORE_ACTION_ERROR', 400);
    }
});

Router::post('/api/store/items/{id}/partial', function ($params) {
    $storeUser = Auth::requireRole(['SUPER_ADMIN', 'ADMIN', 'STORE_USER']);
    $itemId = (int) $params['id'];
    $issuedQty = (float) Request::input('issued_quantity');
    $remark = Request::input('remark');

    try {
        $result = StoreService::processItemAction((int) $storeUser['id'], $itemId, 'PARTIAL_ISSUE', $issuedQty, $remark);
        Response::success($result, 'Material partially issued.');
    } catch (Throwable $e) {
        Response::error($e->getMessage(), 'STORE_ACTION_ERROR', 400);
    }
});

Router::post('/api/store/items/{id}/not-available', function ($params) {
    $storeUser = Auth::requireRole(['SUPER_ADMIN', 'ADMIN', 'STORE_USER']);
    $itemId = (int) $params['id'];
    $remark = Request::input('remark', 'Not available in store');

    try {
        $result = StoreService::processItemAction((int) $storeUser['id'], $itemId, 'NOT_AVAILABLE', 0, $remark);
        Response::success($result, 'Material marked as Not Available.');
    } catch (Throwable $e) {
        Response::error($e->getMessage(), 'STORE_ACTION_ERROR', 400);
    }
});

Router::post('/api/store/emergency', function () {
    $storeUser = Auth::requireRole(['SUPER_ADMIN', 'ADMIN', 'STORE_USER']);
    $targetUserId = (int) Request::input('user_id');
    $locationId = (int) Request::input('location_id');
    $reason = Request::input('reason');
    $remark = Request::input('remark');
    $items = Request::input('items');

    if ($targetUserId <= 0 || $locationId <= 0 || empty(trim((string)$reason))) {
        Response::error('User, Location, and Emergency reason are mandatory.', 'VALIDATION_ERROR', 422);
    }

    try {
        if (!empty($items) && is_array($items)) {
            // Bulk multi-material issue
            $result = StoreService::createEmergencyIssueBulk(
                (int) $storeUser['id'],
                $targetUserId,
                $locationId,
                $reason,
                $items,
                $remark
            );
            Response::success($result, 'Emergency issue recorded successfully for ' . count($result['emergency_ids'] ?? []) . ' item(s).', 201);
        } else {
            // Single material issue (legacy backward compatibility)
            $materialId = (int) Request::input('material_id');
            $quantity = (float) Request::input('quantity');

            if ($materialId <= 0 || $quantity <= 0) {
                Response::error('Material and valid quantity are required.', 'VALIDATION_ERROR', 422);
            }

            $result = StoreService::createEmergencyIssue(
                (int) $storeUser['id'],
                $targetUserId,
                $materialId,
                $quantity,
                $locationId,
                $reason,
                $remark
            );
            Response::success($result, 'Emergency issue recorded successfully.', 201);
        }
    } catch (Throwable $e) {
        Response::error($e->getMessage(), 'EMERGENCY_ERROR', 400);
    }
});

Router::get('/api/store/emergency', function () {
    Auth::requireRole(['SUPER_ADMIN', 'ADMIN', 'STORE_USER']);
    $page = max(1, (int) Request::input('page', 1));
    $limit = min(50, max(1, (int) Request::input('limit', 20)));
    $data = StoreService::getEmergencyHistory($page, $limit);
    Response::success($data);
});

Router::get('/api/store/emergency/options', function () {
    Auth::requireRole(['SUPER_ADMIN', 'ADMIN', 'STORE_USER']);
    $users = Database::query("SELECT u.id, u.name, u.employee_code, d.name AS department_name FROM users u LEFT JOIN departments d ON u.department_id = d.id WHERE u.status = 'ACTIVE' ORDER BY u.name ASC");
    $locations = Database::query("SELECT id, name, code FROM locations WHERE status = 'ACTIVE' ORDER BY name ASC");
    $materials = Database::query("SELECT m.id, m.code, m.name, m.unit, m.default_rate, COALESCE(m.current_stock, 0) AS current_stock, c.name AS category 
                                 FROM materials m 
                                 LEFT JOIN material_categories c ON m.category_id = c.id 
                                 WHERE m.status = 'ACTIVE' 
                                 ORDER BY m.name ASC");

    Response::success([
        'users'     => $users,
        'locations' => $locations,
        'materials' => $materials
    ]);
});

Router::get('/api/store/feed', function () {
    Auth::requireRole(['SUPER_ADMIN', 'ADMIN', 'STORE_USER']);
    $date = Request::input('date', date('Y-m-d'));
    $locationId = Request::input('location_id') ? (int) Request::input('location_id') : null;
    $statusFilter = Request::input('status');
    $search = trim((string) Request::input('search', ''));

    $where = ["r.requisition_date = :req_date"];
    $params = [':req_date' => $date];

    if ($locationId) {
        $where[] = "s.location_id = :loc_id";
        $params[':loc_id'] = $locationId;
    }
    if ($statusFilter && $statusFilter !== 'ALL') {
        if ($statusFilter === 'PARTIAL_ISSUED' || $statusFilter === 'PARTIALLY_ISSUED') {
            $where[] = "i.status = 'PARTIALLY_ISSUED'";
        } else {
            $where[] = "i.status = :status_filter";
            $params[':status_filter'] = $statusFilter;
        }
    }
    if ($search !== '') {
        $where[] = "(u.name LIKE :s1 OR u.employee_code LIKE :s2 OR i.material_name_snapshot LIKE :s3 OR l.name LIKE :s4 OR s.sub_requisition_no LIKE :s5)";
        $searchWildcard = "%{$search}%";
        $params[':s1'] = $searchWildcard;
        $params[':s2'] = $searchWildcard;
        $params[':s3'] = $searchWildcard;
        $params[':s4'] = $searchWildcard;
        $params[':s5'] = $searchWildcard;
    }

    $whereSql = implode(' AND ', $where);

    $sql = "SELECT i.id, i.sub_requisition_id, i.material_id, i.material_name_snapshot, i.unit_snapshot,
                   i.requested_quantity, i.issued_quantity, i.unit_rate, i.amount, i.remark, i.store_remark, i.status,
                   i.is_emergency, i.created_at, i.store_action_at,
                   m.code AS material_code, COALESCE(m.current_stock, 0) AS current_stock, c.name AS material_category,
                   s.sub_requisition_no, s.location_id, l.name AS location_name, l.code AS location_code,
                   r.id AS master_requisition_id, r.requisition_no AS master_requisition_no, r.requisition_date,
                   u.id AS user_id, u.name AS user_name, u.employee_code, u.mobile AS user_mobile,
                   d.name AS department_name
            FROM requisition_items i
            JOIN requisition_subs s ON i.sub_requisition_id = s.id
            JOIN requisitions r ON s.requisition_id = r.id
            JOIN locations l ON s.location_id = l.id
            JOIN users u ON r.user_id = u.id
            LEFT JOIN departments d ON u.department_id = d.id
            LEFT JOIN materials m ON i.material_id = m.id
            LEFT JOIN material_categories c ON m.category_id = c.id
            WHERE {$whereSql}
            ORDER BY (i.status = 'PENDING') DESC, i.created_at DESC";

    $items = Database::query($sql, $params);

    $statsSql = "SELECT 
                    COUNT(i.id) AS total_items,
                    SUM(CASE WHEN i.status = 'PENDING' THEN 1 ELSE 0 END) AS pending_count,
                    SUM(CASE WHEN i.status = 'ISSUED' THEN 1 ELSE 0 END) AS issued_count,
                    SUM(CASE WHEN i.status = 'PARTIALLY_ISSUED' THEN 1 ELSE 0 END) AS partial_count,
                    SUM(CASE WHEN i.status = 'NOT_AVAILABLE' THEN 1 ELSE 0 END) AS not_available_count,
                    SUM(CASE WHEN i.status IN ('ISSUED', 'PARTIALLY_ISSUED') THEN i.amount ELSE 0 END) AS total_issued_amount
                 FROM requisition_items i
                 JOIN requisition_subs s ON i.sub_requisition_id = s.id
                 JOIN requisitions r ON s.requisition_id = r.id
                 WHERE r.requisition_date = :today_date";

    $statsRow = Database::queryOne($statsSql, [':today_date' => $date]);
    $totalItems = (int) ($statsRow['total_items'] ?? 0);
    $pendingCount = (int) ($statsRow['pending_count'] ?? 0);
    $issuedCount = (int) ($statsRow['issued_count'] ?? 0);
    $partialCount = (int) ($statsRow['partial_count'] ?? 0);
    $naCount = (int) ($statsRow['not_available_count'] ?? 0);
    $totalAmount = (float) ($statsRow['total_issued_amount'] ?? 0.0);
    $completedCount = $issuedCount + $partialCount + $naCount;
    $progressPercent = ($totalItems > 0) ? (int) round(($completedCount / $totalItems) * 100) : 0;

    $locations = Database::query("SELECT id, name, code FROM locations WHERE status = 'ACTIVE' ORDER BY name ASC");
    $timing = TimeService::getTimingStatus($date);

    Response::success([
        'items'     => $items,
        'stats'     => [
            'total_items'         => $totalItems,
            'pending_count'       => $pendingCount,
            'issued_count'        => $issuedCount,
            'partial_count'       => $partialCount,
            'not_available_count' => $naCount,
            'total_issued_amount' => $totalAmount,
            'dispatch_progress'   => $progressPercent
        ],
        'locations' => $locations,
        'timing'    => $timing
    ]);
});

Router::post('/api/store/batch-action', function () {
    $storeUser = Auth::requireRole(['SUPER_ADMIN', 'ADMIN', 'STORE_USER']);
    $itemIds = Request::input('item_ids', []);
    $actionType = Request::input('action_type', 'FULL_ISSUE');
    $remark = Request::input('remark');

    if (empty($itemIds) || !is_array($itemIds)) {
        Response::error('Please select at least one item.', 'VALIDATION_ERROR', 422);
    }

    $processed = 0;
    $errors = [];

    foreach ($itemIds as $itemId) {
        try {
            StoreService::processItemAction((int) $storeUser['id'], (int) $itemId, $actionType, 0, $remark);
            $processed++;
        } catch (Throwable $e) {
            $errors[] = "Item #{$itemId}: " . $e->getMessage();
        }
    }

    Response::success([
        'processed_count' => $processed,
        'error_count'     => count($errors),
        'errors'          => $errors
    ], "{$processed} item(s) processed successfully.");
});

Router::get('/api/store/stock', function () {
    Auth::requireRole(['SUPER_ADMIN', 'ADMIN', 'STORE_USER']);
    $search = trim((string) Request::input('search', ''));
    $category = trim((string) Request::input('category', ''));

    $where = ["m.status = 'ACTIVE'"];
    $params = [];

    if ($search !== '') {
        $where[] = "(m.name LIKE :s1 OR m.code LIKE :s2)";
        $searchWildcard = "%{$search}%";
        $params[':s1'] = $searchWildcard;
        $params[':s2'] = $searchWildcard;
    }
    if ($category !== '') {
        $where[] = "c.name = :category";
        $params[':category'] = $category;
    }

    $whereSql = implode(' AND ', $where);
    $materials = Database::query("SELECT m.id, m.code, m.name, m.unit, m.default_rate, COALESCE(m.current_stock, 0) AS current_stock, c.name AS category 
                                  FROM materials m 
                                  LEFT JOIN material_categories c ON m.category_id = c.id 
                                  WHERE {$whereSql} 
                                  ORDER BY m.name ASC", $params);
    $categories = Database::query("SELECT DISTINCT c.name AS category 
                                   FROM materials m 
                                   JOIN material_categories c ON m.category_id = c.id 
                                   WHERE m.status = 'ACTIVE' AND c.name IS NOT NULL 
                                   ORDER BY c.name ASC");

    Response::success([
        'materials'  => $materials,
        'categories' => array_column($categories, 'category')
    ]);
});

Router::get('/api/store/materials/{id}/details', function ($params) {
    Auth::requireRole(['SUPER_ADMIN', 'ADMIN', 'STORE_USER']);
    $materialId = (int) ($params['id'] ?? 0);

    $material = Database::queryOne(
        "SELECT m.id, m.name, m.code, m.unit, m.default_rate, COALESCE(m.current_stock, 0) AS current_stock,
                m.category_id, c.name AS category_name, m.tally_item_name, m.tally_item_code, m.status,
                m.created_at, m.updated_at
         FROM materials m
         LEFT JOIN material_categories c ON m.category_id = c.id
         WHERE m.id = :id",
        [':id' => $materialId]
    );

    if (!$material) {
        Response::error('Material not found.', 'NOT_FOUND', 404);
    }

    // 1. Overall Aggregates
    $summary = Database::queryOne(
        "SELECT COUNT(i.id) AS total_requisition_count,
                COALESCE(SUM(i.requested_quantity), 0) AS total_requested_qty,
                COALESCE(SUM(i.issued_quantity), 0) AS total_issued_qty,
                COALESCE(SUM(i.amount), 0) AS total_issued_amount,
                COUNT(DISTINCT r.user_id) AS total_unique_users,
                COUNT(DISTINCT s.location_id) AS total_unique_locations
         FROM requisition_items i
         JOIN requisition_subs s ON i.sub_requisition_id = s.id
         JOIN requisitions r ON s.requisition_id = r.id
         WHERE i.material_id = :id",
        [':id' => $materialId]
    );

    // 2. User/Employee Breakdown
    $userBreakdown = Database::query(
        "SELECT u.id, u.name, u.employee_code, d.name AS department_name,
                COALESCE(SUM(i.issued_quantity), 0) AS total_issued_qty,
                COALESCE(SUM(i.requested_quantity), 0) AS total_requested_qty,
                COALESCE(SUM(i.amount), 0) AS total_amount,
                COUNT(i.id) AS requisition_count,
                MAX(i.created_at) AS last_issued_at
         FROM requisition_items i
         JOIN requisition_subs s ON i.sub_requisition_id = s.id
         JOIN requisitions r ON s.requisition_id = r.id
         JOIN users u ON r.user_id = u.id
         LEFT JOIN departments d ON u.department_id = d.id
         WHERE i.material_id = :id
         GROUP BY u.id, u.name, u.employee_code, d.name
         ORDER BY total_issued_qty DESC, last_issued_at DESC
         LIMIT 30",
        [':id' => $materialId]
    );

    // 3. Location Breakdown
    $locationBreakdown = Database::query(
        "SELECT l.id, l.name, l.code,
                COALESCE(SUM(i.issued_quantity), 0) AS total_issued_qty,
                COALESCE(SUM(i.requested_quantity), 0) AS total_requested_qty,
                COALESCE(SUM(i.amount), 0) AS total_amount,
                COUNT(i.id) AS requisition_count,
                MAX(i.created_at) AS last_issued_at
         FROM requisition_items i
         JOIN requisition_subs s ON i.sub_requisition_id = s.id
         JOIN locations l ON s.location_id = l.id
         WHERE i.material_id = :id
         GROUP BY l.id, l.name, l.code
         ORDER BY total_issued_qty DESC
         LIMIT 30",
        [':id' => $materialId]
    );

    // 4. Movement & Transaction History Log (Recent 50 transactions)
    $movementLog = Database::query(
        "SELECT i.id, i.material_name_snapshot, i.unit_snapshot, i.requested_quantity, i.issued_quantity,
                i.unit_rate, i.amount, i.remark, i.store_remark, i.status, i.is_emergency,
                i.created_at, i.store_action_at,
                r.requisition_no, r.requisition_date, s.sub_requisition_no,
                l.name AS location_name, l.code AS location_code,
                u.name AS user_name, u.employee_code,
                st.name AS store_action_by_name
         FROM requisition_items i
         JOIN requisition_subs s ON i.sub_requisition_id = s.id
         JOIN requisitions r ON s.requisition_id = r.id
         JOIN locations l ON s.location_id = l.id
         JOIN users u ON r.user_id = u.id
         LEFT JOIN users st ON i.store_action_by = st.id
         WHERE i.material_id = :id
         ORDER BY i.created_at DESC
         LIMIT 50",
        [':id' => $materialId]
    );

    // 5. Audit Log Events (Stock adjustments & master changes)
    $auditLogs = Database::query(
        "SELECT a.id, a.action, a.new_data, a.old_data, a.created_at, u.name AS actor_name
         FROM activity_logs a
         LEFT JOIN users u ON a.user_id = u.id
         WHERE a.entity_type = 'materials' AND a.entity_id = :id
         ORDER BY a.created_at DESC
         LIMIT 20",
        [':id' => (string) $materialId]
    );

    // 6. Available Categories
    $categories = Database::query("SELECT id, name FROM material_categories WHERE status = 'ACTIVE' ORDER BY name ASC");

    Response::success([
        'material'           => $material,
        'summary'            => $summary,
        'user_breakdown'     => $userBreakdown,
        'location_breakdown' => $locationBreakdown,
        'movement_log'       => $movementLog,
        'audit_logs'         => $auditLogs,
        'categories'         => $categories,
    ]);
});

Router::post('/api/store/materials/{id}/update-stock', function ($params) {
    $currentUser = Auth::requireRole(['SUPER_ADMIN', 'ADMIN', 'STORE_USER']);
    $materialId = (int) ($params['id'] ?? 0);

    $mat = Database::queryOne("SELECT * FROM materials WHERE id = :id", [':id' => $materialId]);
    if (!$mat) {
        Response::error('Material not found.', 'NOT_FOUND', 404);
    }

    $newStock = Request::input('current_stock');
    if ($newStock === null || !is_numeric($newStock)) {
        Response::error('Valid current stock value is required.', 'VALIDATION_ERROR', 422);
    }
    $newStock = (float) $newStock;
    if ($newStock < 0) {
        Response::error('Stock cannot be negative.', 'VALIDATION_ERROR', 422);
    }

    $reason = trim((string) Request::input('reason', 'Physical stock adjustment from Store Mobile App'));
    $name = Request::input('name') ? trim(Request::input('name')) : $mat['name'];
    $code = Request::input('code') ? trim(Request::input('code')) : $mat['code'];
    $unit = Request::input('unit') ? trim(Request::input('unit')) : $mat['unit'];
    $defaultRate = Request::input('default_rate') !== null ? (float) Request::input('default_rate') : (float) $mat['default_rate'];
    $categoryId = Request::input('category_id') !== null ? (int) Request::input('category_id') : $mat['category_id'];
    if ($categoryId === 0) $categoryId = null;

    $oldStock = (float) ($mat['current_stock'] ?? 0.0);
    $diff = $newStock - $oldStock;

    // Update material
    Database::execute(
        "UPDATE materials 
         SET current_stock = :stock,
             name = :name,
             code = :code,
             unit = :unit,
             default_rate = :rate,
             category_id = :cat_id,
             updated_at = NOW()
         WHERE id = :id",
        [
            ':stock'   => $newStock,
            ':name'    => $name,
            ':code'    => $code,
            ':unit'    => $unit,
            ':rate'    => $defaultRate,
            ':cat_id'  => $categoryId,
            ':id'      => $materialId
        ]
    );

    // Activity Audit Log
    Logger::logActivity(
        (int) $currentUser['id'],
        'PHYSICAL_STOCK_ADJUSTMENT',
        'materials',
        (string) $materialId,
        [
            'current_stock' => $oldStock,
            'name'          => $mat['name'],
            'default_rate'  => (float) $mat['default_rate']
        ],
        [
            'current_stock' => $newStock,
            'stock_diff'    => $diff,
            'reason'        => $reason,
            'name'          => $name,
            'default_rate'  => $defaultRate
        ]
    );

    Response::success([
        'id'            => $materialId,
        'name'          => $name,
        'code'          => $code,
        'current_stock' => $newStock,
        'old_stock'     => $oldStock,
        'diff'          => $diff,
        'unit'          => $unit,
        'default_rate'  => $defaultRate,
    ], 'Stock balance updated successfully!');
});

Router::get('/api/store/history', function () {
    Auth::requireRole(['SUPER_ADMIN', 'ADMIN', 'STORE_USER']);
    $dateFrom = Request::input('date_from', date('Y-m-d', strtotime('-7 days')));
    $dateTo = Request::input('date_to', date('Y-m-d'));
    $status = Request::input('status');
    $search = trim((string) Request::input('search', ''));
    $page = max(1, (int) Request::input('page', 1));
    $limit = min(1000, max(1, (int) Request::input('limit', 50)));
    $offset = ($page - 1) * $limit;

    $where = ["r.requisition_date BETWEEN :from AND :to", "i.store_action_at IS NOT NULL"];
    $params = [':from' => $dateFrom, ':to' => $dateTo];

    if (!empty($status) && $status !== 'ALL') {
        if ($status === 'PARTIAL_ISSUED' || $status === 'PARTIALLY_ISSUED') {
            $where[] = "i.status = 'PARTIALLY_ISSUED'";
        } else {
            $where[] = "i.status = :status";
            $params[':status'] = $status;
        }
    }

    if ($search !== '') {
        $where[] = "(u.name LIKE :s1 OR u.employee_code LIKE :s2 OR i.material_name_snapshot LIKE :s3 OR l.name LIKE :s4 OR s.sub_requisition_no LIKE :s5)";
        $searchWildcard = "%{$search}%";
        $params[':s1'] = $searchWildcard;
        $params[':s2'] = $searchWildcard;
        $params[':s3'] = $searchWildcard;
        $params[':s4'] = $searchWildcard;
        $params[':s5'] = $searchWildcard;
    }

    $whereSql = implode(' AND ', $where);

    $countSql = "SELECT COUNT(i.id) AS total_count
                 FROM requisition_items i
                 JOIN requisition_subs s ON i.sub_requisition_id = s.id
                 JOIN requisitions r ON s.requisition_id = r.id
                 JOIN users u ON r.user_id = u.id
                 JOIN locations l ON s.location_id = l.id
                 WHERE {$whereSql}";
    $countRow = Database::queryOne($countSql, $params);
    $totalCount = (int) ($countRow['total_count'] ?? 0);

    $sql = "SELECT i.id, i.sub_requisition_id, i.material_id, i.material_name_snapshot, i.unit_snapshot,
                   i.requested_quantity, i.issued_quantity, i.unit_rate, i.amount, i.remark, i.store_remark, i.status,
                   i.is_emergency, i.created_at, i.store_action_at,
                   m.code AS material_code, c.name AS material_category,
                   s.sub_requisition_no, s.location_id, l.name AS location_name, l.code AS location_code,
                   r.id AS master_requisition_id, r.requisition_no AS master_requisition_no, r.requisition_date,
                   u.id AS user_id, u.name AS user_name, u.employee_code, u.mobile AS user_mobile,
                   d.name AS department_name,
                   st.name AS store_action_by_name
            FROM requisition_items i
            JOIN requisition_subs s ON i.sub_requisition_id = s.id
            JOIN requisitions r ON s.requisition_id = r.id
            JOIN locations l ON s.location_id = l.id
            JOIN users u ON r.user_id = u.id
            LEFT JOIN departments d ON u.department_id = d.id
            LEFT JOIN materials m ON i.material_id = m.id
            LEFT JOIN material_categories c ON m.category_id = c.id
            LEFT JOIN users st ON i.store_action_by = st.id
            WHERE {$whereSql}
            ORDER BY i.store_action_at DESC
            LIMIT {$limit} OFFSET {$offset}";

    $items = Database::query($sql, $params);

    Response::success([
        'items'       => $items,
        'total_count' => $totalCount,
        'page'        => $page,
        'limit'       => $limit,
        'total_pages' => ceil($totalCount / $limit)
    ]);
});

// ------------------------------------------------------------
// 4. ADMIN & TALLY ENDPOINTS
// ------------------------------------------------------------
Router::get('/api/admin/dashboard', function () {
    Auth::requireRole(['SUPER_ADMIN', 'ADMIN']);
    $from = Request::input('date_from');
    $to = Request::input('date_to');
    $metrics = AdminService::getDashboardMetrics($from, $to);
    Response::success($metrics);
});

Router::post('/api/admin/date-override', function () {
    $admin = Auth::requireRole(['SUPER_ADMIN', 'ADMIN']);
    $overrideDate = Request::input('override_date');
    $reason = Request::input('reason');
    $hoursInput = Request::input('duration_hours');
    $hours = ($hoursInput !== null && $hoursInput !== '' && (int)$hoursInput > 0) ? (int)$hoursInput : (int)Config::get('ADMIN_OVERRIDE_HOURS', 2);

    if (empty($overrideDate) || empty($reason)) {
        Response::error('Date and reason are required.', 'VALIDATION_ERROR', 422);
    }

    try {
        $result = AdminService::createDateOverride((int) $admin['id'], $overrideDate, $reason, $hours);
        Response::success($result, "Date opened for Store editing for {$hours} hour(s).");
    } catch (Throwable $e) {
        Response::error($e->getMessage(), 'OVERRIDE_ERROR', 400);
    }
});

Router::get('/api/admin/date-overrides', function () {
    Auth::requireRole(['SUPER_ADMIN', 'ADMIN']);
    $overrides = AdminService::listDateOverrides(30);
    Response::success($overrides);
});

Router::post('/api/admin/date-overrides/{id}/close', function ($params) {
    $admin = Auth::requireRole(['SUPER_ADMIN', 'ADMIN']);
    $overrideId = (int) $params['id'];

    try {
        AdminService::closeDateOverride((int) $admin['id'], $overrideId);
        Response::success(null, 'Override closed successfully.');
    } catch (Throwable $e) {
        Response::error($e->getMessage(), 'CLOSE_ERROR', 400);
    }
});

Router::get('/api/admin/tally/preview', function () {
    Auth::requireRole(['SUPER_ADMIN', 'ADMIN', 'STORE_USER']);
    $from = Request::input('date_from', date('Y-m-d'));
    $to = Request::input('date_to', date('Y-m-d'));
    $userId = Request::input('user_id') ? (int) Request::input('user_id') : null;
    $locId = Request::input('location_id') ? (int) Request::input('location_id') : null;
    $status = Request::input('export_status', 'NOT_EXPORTED');

    $preview = TallyService::getExportPreview($from, $to, $userId, $locId, $status);
    Response::success($preview);
});

Router::post('/api/admin/tally/export', function () {
    $admin = Auth::requireRole(['SUPER_ADMIN', 'ADMIN', 'STORE_USER']);
    $from = Request::input('date_from', date('Y-m-d'));
    $to = Request::input('date_to', date('Y-m-d'));
    $subIds = Request::input('sub_requisition_ids', []);

    if (empty($subIds)) {
        Response::error('Please select at least one sub-requisition to export.', 'VALIDATION_ERROR', 422);
    }

    try {
        $result = TallyService::generateExport((int) $admin['id'], $from, $to, $subIds);
        Response::success($result, 'Tally export file generated successfully.');
    } catch (Throwable $e) {
        Response::error($e->getMessage(), 'EXPORT_ERROR', 400);
    }
});

Router::get('/api/admin/timing-status', function () {
    $date = Request::input('date', date('Y-m-d'));
    $timing = TimeService::getTimingStatus($date);
    $timing['is_user_window_open'] = $timing['user_window']['is_open'] ?? false;
    $timing['is_store_edit_allowed'] = $timing['store_window']['is_open'] ?? false;
    Response::success($timing);
});

// ------------------------------------------------------------
// 5. ADMIN MOBILE APP EXTENDED ENDPOINTS
// ------------------------------------------------------------
Router::get('/api/admin/requisitions', function () {
    Auth::requireRole(['SUPER_ADMIN', 'ADMIN']);
    $from = Request::input('date_from');
    $to = Request::input('date_to');
    $status = Request::input('status');
    $locId = Request::input('location_id') ? (int) Request::input('location_id') : null;
    $search = trim((string) Request::input('search', ''));
    $page = max(1, (int) Request::input('page', 1));
    $limit = min(100, max(10, (int) Request::input('limit', 30)));
    $offset = ($page - 1) * $limit;

    $where = ["1=1"];
    $params = [];

    if (!empty($from) && !empty($to)) {
        if ($from === $to) {
            $where[] = "r.requisition_date = :d_from";
            $params[':d_from'] = $from;
        } else {
            $where[] = "r.requisition_date BETWEEN :d_from AND :d_to";
            $params[':d_from'] = $from;
            $params[':d_to'] = $to;
        }
    } elseif (!empty($from)) {
        $where[] = "r.requisition_date >= :d_from";
        $params[':d_from'] = $from;
    }

    if (!empty($status) && $status !== 'ALL') {
        $where[] = "r.status = :status";
        $params[':status'] = $status;
    }

    if ($locId) {
        $where[] = "EXISTS (SELECT 1 FROM requisition_subs sub_loc WHERE sub_loc.requisition_id = r.id AND sub_loc.location_id = :loc_id)";
        $params[':loc_id'] = $locId;
    }

    if ($search !== '') {
        $where[] = "(r.requisition_no LIKE :s1 OR u.name LIKE :s2 OR u.employee_code LIKE :s3)";
        $params[':s1'] = "%{$search}%";
        $params[':s2'] = "%{$search}%";
        $params[':s3'] = "%{$search}%";
    }

    $whereSql = implode(" AND ", $where);

    $countRow = Database::queryOne("SELECT COUNT(*) AS total 
                                    FROM requisitions r 
                                    JOIN users u ON r.user_id = u.id 
                                    WHERE {$whereSql}", $params);
    $totalCount = (int) ($countRow['total'] ?? 0);

    $sql = "SELECT r.id, r.requisition_no AS requisition_number, r.requisition_date, r.status, '' AS notes, r.created_at,
                   u.name AS user_name, u.employee_code, u.mobile,
                   (SELECT COUNT(*) FROM requisition_subs WHERE requisition_id = r.id) AS total_subs,
                   (SELECT COUNT(*) FROM requisition_items ri JOIN requisition_subs rs ON ri.sub_requisition_id = rs.id WHERE rs.requisition_id = r.id) AS total_items,
                   (SELECT COALESCE(SUM(ri.amount), 0) FROM requisition_items ri JOIN requisition_subs rs ON ri.sub_requisition_id = rs.id WHERE rs.requisition_id = r.id) AS total_issued_amount
            FROM requisitions r
            JOIN users u ON r.user_id = u.id
            WHERE {$whereSql}
            ORDER BY r.requisition_date DESC, r.id DESC
            LIMIT {$limit} OFFSET {$offset}";

    $rows = Database::query($sql, $params);

    Response::success([
        'requisitions' => $rows,
        'page'         => $page,
        'limit'        => $limit,
        'total'        => $totalCount,
        'total_pages'  => ceil($totalCount / $limit)
    ]);
});

Router::get('/api/admin/requisitions/{id}', function ($params) {
    Auth::requireRole(['SUPER_ADMIN', 'ADMIN']);
    $reqId = (int) $params['id'];

    $req = Database::queryOne("SELECT r.id, r.requisition_no AS requisition_number, r.requisition_date, r.status, '' AS notes, r.created_at,
                                      u.name AS user_name, u.employee_code, u.mobile, u.email
                               FROM requisitions r
                               JOIN users u ON r.user_id = u.id
                               WHERE r.id = :id", [':id' => $reqId]);
    if (!$req) {
        Response::error('Requisition not found.', 'NOT_FOUND', 404);
    }

    $subs = Database::query("SELECT s.id, s.sub_requisition_no AS sub_requisition_number, s.location_id, s.status, s.tally_export_status,
                                    l.name AS location_name, l.code AS location_code
                             FROM requisition_subs s
                             JOIN locations l ON s.location_id = l.id
                             WHERE s.requisition_id = :id
                             ORDER BY l.name ASC", [':id' => $reqId]);

    $subList = [];
    $grandTotalItems = 0;
    $grandTotalAmount = 0.0;

    foreach ($subs as $sub) {
        $subId = (int) $sub['id'];
        $items = Database::query("SELECT i.id, i.material_id, i.material_name_snapshot AS material_name, i.unit_snapshot AS unit,
                                         i.requested_quantity, i.issued_quantity, i.unit_rate AS rate, i.amount, i.remark, i.store_remark,
                                         i.status, i.is_emergency, i.store_action_at,
                                         m.code AS material_code,
                                         su.name AS store_user_name
                                  FROM requisition_items i
                                  LEFT JOIN materials m ON i.material_id = m.id
                                  LEFT JOIN users su ON i.store_action_by = su.id
                                  WHERE i.sub_requisition_id = :sub_id
                                  ORDER BY i.id ASC", [':sub_id' => $subId]);

        $subTotalAmount = 0.0;
        foreach ($items as &$it) {
            $issued = (float) ($it['issued_quantity'] ?? 0);
            $rate = (float) ($it['rate'] ?? 0);
            $amount = (float) ($it['amount'] ?? 0);
            if ($amount <= 0 && $issued > 0 && $rate > 0) {
                $amount = round($issued * $rate, 2);
            }
            $it['amount'] = $amount;
            $subTotalAmount += $amount;
            $grandTotalAmount += $amount;
            $grandTotalItems++;
        }

        $sub['total_amount'] = $subTotalAmount;
        $sub['items'] = $items;
        $subList[] = $sub;
    }

    $req['total_items'] = $grandTotalItems;
    $req['total_amount'] = $grandTotalAmount;
    $req['sub_requisitions'] = $subList;

    Response::success($req);
});

Router::get('/api/admin/users', function () {
    Auth::requireRole(['SUPER_ADMIN', 'ADMIN']);
    $search = trim((string) Request::input('search', ''));
    $role = Request::input('role');
    $status = Request::input('status');

    $where = ["1=1"];
    $params = [];

    if ($search !== '') {
        $where[] = "(u.name LIKE :s1 OR u.employee_code LIKE :s2 OR u.mobile LIKE :s3 OR u.email LIKE :s4)";
        $params[':s1'] = "%{$search}%";
        $params[':s2'] = "%{$search}%";
        $params[':s3'] = "%{$search}%";
        $params[':s4'] = "%{$search}%";
    }

    if (!empty($role) && $role !== 'ALL') {
        $where[] = "u.role = :role";
        $params[':role'] = $role;
    }

    if (!empty($status) && $status !== 'ALL') {
        $where[] = "u.status = :status";
        $params[':status'] = $status;
    }

    $whereSql = implode(" AND ", $where);
    $users = Database::query("SELECT u.id, u.employee_code, u.name, u.mobile, u.email, u.role, u.status, u.created_at,
                                     d.name AS department_name
                              FROM users u
                              LEFT JOIN departments d ON u.department_id = d.id
                              WHERE {$whereSql}
                              ORDER BY u.name ASC", $params);

    $departments = Database::query("SELECT id, name FROM departments WHERE status = 'ACTIVE' ORDER BY name ASC");
    Response::success(['users' => $users, 'departments' => $departments]);
});

Router::post('/api/admin/users', function () {
    $admin = Auth::requireRole(['SUPER_ADMIN', 'ADMIN']);
    $id = Request::input('id') ? (int) Request::input('id') : null;
    $data = [
        'name'          => Request::input('name'),
        'employee_code' => Request::input('employee_code'),
        'mobile'        => Request::input('mobile'),
        'email'         => Request::input('email'),
        'role'          => Request::input('role', 'USER'),
        'department_id' => Request::input('department_id'),
        'password'      => Request::input('password'),
        'status'        => Request::input('status', 'ACTIVE')
    ];

    if (empty($data['name']) || empty($data['employee_code'])) {
        Response::error('Name and Employee Code are required.', 'VALIDATION_ERROR', 422);
    }

    try {
        $userId = AdminService::saveUser($data, $id, (int) $admin['id']);
        Response::success(['id' => $userId], $id ? 'User updated successfully.' : 'User created successfully.');
    } catch (Throwable $e) {
        Response::error($e->getMessage(), 'SAVE_ERROR', 400);
    }
});

Router::post('/api/admin/users/{id}/toggle-status', function ($params) {
    $admin = Auth::requireRole(['SUPER_ADMIN', 'ADMIN']);
    $userId = (int) $params['id'];
    try {
        $newStatus = AdminService::toggleUserStatus($userId, (int) $admin['id']);
        Response::success(['status' => $newStatus], "User marked as {$newStatus}.");
    } catch (Throwable $e) {
        Response::error($e->getMessage(), 'STATUS_ERROR', 400);
    }
});

Router::post('/api/admin/users/{id}/reset-password', function ($params) {
    $admin = Auth::requireRole(['SUPER_ADMIN', 'ADMIN']);
    $userId = (int) $params['id'];
    $newPassword = Request::input('new_password');

    if (empty($newPassword) || strlen($newPassword) < 4) {
        Response::error('Password must be at least 4 characters.', 'VALIDATION_ERROR', 422);
    }

    $hash = password_hash($newPassword, PASSWORD_BCRYPT);
    Database::execute("UPDATE users SET password_hash = :hash, updated_at = NOW() WHERE id = :id", [
        ':hash' => $hash,
        ':id'   => $userId
    ]);

    Logger::logActivity((int) $admin['id'], 'USER_PASSWORD_RESET_BY_ADMIN', 'users', (string) $userId);
    Response::success(null, 'User password reset successfully.');
});

Router::get('/api/admin/locations', function () {
    Auth::requireRole(['SUPER_ADMIN', 'ADMIN']);
    $locations = Database::query("SELECT id, name, code, tally_ledger_name, tally_ledger_code, status, created_at 
                                  FROM locations 
                                  ORDER BY name ASC");
    Response::success($locations);
});

Router::post('/api/admin/locations', function () {
    $admin = Auth::requireRole(['SUPER_ADMIN', 'ADMIN']);
    $id = Request::input('id') ? (int) Request::input('id') : null;
    $data = [
        'name'              => Request::input('name'),
        'code'              => Request::input('code'),
        'tally_ledger_name' => Request::input('tally_ledger_name'),
        'tally_ledger_code' => Request::input('tally_ledger_code'),
        'status'            => Request::input('status', 'ACTIVE')
    ];

    if (empty($data['name']) || empty($data['code'])) {
        Response::error('Location Name and Code are required.', 'VALIDATION_ERROR', 422);
    }

    try {
        $locId = AdminService::saveLocation($data, $id, (int) $admin['id']);
        Response::success(['id' => $locId], $id ? 'Location updated successfully.' : 'Location created successfully.');
    } catch (Throwable $e) {
        Response::error($e->getMessage(), 'SAVE_ERROR', 400);
    }
});

Router::post('/api/admin/locations/{id}/toggle-status', function ($params) {
    $admin = Auth::requireRole(['SUPER_ADMIN', 'ADMIN']);
    $locId = (int) $params['id'];
    try {
        $newStatus = AdminService::toggleLocationStatus($locId, (int) $admin['id']);
        Response::success(['status' => $newStatus], "Location marked as {$newStatus}.");
    } catch (Throwable $e) {
        Response::error($e->getMessage(), 'STATUS_ERROR', 400);
    }
});

Router::get('/api/admin/materials', function () {
    Auth::requireRole(['SUPER_ADMIN', 'ADMIN', 'STORE_USER']);
    $search = trim((string) Request::input('search', ''));
    $status = Request::input('status');

    $where = ["1=1"];
    $params = [];

    if ($search !== '') {
        $where[] = "(m.name LIKE :s1 OR m.code LIKE :s2 OR m.tally_item_name LIKE :s3)";
        $params[':s1'] = "%{$search}%";
        $params[':s2'] = "%{$search}%";
        $params[':s3'] = "%{$search}%";
    }

    if (!empty($status) && $status !== 'ALL') {
        $where[] = "m.status = :status";
        $params[':status'] = $status;
    }

    $whereSql = implode(" AND ", $where);
    $materials = Database::query("SELECT m.id, m.name, m.code, m.unit, m.default_rate, m.current_stock,
                                         m.tally_item_name, m.tally_item_code, m.status, m.created_at,
                                         c.name AS category_name
                                  FROM materials m
                                  LEFT JOIN material_categories c ON m.category_id = c.id
                                  WHERE {$whereSql}
                                  ORDER BY m.name ASC", $params);

    Response::success($materials);
});

Router::post('/api/admin/materials', function () {
    $admin = Auth::requireRole(['SUPER_ADMIN', 'ADMIN']);
    $id = Request::input('id') ? (int) Request::input('id') : null;
    $data = [
        'name'            => Request::input('name'),
        'code'            => Request::input('code'),
        'category_id'     => Request::input('category_id'),
        'unit'            => Request::input('unit', 'NOS'),
        'default_rate'    => (float) Request::input('default_rate', 0.0),
        'current_stock'   => (float) Request::input('current_stock', 0.0),
        'tally_item_name' => Request::input('tally_item_name'),
        'tally_item_code' => Request::input('tally_item_code'),
        'status'          => Request::input('status', 'ACTIVE')
    ];

    if (empty($data['name'])) {
        Response::error('Material name is required.', 'VALIDATION_ERROR', 422);
    }

    try {
        $matId = AdminService::saveMaterial($data, $id, (int) $admin['id']);
        Response::success(['id' => $matId], $id ? 'Material updated successfully.' : 'Material created successfully.');
    } catch (Throwable $e) {
        Response::error($e->getMessage(), 'SAVE_ERROR', 400);
    }
});

Router::post('/api/admin/materials/{id}/toggle-status', function ($params) {
    $admin = Auth::requireRole(['SUPER_ADMIN', 'ADMIN']);
    $matId = (int) $params['id'];
    try {
        $newStatus = AdminService::toggleMaterialStatus($matId, (int) $admin['id']);
        Response::success(['status' => $newStatus], "Material marked as {$newStatus}.");
    } catch (Throwable $e) {
        Response::error($e->getMessage(), 'STATUS_ERROR', 400);
    }
});

Router::post('/api/admin/materials/{id}/quick-stock', function ($params) {
    $admin = Auth::requireRole(['SUPER_ADMIN', 'ADMIN', 'STORE_USER']);
    $matId = (int) $params['id'];
    $newStock = Request::input('current_stock');
    $remark = trim((string) Request::input('remark', 'Stock adjusted via Mobile App'));

    if ($newStock === null || $newStock === '') {
        Response::error('Stock balance is required.', 'VALIDATION_ERROR', 422);
    }

    $newStockVal = (float) $newStock;
    if ($newStockVal < 0) {
        Response::error('Stock cannot be negative.', 'VALIDATION_ERROR', 422);
    }

    $oldMat = Database::queryOne("SELECT id, name, current_stock, unit FROM materials WHERE id = :id", [':id' => $matId]);
    if (!$oldMat) {
        Response::error('Material not found.', 'NOT_FOUND', 404);
    }

    Database::execute("UPDATE materials SET current_stock = :stock, updated_at = NOW() WHERE id = :id", [
        ':stock' => $newStockVal,
        ':id'    => $matId
    ]);

    Logger::logActivity((int) $admin['id'], 'STOCK_BALANCE_ADJUSTED', 'materials', (string) $matId, [
        'old_stock' => $oldMat['current_stock'],
        'new_stock' => $newStockVal,
        'remark'    => $remark
    ]);

    Response::success([
        'id'            => $matId,
        'current_stock' => $newStockVal,
        'unit'          => $oldMat['unit']
    ], "Stock balance updated to {$newStockVal} {$oldMat['unit']}.");
});

Router::get('/api/admin/settings', function () {
    Auth::requireRole(['SUPER_ADMIN', 'ADMIN']);
    $rows = Database::query("SELECT `key`, `value`, `description` FROM settings ORDER BY `key` ASC");
    $settingsMap = [];
    foreach ($rows as $r) {
        $settingsMap[$r['key']] = [
            'value'       => $r['value'],
            'description' => $r['description']
        ];
    }
    Response::success($settingsMap);
});

Router::post('/api/admin/settings', function () {
    $admin = Auth::requireRole(['SUPER_ADMIN', 'ADMIN']);
    $settings = Request::input('settings', []);

    if (!is_array($settings)) {
        Response::error('Settings data format invalid.', 'VALIDATION_ERROR', 422);
    }

    foreach ($settings as $key => $val) {
        $cleanKey = trim((string) $key);
        $cleanVal = trim((string) $val);
        if ($cleanKey !== '') {
            Database::execute("INSERT INTO settings (`key`, `value`, `updated_at`) 
                               VALUES (:k, :v, NOW()) 
                               ON DUPLICATE KEY UPDATE `value` = :v2, `updated_at` = NOW()", [
                ':k'  => $cleanKey,
                ':v'  => $cleanVal,
                ':v2' => $cleanVal
            ]);
        }
    }

    Config::reload();
    Logger::logActivity((int) $admin['id'], 'SETTINGS_UPDATED_BY_APP', 'settings', null, null, $settings);

    Response::success(null, 'Settings updated and reloaded successfully.');
});

Router::get('/api/admin/activity-logs', function () {
    Auth::requireRole(['SUPER_ADMIN', 'ADMIN']);
    $search = trim((string) Request::input('search', ''));
    $page = max(1, (int) Request::input('page', 1));
    $limit = min(100, max(10, (int) Request::input('limit', 50)));
    $offset = ($page - 1) * $limit;

    $where = ["1=1"];
    $params = [];

    if ($search !== '') {
        $where[] = "(l.action LIKE :s1 OR u.name LIKE :s2 OR l.entity_type LIKE :s3)";
        $params[':s1'] = "%{$search}%";
        $params[':s2'] = "%{$search}%";
        $params[':s3'] = "%{$search}%";
    }

    $whereSql = implode(" AND ", $where);
    $logs = Database::query("SELECT l.id, l.action, l.entity_type, l.entity_id, l.new_data AS new_values, l.ip_address, l.created_at,
                                    u.name AS user_name, u.role AS user_role
                             FROM activity_logs l
                             LEFT JOIN users u ON l.user_id = u.id
                             WHERE {$whereSql}
                             ORDER BY l.id DESC
                             LIMIT {$limit} OFFSET {$offset}", $params);

    Response::success($logs);
});

function handleReportAggregation() {
    try {
        $from = Request::input('date_from', date('Y-m-01'));
        $to = Request::input('date_to', date('Y-m-d'));
        $userId = Request::input('user_id') ? (int) Request::input('user_id') : null;
        $locId = Request::input('location_id') ? (int) Request::input('location_id') : null;
        $matId = Request::input('material_id') ? (int) Request::input('material_id') : null;
        $status = Request::input('status');

        $where = ["1=1"];
        $params = [];

        if (!empty($from) && !empty($to)) {
            if ($from === $to) {
                $where[] = "r.requisition_date = :d_from";
                $params[':d_from'] = $from;
            } else {
                $where[] = "r.requisition_date BETWEEN :d_from AND :d_to";
                $params[':d_from'] = $from;
                $params[':d_to'] = $to;
            }
        } elseif (!empty($from)) {
            $where[] = "r.requisition_date >= :d_from";
            $params[':d_from'] = $from;
        }

        if ($userId) {
            $where[] = "r.user_id = :uid";
            $params[':uid'] = $userId;
        }

        if ($locId) {
            $where[] = "rs.location_id = :lid";
            $params[':lid'] = $locId;
        }

        if ($matId) {
            $where[] = "ri.material_id = :mid";
            $params[':mid'] = $matId;
        }

        if (!empty($status) && $status !== 'ALL') {
            $where[] = "ri.status = :status";
            $params[':status'] = $status;
        }

        $whereSql = implode(" AND ", $where);

        // 1. Raw Detailed Transaction Records (Single robust query without GROUP BY conflicts)
        $rawSql = "SELECT ri.id AS item_id, ri.material_id, ri.material_name_snapshot AS material_name, ri.unit_snapshot AS unit,
                          ri.requested_quantity, ri.issued_quantity, ri.unit_rate AS rate, ri.amount, ri.remark, ri.store_remark,
                          ri.status, ri.is_emergency, ri.created_at AS item_created_at,
                          rs.id AS sub_requisition_id, rs.sub_requisition_no, rs.location_id, rs.tally_export_status,
                          r.id AS requisition_id, r.requisition_no AS requisition_number, r.requisition_date, r.user_id,
                          u.name AS user_name, u.employee_code, u.mobile,
                          COALESCE(d.name, 'General') AS department_name,
                          l.name AS location_name, l.code AS location_code,
                          COALESCE(m.code, '') AS material_code
                   FROM requisition_items ri
                   JOIN requisition_subs rs ON ri.sub_requisition_id = rs.id
                   JOIN requisitions r ON rs.requisition_id = r.id
                   JOIN users u ON r.user_id = u.id
                   JOIN locations l ON rs.location_id = l.id
                   LEFT JOIN materials m ON ri.material_id = m.id
                   LEFT JOIN departments d ON u.department_id = d.id
                   WHERE {$whereSql}
                   ORDER BY r.requisition_date DESC, r.id DESC, rs.id ASC, ri.id ASC";

        $rawRecords = Database::query($rawSql, $params);

        // Aggregation Containers
        $totalRequisitions = [];
        $totalItemsCount = 0;
        $totalRequestedQty = 0.0;
        $totalIssuedQty = 0.0;
        $totalValuation = 0.0;

        $locMap = [];
        $itemMap = [];
        $userMap = [];
        $deptMap = [];
        $catMap = [];
        $trendMap = [];

        $emergencyRecords = [];
        $stockoutRecords = [];
        $partialRecords = [];
        $statusCounts = [
            'ISSUED' => 0,
            'PARTIALLY_ISSUED' => 0,
            'NOT_AVAILABLE' => 0,
            'PENDING' => 0,
            'EMERGENCY' => 0,
        ];

        foreach ($rawRecords as &$row) {
            $reqId = (int) ($row['requisition_id'] ?? 0);
            $subId = (int) ($row['sub_requisition_id'] ?? 0);
            $totalRequisitions[$reqId] = true;
            $totalItemsCount++;

            $reqQty = (float) ($row['requested_quantity'] ?? 0);
            $issQty = (float) ($row['issued_quantity'] ?? 0);
            $rate = (float) ($row['rate'] ?? 0);
            $amount = (float) ($row['amount'] ?? 0);

            if ($amount <= 0 && $issQty > 0 && $rate > 0) {
                $amount = round($issQty * $rate, 2);
                $row['amount'] = $amount;
            }

            $totalRequestedQty += $reqQty;
            $totalIssuedQty += $issQty;
            $totalValuation += $amount;

            $st = $row['status'] ?? 'PENDING';
            if (isset($statusCounts[$st])) {
                $statusCounts[$st]++;
            }
            if (!empty($row['is_emergency'])) {
                $statusCounts['EMERGENCY']++;
                $emergencyRecords[] = $row;
            }
            if ($st === 'NOT_AVAILABLE') {
                $stockoutRecords[] = $row;
            } elseif ($st === 'PARTIALLY_ISSUED') {
                $partialRecords[] = $row;
            }

            // Group by Location
            $locIdKey = (int) ($row['location_id'] ?? 0);
            if (!isset($locMap[$locIdKey])) {
                $locMap[$locIdKey] = [
                    'location_id' => $locIdKey,
                    'location_name' => $row['location_name'] ?? 'Unknown Location',
                    'location_code' => $row['location_code'] ?? '',
                    'req_set' => [],
                    'sub_set' => [],
                    'total_items' => 0,
                    'total_requested_qty' => 0.0,
                    'total_issued_qty' => 0.0,
                    'total_issued_value' => 0.0,
                ];
            }
            $locMap[$locIdKey]['req_set'][$reqId] = true;
            $locMap[$locIdKey]['sub_set'][$subId] = true;
            $locMap[$locIdKey]['total_items']++;
            $locMap[$locIdKey]['total_requested_qty'] += $reqQty;
            $locMap[$locIdKey]['total_issued_qty'] += $issQty;
            $locMap[$locIdKey]['total_issued_value'] += $amount;

            // Group by Item
            $itemName = trim($row['material_name'] ?? 'Unknown Item');
            $unit = trim($row['unit'] ?? '');
            $itemKey = $itemName . '__' . $unit;
            if (!isset($itemMap[$itemKey])) {
                $itemMap[$itemKey] = [
                    'material_id' => (int) ($row['material_id'] ?? 0),
                    'item_name' => $itemName,
                    'item_code' => $row['material_code'] ?? '',
                    'unit' => $unit,
                    'default_rate' => $rate,
                    'total_requests' => 0,
                    'total_requested_qty' => 0.0,
                    'total_issued_qty' => 0.0,
                    'total_issued_value' => 0.0,
                ];
            }
            $itemMap[$itemKey]['total_requests']++;
            $itemMap[$itemKey]['total_requested_qty'] += $reqQty;
            $itemMap[$itemKey]['total_issued_qty'] += $issQty;
            $itemMap[$itemKey]['total_issued_value'] += $amount;

            // Group by User
            $uIdKey = (int) ($row['user_id'] ?? 0);
            if (!isset($userMap[$uIdKey])) {
                $userMap[$uIdKey] = [
                    'user_id' => $uIdKey,
                    'user_name' => $row['user_name'] ?? 'Unknown User',
                    'employee_code' => $row['employee_code'] ?? '',
                    'mobile' => $row['mobile'] ?? '',
                    'department_name' => $row['department_name'] ?? 'General',
                    'req_set' => [],
                    'total_items' => 0,
                    'total_requested_qty' => 0.0,
                    'total_issued_qty' => 0.0,
                    'total_issued_value' => 0.0,
                ];
            }
            $userMap[$uIdKey]['req_set'][$reqId] = true;
            $userMap[$uIdKey]['total_items']++;
            $userMap[$uIdKey]['total_requested_qty'] += $reqQty;
            $userMap[$uIdKey]['total_issued_qty'] += $issQty;
            $userMap[$uIdKey]['total_issued_value'] += $amount;

            // Group by Department
            $deptName = trim($row['department_name'] ?? 'General / Unassigned');
            if (!isset($deptMap[$deptName])) {
                $deptMap[$deptName] = [
                    'department_id' => 0,
                    'department_name' => $deptName,
                    'req_set' => [],
                    'total_items' => 0,
                    'total_requested_qty' => 0.0,
                    'total_issued_qty' => 0.0,
                    'total_issued_value' => 0.0,
                ];
            }
            $deptMap[$deptName]['req_set'][$reqId] = true;
            $deptMap[$deptName]['total_items']++;
            $deptMap[$deptName]['total_requested_qty'] += $reqQty;
            $deptMap[$deptName]['total_issued_qty'] += $issQty;
            $deptMap[$deptName]['total_issued_value'] += $amount;

            // Group by Category
            $catName = !empty($row['department_name']) ? $row['department_name'] : 'General Store';
            if (!isset($catMap[$catName])) {
                $catMap[$catName] = [
                    'category_id' => 0,
                    'category_name' => $catName,
                    'total_items' => 0,
                    'total_requested_qty' => 0.0,
                    'total_issued_qty' => 0.0,
                    'total_issued_value' => 0.0,
                ];
            }
            $catMap[$catName]['total_items']++;
            $catMap[$catName]['total_requested_qty'] += $reqQty;
            $catMap[$catName]['total_issued_qty'] += $issQty;
            $catMap[$catName]['total_issued_value'] += $amount;

            // Group by Daily Trend
            $dateLabel = $row['requisition_date'] ?? date('Y-m-d');
            if (!isset($trendMap[$dateLabel])) {
                $trendMap[$dateLabel] = [
                    'date_label' => $dateLabel,
                    'req_set' => [],
                    'items_count' => 0,
                    'requested_qty' => 0.0,
                    'issued_qty' => 0.0,
                    'valuation' => 0.0,
                ];
            }
            $trendMap[$dateLabel]['req_set'][$reqId] = true;
            $trendMap[$dateLabel]['items_count']++;
            $trendMap[$dateLabel]['requested_qty'] += $reqQty;
            $trendMap[$dateLabel]['issued_qty'] += $issQty;
            $trendMap[$dateLabel]['valuation'] += $amount;
        }

        // Finalize lists
        $locConsumption = array_values(array_map(function ($l) {
            return [
                'location_id' => $l['location_id'],
                'location_name' => $l['location_name'],
                'location_code' => $l['location_code'],
                'total_requisitions' => count($l['req_set']),
                'total_sub_requisitions' => count($l['sub_set']),
                'total_items' => $l['total_items'],
                'total_requested_qty' => round($l['total_requested_qty'], 2),
                'total_issued_qty' => round($l['total_issued_qty'], 2),
                'total_issued_value' => round($l['total_issued_value'], 2),
            ];
        }, $locMap));
        usort($locConsumption, fn($a, $b) => $b['total_issued_value'] <=> $a['total_issued_value']);

        $itemConsumption = array_values(array_map(function ($i) {
            return [
                'material_id' => $i['material_id'],
                'item_name' => $i['item_name'],
                'item_code' => $i['item_code'],
                'unit' => $i['unit'],
                'default_rate' => $i['default_rate'],
                'total_requests' => $i['total_requests'],
                'total_requested_qty' => round($i['total_requested_qty'], 2),
                'total_issued_qty' => round($i['total_issued_qty'], 2),
                'total_issued_value' => round($i['total_issued_value'], 2),
            ];
        }, $itemMap));
        usort($itemConsumption, fn($a, $b) => $b['total_issued_value'] <=> $a['total_issued_value']);

        $userConsumption = array_values(array_map(function ($u) {
            return [
                'user_id' => $u['user_id'],
                'user_name' => $u['user_name'],
                'employee_code' => $u['employee_code'],
                'mobile' => $u['mobile'],
                'department_name' => $u['department_name'],
                'total_requisitions' => count($u['req_set']),
                'total_items' => $u['total_items'],
                'total_requested_qty' => round($u['total_requested_qty'], 2),
                'total_issued_qty' => round($u['total_issued_qty'], 2),
                'total_issued_value' => round($u['total_issued_value'], 2),
            ];
        }, $userMap));
        usort($userConsumption, fn($a, $b) => $b['total_issued_value'] <=> $a['total_issued_value']);

        $deptConsumption = array_values(array_map(function ($d) {
            return [
                'department_id' => $d['department_id'],
                'department_name' => $d['department_name'],
                'total_requisitions' => count($d['req_set']),
                'total_items' => $d['total_items'],
                'total_requested_qty' => round($d['total_requested_qty'], 2),
                'total_issued_qty' => round($d['total_issued_qty'], 2),
                'total_issued_value' => round($d['total_issued_value'], 2),
            ];
        }, $deptMap));
        usort($deptConsumption, fn($a, $b) => $b['total_issued_value'] <=> $a['total_issued_value']);

        $catConsumption = array_values(array_map(function ($c) {
            return [
                'category_id' => $c['category_id'],
                'category_name' => $c['category_name'],
                'total_items' => $c['total_items'],
                'total_requested_qty' => round($c['total_requested_qty'], 2),
                'total_issued_qty' => round($c['total_issued_qty'], 2),
                'total_issued_value' => round($c['total_issued_value'], 2),
            ];
        }, $catMap));
        usort($catConsumption, fn($a, $b) => $b['total_issued_value'] <=> $a['total_issued_value']);

        ksort($trendMap);
        $dailyTrends = array_values(array_map(function ($t) {
            return [
                'date_label' => $t['date_label'],
                'requisitions_count' => count($t['req_set']),
                'items_count' => $t['items_count'],
                'requested_qty' => round($t['requested_qty'], 2),
                'issued_qty' => round($t['issued_qty'], 2),
                'valuation' => round($t['valuation'], 2),
            ];
        }, $trendMap));

        Response::success([
            'date_from'             => $from,
            'date_to'               => $to,
            'summary'               => [
                'total_requisitions'  => count($totalRequisitions),
                'total_items_count'   => $totalItemsCount,
                'total_requested_qty' => round($totalRequestedQty, 2),
                'total_issued_qty'    => round($totalIssuedQty, 2),
                'total_valuation'     => round($totalValuation, 2),
                'status_counts'       => $statusCounts,
                'fulfillment_rate'    => $totalRequestedQty > 0 ? round(($totalIssuedQty / $totalRequestedQty) * 100, 1) : 0,
            ],
            'loc_consumption'       => $locConsumption,
            'item_consumption'      => $itemConsumption,
            'user_consumption'      => $userConsumption,
            'dept_consumption'      => $deptConsumption,
            'cat_consumption'       => $catConsumption,
            'daily_trends'          => $dailyTrends,
            'emergency_records'     => $emergencyRecords,
            'stockout_records'      => $stockoutRecords,
            'partial_records'       => $partialRecords,
            'raw_records'           => $rawRecords
        ]);
    } catch (Throwable $e) {
        Logger::logError('handleReportAggregation Exception', $e);
        Response::error('Failed to generate report: ' . $e->getMessage(), 'REPORT_ERROR', 500);
    }
}

Router::get('/api/ceo/reports', function () {
    handleReportAggregation();
});

Router::get('/api/ceo/masters', function () {
    $users = Database::query("SELECT id, name, employee_code, role FROM users WHERE status = 'ACTIVE' ORDER BY name ASC");
    $locations = Database::query("SELECT id, name, code FROM locations WHERE status = 'ACTIVE' ORDER BY name ASC");
    $materials = Database::query("SELECT id, name, code, unit FROM materials WHERE status = 'ACTIVE' ORDER BY name ASC");

    Response::success([
        'users' => $users,
        'locations' => $locations,
        'materials' => $materials,
    ]);
});

Router::get('/api/admin/reports', function () {
    handleReportAggregation();
});

// Dispatch the API request
Router::dispatch();

