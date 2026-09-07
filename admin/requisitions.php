<?php
/**
 * ADMIN PANEL - REQUISITIONS VIEW
 * Master Requisitions & Sub-Requisitions Explorer with search, date filters, and status breakdowns
 */

require_once __DIR__ . '/../config/config.php';
require_once __DIR__ . '/../core/Database.php';
require_once __DIR__ . '/../core/Session.php';
require_once __DIR__ . '/../core/Auth.php';

Session::start();
if (!Session::get('user_id')) {
    header('Location: /admin/login.php');
    exit;
}

$currentUser = Auth::user();
if (!$currentUser || !in_array($currentUser['role'], ['SUPER_ADMIN', 'ADMIN'])) {
    Auth::logoutWeb();
    header('Location: /admin/login.php');
    exit;
}

$dateFrom = $_GET['date_from'] ?? date('Y-m-d', strtotime('-30 days'));
$dateTo = $_GET['date_to'] ?? date('Y-m-d');
$search = trim($_GET['q'] ?? '');

$where = ["r.requisition_date BETWEEN :from AND :to"];
$params = [':from' => $dateFrom, ':to' => $dateTo];

if (!empty($search)) {
    $where[] = "(r.requisition_no LIKE :q OR u.name LIKE :q OR u.employee_code LIKE :q)";
    $params[':q'] = "%{$search}%";
}

$whereSql = implode(' AND ', $where);

$sql = "SELECT r.*, u.name AS user_name, u.employee_code, d.name AS department_name,
               COUNT(DISTINCT s.id) AS sub_reqs_count,
               COUNT(i.id) AS total_items_count,
               COALESCE(SUM(i.requested_quantity), 0) AS total_requested_qty,
               COALESCE(SUM(i.issued_quantity), 0) AS total_issued_qty,
               SUM(CASE WHEN i.status = 'PENDING' THEN 1 ELSE 0 END) AS pending_count,
               SUM(CASE WHEN i.status = 'ISSUED' THEN 1 ELSE 0 END) AS issued_count,
               SUM(CASE WHEN i.status = 'PARTIALLY_ISSUED' THEN 1 ELSE 0 END) AS partial_count,
               SUM(CASE WHEN i.status = 'NOT_AVAILABLE' THEN 1 ELSE 0 END) AS na_count
        FROM requisitions r
        JOIN users u ON r.user_id = u.id
        LEFT JOIN departments d ON u.department_id = d.id
        LEFT JOIN requisition_subs s ON r.id = s.requisition_id
        LEFT JOIN requisition_items i ON s.id = i.sub_requisition_id
        WHERE {$whereSql}
        GROUP BY r.id
        ORDER BY r.requisition_date DESC, r.id DESC";

$requisitions = Database::query($sql, $params);
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Master Requisitions - <?= htmlspecialchars(Config::get('APP_NAME')) ?></title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="/assets/css/admin.css">
</head>
<body>
<div class="app-container">
    <?php require __DIR__ . '/includes/sidebar.php'; ?>

    <div class="main-wrapper">
        <header class="top-navbar">
            <div class="nav-title-block">
                <h1>📋 Master Requisitions Directory</h1>
                <p>One Master Requisition per user per date with location-wise sub-requisitions.</p>
            </div>
        </header>

        <main class="dashboard-content">
            <!-- Filter Bar -->
            <div class="card-box" style="margin-bottom: 20px;">
                <form method="GET" style="display: flex; gap: 14px; align-items: flex-end; flex-wrap: wrap;">
                    <div class="form-group">
                        <label style="font-size: 12px; font-weight: 600;">Date From</label>
                        <input type="date" name="date_from" value="<?= htmlspecialchars($dateFrom) ?>" class="form-control" style="width: 150px;">
                    </div>
                    <div class="form-group">
                        <label style="font-size: 12px; font-weight: 600;">Date To</label>
                        <input type="date" name="date_to" value="<?= htmlspecialchars($dateTo) ?>" class="form-control" style="width: 150px;">
                    </div>
                    <div class="form-group">
                        <label style="font-size: 12px; font-weight: 600;">Search User / Req No.</label>
                        <input type="text" name="q" value="<?= htmlspecialchars($search) ?>" class="form-control" placeholder="REQ-... or Name" style="width: 220px;">
                    </div>
                    <button type="submit" class="btn-open-override" style="margin: 0; padding: 9px 20px; background: #2563eb;">
                        🔍 Filter
                    </button>
                </form>
            </div>

            <!-- Requisitions Table -->
            <div class="table-card">
                <div class="table-header-bar">
                    <span style="font-size: 14.5px; font-weight: 700;">Requisitions Found (<?= count($requisitions) ?>)</span>
                </div>
                <div class="table-responsive">
                    <table class="admin-table">
                        <thead>
                            <tr>
                                <th>Requisition No.</th>
                                <th>User Name</th>
                                <th>Department</th>
                                <th>Date</th>
                                <th style="text-align: center;">Locations (Subs)</th>
                                <th style="text-align: center;">Total Items</th>
                                <th style="text-align: center;">Requested Qty</th>
                                <th style="text-align: center;">Issued Qty</th>
                                <th>Status</th>
                                <th style="text-align: center;">Action</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php if (empty($requisitions)): ?>
                                <tr>
                                    <td colspan="10" style="text-align: center; padding: 36px; color: var(--text-muted);">
                                        No requisitions match your criteria.
                                    </td>
                                </tr>
                            <?php else: ?>
                                <?php foreach ($requisitions as $r): ?>
                                    <tr>
                                        <td><code><?= htmlspecialchars($r['requisition_no']) ?></code></td>
                                        <td><strong><?= htmlspecialchars($r['user_name']) ?></strong> (<?= htmlspecialchars($r['employee_code']) ?>)</td>
                                        <td><?= htmlspecialchars($r['department_name'] ?? '-') ?></td>
                                        <td><?= date('d M Y', strtotime($r['requisition_date'])) ?></td>
                                        <td style="text-align: center;"><strong><?= $r['sub_reqs_count'] ?></strong> Locations</td>
                                        <td style="text-align: center;"><?= $r['total_items_count'] ?> items</td>
                                        <td style="text-align: center;"><?= $r['total_requested_qty'] ?></td>
                                        <td style="text-align: center; font-weight: 700; color: #16a34a;"><?= $r['total_issued_qty'] ?></td>
                                        <td>
                                            <span style="font-size: 11px; font-weight: 700; padding: 3px 8px; border-radius: 4px; background: #eff6ff; color: #1d4ed8;">
                                                <?= $r['status'] ?>
                                            </span>
                                        </td>
                                        <td style="text-align: center;">
                                            <a href="/store/index.php?user_id=<?= $r['user_id'] ?>" target="_blank" class="btn-view-icon" title="View in Store Panel">
                                                👁️
                                            </a>
                                        </td>
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
</body>
</html>
