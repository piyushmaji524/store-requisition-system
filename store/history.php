<?php
/**
 * STORE PANEL - ISSUE HISTORY
 * Historical view of all fulfilled store items and actions
 */

require_once __DIR__ . '/../config/config.php';
require_once __DIR__ . '/../core/Database.php';
require_once __DIR__ . '/../core/Session.php';
require_once __DIR__ . '/../core/Auth.php';

Session::start();
if (!Session::get('user_id')) {
    header('Location: /store/login.php');
    exit;
}

$currentUser = Auth::user();
if (!$currentUser || !in_array($currentUser['role'], ['STORE_USER', 'SUPER_ADMIN', 'ADMIN'])) {
    Auth::logoutWeb();
    header('Location: /store/login.php');
    exit;
}

$dateFrom = $_GET['date_from'] ?? date('Y-m-d', strtotime('-7 days'));
$dateTo = $_GET['date_to'] ?? date('Y-m-d');
$status = $_GET['status'] ?? '';

$where = ["r.requisition_date BETWEEN :from AND :to", "i.store_action_at IS NOT NULL"];
$params = [':from' => $dateFrom, ':to' => $dateTo];

if (!empty($status)) {
    $where[] = "i.status = :status";
    $params[':status'] = $status;
}

$whereSql = implode(' AND ', $where);

$sql = "SELECT i.*, r.requisition_no, r.requisition_date, u.name AS user_name,
               s.sub_requisition_no, l.name AS location_name,
               st.name AS store_action_by_name
        FROM requisition_items i
        JOIN requisition_subs s ON i.sub_requisition_id = s.id
        JOIN requisitions r ON s.requisition_id = r.id
        JOIN users u ON r.user_id = u.id
        JOIN locations l ON s.location_id = l.id
        LEFT JOIN users st ON i.store_action_by = st.id
        WHERE {$whereSql}
        ORDER BY i.store_action_at DESC
        LIMIT 100";

$historyItems = Database::query($sql, $params);
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Issue History - <?= htmlspecialchars(Config::get('APP_NAME')) ?></title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="/assets/css/store.css">
</head>
<body>
<div class="app-container">
    <!-- Sidebar -->
    <?php require __DIR__ . '/includes/sidebar.php'; ?>

    <div class="main-wrapper">
        <header class="top-navbar">
            <div class="nav-left">
                <button class="menu-toggle" aria-label="Toggle Menu">☰</button>
                <div class="nav-center-badges">
                    <div class="header-badge">
                        <span class="badge-dot"></span>
                        Store Window: <strong>06:00 AM - 09:00 PM (IST)</strong>
                    </div>
                </div>
            </div>
            <div class="nav-right">
                <h2 style="font-size: 16px; font-weight: 700; color: var(--text-main); margin: 0;">🕒 Store Issue History</h2>
            </div>
        </header>

        <main class="dashboard-body">
            <!-- Filter Bar -->
            <div class="sub-requisition-card" style="padding: 16px;">
                <form method="GET" style="display: flex; gap: 16px; align-items: flex-end; flex-wrap: wrap;">
                    <div class="form-group">
                        <label>Date From</label>
                        <input type="date" name="date_from" value="<?= htmlspecialchars($dateFrom) ?>" class="form-control" style="width: 160px;">
                    </div>
                    <div class="form-group">
                        <label>Date To</label>
                        <input type="date" name="date_to" value="<?= htmlspecialchars($dateTo) ?>" class="form-control" style="width: 160px;">
                    </div>
                    <div class="form-group">
                        <label>Status</label>
                        <select name="status" class="form-control" style="width: 160px;">
                            <option value="">All Statuses</option>
                            <option value="ISSUED" <?= $status === 'ISSUED' ? 'selected' : '' ?>>Issued</option>
                            <option value="PARTIALLY_ISSUED" <?= $status === 'PARTIALLY_ISSUED' ? 'selected' : '' ?>>Partially Issued</option>
                            <option value="NOT_AVAILABLE" <?= $status === 'NOT_AVAILABLE' ? 'selected' : '' ?>>Not Available</option>
                        </select>
                    </div>
                    <button type="submit" class="btn-primary" style="height: 38px;">🔍 Filter Records</button>
                </form>
            </div>

            <!-- Table Card -->
            <div class="sub-requisition-card">
                <div class="table-responsive">
                    <table class="items-table">
                        <thead>
                            <tr>
                                <th>#</th>
                                <th>Action Time</th>
                                <th>Master Requisition</th>
                                <th>Sub Requisition</th>
                                <th>User</th>
                                <th>Material</th>
                                <th>Requested</th>
                                <th>Issued</th>
                                <th>Status</th>
                                <th>Store Incharge</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php if (empty($historyItems)): ?>
                                <tr>
                                    <td colspan="10" style="text-align: center; padding: 36px; color: var(--text-muted);">
                                        No issue history records found for the selected date range.
                                    </td>
                                </tr>
                            <?php else: ?>
                                <?php foreach ($historyItems as $idx => $row): 
                                    $statusClass = strtolower($row['status']);
                                ?>
                                    <tr>
                                        <td><?= $idx + 1 ?></td>
                                        <td><?= date('d M Y, h:i A', strtotime($row['store_action_at'])) ?></td>
                                        <td><strong><?= htmlspecialchars($row['requisition_no']) ?></strong></td>
                                        <td><?= htmlspecialchars($row['sub_requisition_no']) ?></td>
                                        <td><?= htmlspecialchars($row['user_name']) ?></td>
                                        <td><strong><?= htmlspecialchars($row['material_name_snapshot']) ?></strong></td>
                                        <td><?= $row['requested_quantity'] ?> <?= htmlspecialchars($row['unit_snapshot']) ?></td>
                                        <td><strong style="color: #16a34a;"><?= $row['issued_quantity'] ?></strong> <?= htmlspecialchars($row['unit_snapshot']) ?></td>
                                        <td>
                                            <span class="status-badge <?= $statusClass ?>">
                                                <?= str_replace('_', ' ', $row['status']) ?>
                                            </span>
                                        </td>
                                        <td><?= htmlspecialchars($row['store_action_by_name'] ?? 'Store') ?></td>
                                    </tr>
                                <?php endforeach; ?>
                            <?php endif; ?>
                        </tbody>
                    </table>
                </div>
            </div>
        </main>
    </div>
</div>
<script src="/assets/js/app-modal.js"></script>
<script src="/assets/js/store.js"></script>
</body>
</html>
