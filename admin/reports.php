<?php
/**
 * ADMIN PANEL - REPORTS & ANALYTICS
 * Comprehensive reports (Requisition, Sub-Requisition, User, Location, Material Issues)
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
$reportType = $_GET['type'] ?? 'material';

$where = ["r.requisition_date BETWEEN :from AND :to"];
$params = [':from' => $dateFrom, ':to' => $dateTo];

if ($reportType === 'material') {
    $sql = "SELECT m.name AS material_name, m.code AS material_code, m.unit,
                   COUNT(i.id) AS total_requests,
                   COALESCE(SUM(i.requested_quantity), 0) AS total_requested_qty,
                   COALESCE(SUM(i.issued_quantity), 0) AS total_issued_qty,
                   COALESCE(SUM(i.amount), 0) AS total_amount_val
            FROM materials m
            LEFT JOIN requisition_items i ON m.id = i.material_id
            LEFT JOIN requisition_subs s ON i.sub_requisition_id = s.id
            LEFT JOIN requisitions r ON s.requisition_id = r.id AND {$where[0]}
            GROUP BY m.id
            ORDER BY total_issued_qty DESC";
    $reportData = Database::query($sql, $params);
} elseif ($reportType === 'user') {
    $sql = "SELECT u.name AS user_name, u.employee_code, d.name AS department_name,
                   COUNT(DISTINCT r.id) AS total_requisitions,
                   COUNT(i.id) AS total_items,
                   COALESCE(SUM(i.issued_quantity), 0) AS total_issued_qty
            FROM users u
            LEFT JOIN departments d ON u.department_id = d.id
            LEFT JOIN requisitions r ON u.id = r.user_id AND {$where[0]}
            LEFT JOIN requisition_subs s ON r.id = s.requisition_id
            LEFT JOIN requisition_items i ON s.id = i.sub_requisition_id
            WHERE u.role = 'REQUISITION_USER'
            GROUP BY u.id
            ORDER BY total_issued_qty DESC";
    $reportData = Database::query($sql, $params);
} else {
    $sql = "SELECT l.name AS location_name, l.code AS location_code,
                   COUNT(DISTINCT s.id) AS sub_requisition_count,
                   COUNT(i.id) AS items_count,
                   COALESCE(SUM(i.issued_quantity), 0) AS total_issued_qty
            FROM locations l
            LEFT JOIN requisition_subs s ON l.id = s.location_id
            LEFT JOIN requisitions r ON s.requisition_id = r.id AND {$where[0]}
            LEFT JOIN requisition_items i ON s.id = i.sub_requisition_id
            GROUP BY l.id
            ORDER BY total_issued_qty DESC";
    $reportData = Database::query($sql, $params);
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reports - <?= htmlspecialchars(Config::get('APP_NAME')) ?></title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="/assets/css/admin.css">
</head>
<body>
<div class="app-container">
    <?php require __DIR__ . '/includes/sidebar.php'; ?>

    <div class="main-wrapper">
        <header class="top-navbar">
            <div class="nav-title-block">
                <h1>📈 Enterprise Reports & Analytics</h1>
                <p>Material issue aggregates, location distribution, and user request summaries.</p>
            </div>
        </header>

        <main class="dashboard-content">
            <!-- Filter Bar -->
            <div class="card-box" style="margin-bottom: 20px;">
                <form method="GET" style="display: flex; gap: 14px; align-items: flex-end; flex-wrap: wrap;">
                    <div class="form-group">
                        <label style="font-size: 12px; font-weight: 600;">Report Type</label>
                        <select name="type" class="form-control" style="width: 200px;">
                            <option value="material" <?= $reportType === 'material' ? 'selected' : '' ?>>Material Issue Report</option>
                            <option value="user" <?= $reportType === 'user' ? 'selected' : '' ?>>User Requisition Report</option>
                            <option value="location" <?= $reportType === 'location' ? 'selected' : '' ?>>Location Consumption Report</option>
                        </select>
                    </div>
                    <div class="form-group">
                        <label style="font-size: 12px; font-weight: 600;">Date From</label>
                        <input type="date" name="date_from" value="<?= htmlspecialchars($dateFrom) ?>" class="form-control" style="width: 150px;">
                    </div>
                    <div class="form-group">
                        <label style="font-size: 12px; font-weight: 600;">Date To</label>
                        <input type="date" name="date_to" value="<?= htmlspecialchars($dateTo) ?>" class="form-control" style="width: 150px;">
                    </div>
                    <button type="submit" class="btn-open-override" style="margin: 0; padding: 9px 20px; background: #2563eb;">
                        Generate Report
                    </button>
                </form>
            </div>

            <!-- Report Table -->
            <div class="table-card">
                <div class="table-header-bar">
                    <span style="font-size: 14.5px; font-weight: 700;">
                        <?= ucfirst($reportType) ?> Report (<?= date('d M Y', strtotime($dateFrom)) ?> to <?= date('d M Y', strtotime($dateTo)) ?>)
                    </span>
                </div>
                <div class="table-responsive">
                    <table class="admin-table">
                        <?php if ($reportType === 'material'): ?>
                            <thead>
                                <tr>
                                    <th>#</th>
                                    <th>Material Name</th>
                                    <th>Item Code</th>
                                    <th>Unit</th>
                                    <th style="text-align: center;">Times Requested</th>
                                    <th style="text-align: center;">Total Requested</th>
                                    <th style="text-align: center;">Total Issued</th>
                                    <th style="text-align: right;">Total Amount (₹)</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php foreach ($reportData as $idx => $r): ?>
                                    <tr>
                                        <td><?= $idx + 1 ?></td>
                                        <td><strong><?= htmlspecialchars($r['material_name']) ?></strong></td>
                                        <td><code><?= htmlspecialchars($r['material_code']) ?></code></td>
                                        <td><?= htmlspecialchars($r['unit']) ?></td>
                                        <td style="text-align: center;"><?= $r['total_requests'] ?></td>
                                        <td style="text-align: center;"><?= $r['total_requested_qty'] ?></td>
                                        <td style="text-align: center; font-weight: 700; color: #16a34a;"><?= $r['total_issued_qty'] ?></td>
                                        <td style="text-align: right; font-weight: 700;">₹ <?= number_format($r['total_amount_val'], 2) ?></td>
                                    </tr>
                                <?php endforeach; ?>
                            </tbody>
                        <?php elseif ($reportType === 'user'): ?>
                            <thead>
                                <tr>
                                    <th>#</th>
                                    <th>User Name</th>
                                    <th>Employee Code</th>
                                    <th>Department</th>
                                    <th style="text-align: center;">Requisitions Made</th>
                                    <th style="text-align: center;">Total Items</th>
                                    <th style="text-align: center;">Total Qty Issued</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php foreach ($reportData as $idx => $r): ?>
                                    <tr>
                                        <td><?= $idx + 1 ?></td>
                                        <td><strong><?= htmlspecialchars($r['user_name']) ?></strong></td>
                                        <td><code><?= htmlspecialchars($r['employee_code']) ?></code></td>
                                        <td><?= htmlspecialchars($r['department_name'] ?? 'General') ?></td>
                                        <td style="text-align: center;"><?= $r['total_requisitions'] ?></td>
                                        <td style="text-align: center;"><?= $r['total_items'] ?></td>
                                        <td style="text-align: center; font-weight: 700; color: #16a34a;"><?= $r['total_issued_qty'] ?></td>
                                    </tr>
                                <?php endforeach; ?>
                            </tbody>
                        <?php else: ?>
                            <thead>
                                <tr>
                                    <th>#</th>
                                    <th>Location Name</th>
                                    <th>Location Code</th>
                                    <th style="text-align: center;">Sub Requisitions</th>
                                    <th style="text-align: center;">Items Dispatched</th>
                                    <th style="text-align: center;">Total Qty Issued</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php foreach ($reportData as $idx => $r): ?>
                                    <tr>
                                        <td><?= $idx + 1 ?></td>
                                        <td><strong><?= htmlspecialchars($r['location_name']) ?></strong></td>
                                        <td><code><?= htmlspecialchars($r['location_code']) ?></code></td>
                                        <td style="text-align: center;"><?= $r['sub_requisition_count'] ?></td>
                                        <td style="text-align: center;"><?= $r['items_count'] ?></td>
                                        <td style="text-align: center; font-weight: 700; color: #16a34a;"><?= $r['total_issued_qty'] ?></td>
                                    </tr>
                                <?php endforeach; ?>
                            </tbody>
                        <?php endif; ?>
                    </table>
                </div>
            </div>
        </main>
    </div>
</div>
</body>
</html>
