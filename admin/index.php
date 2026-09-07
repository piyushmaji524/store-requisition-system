<?php
/**
 * ADMIN PANEL - DASHBOARD
 * Real-time ERP metrics, Dynamic Charts, Live Date Overrides, Recent Master Requisitions
 * 100% Database-Driven Production Configuration
 */

require_once __DIR__ . '/../config/config.php';
require_once __DIR__ . '/../core/Database.php';
require_once __DIR__ . '/../core/Session.php';
require_once __DIR__ . '/../core/Auth.php';
require_once __DIR__ . '/../services/TimeService.php';
require_once __DIR__ . '/../services/AdminService.php';

Session::start();

// Ensure Authenticated Admin
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
$todayStr = date('Y-m-d');
$today = $todayStr;

// Parse date presets & ranges
$preset = trim($_GET['preset'] ?? '');
$dateFrom = trim($_GET['date_from'] ?? '');
$dateTo = trim($_GET['date_to'] ?? '');

if ($preset === 'today') {
    $dateFrom = $today;
    $dateTo = $today;
    $periodLabel = 'Today (' . date('d M Y') . ')';
} elseif ($preset === 'yesterday') {
    $dateFrom = date('Y-m-d', strtotime('-1 day'));
    $dateTo = date('Y-m-d', strtotime('-1 day'));
    $periodLabel = 'Yesterday (' . date('d M Y', strtotime('-1 day')) . ')';
} elseif ($preset === 'last_7_days') {
    $dateFrom = date('Y-m-d', strtotime('-6 days'));
    $dateTo = $today;
    $periodLabel = 'Last 7 Days (' . date('d M', strtotime('-6 days')) . ' - ' . date('d M Y') . ')';
} elseif ($preset === 'this_month') {
    $dateFrom = date('Y-m-01');
    $dateTo = $today;
    $periodLabel = 'This Month (' . date('M Y') . ')';
} elseif ($preset === 'last_month') {
    $dateFrom = date('Y-m-01', strtotime('first day of last month'));
    $dateTo = date('Y-m-t', strtotime('last day of last month'));
    $periodLabel = 'Last Month (' . date('M Y', strtotime('first day of last month')) . ')';
} elseif ($preset === 'last_3_months') {
    $dateFrom = date('Y-m-d', strtotime('-90 days'));
    $dateTo = $today;
    $periodLabel = 'Last 3 Months (' . date('d M Y', strtotime('-90 days')) . ' - ' . date('d M Y') . ')';
} elseif ($preset === 'all_time') {
    $dateFrom = '';
    $dateTo = '';
    $periodLabel = 'All Time';
} else {
    if (!empty($dateFrom) || !empty($dateTo)) {
        if (!empty($dateFrom) && !empty($dateTo) && $dateFrom === $dateTo) {
            $preset = ($dateFrom === $today) ? 'today' : (($dateFrom === date('Y-m-d', strtotime('-1 day'))) ? 'yesterday' : 'custom');
            $periodLabel = date('d M Y', strtotime($dateFrom));
        } else {
            $preset = 'custom';
            $fromStr = !empty($dateFrom) ? date('d M Y', strtotime($dateFrom)) : 'Start';
            $toStr = !empty($dateTo) ? date('d M Y', strtotime($dateTo)) : 'Now';
            $periodLabel = "{$fromStr} - {$toStr}";
        }
    } else {
        $preset = 'today';
        $dateFrom = $today;
        $dateTo = $today;
        $periodLabel = 'Today (' . date('d M Y') . ')';
    }
}

// Fetch dynamic metrics for the selected period
$metrics = AdminService::getDashboardMetrics($dateFrom, $dateTo);
$timingStatus = TimeService::getTimingStatus($dateFrom ?: $todayStr);

// Where filter for recent requisitions and top locations
$whereReq = [];
$paramsReq = [];
if (!empty($dateFrom) && !empty($dateTo)) {
    if ($dateFrom === $dateTo) {
        $whereReq[] = "r.requisition_date = :req_date";
        $paramsReq[':req_date'] = $dateFrom;
    } else {
        $whereReq[] = "r.requisition_date BETWEEN :date_from AND :date_to";
        $paramsReq[':date_from'] = $dateFrom;
        $paramsReq[':date_to'] = $dateTo;
    }
} elseif (!empty($dateFrom)) {
    $whereReq[] = "r.requisition_date >= :date_from";
    $paramsReq[':date_from'] = $dateFrom;
} elseif (!empty($dateTo)) {
    $whereReq[] = "r.requisition_date <= :date_to";
    $paramsReq[':date_to'] = $dateTo;
}
$whereReqSql = !empty($whereReq) ? ("WHERE " . implode(" AND ", $whereReq)) : "";

// Fetch recent master requisitions from database in this period
$recentReqsSql = "SELECT r.*, u.name AS user_name, u.employee_code,
                         COUNT(DISTINCT s.id) AS sub_reqs_count,
                         COUNT(i.id) AS total_items_count,
                         COALESCE(SUM(i.issued_quantity), 0) AS total_issued_qty,
                         SUM(CASE WHEN i.status = 'PENDING' THEN 1 ELSE 0 END) AS pending_count
                  FROM requisitions r
                  JOIN users u ON r.user_id = u.id
                  LEFT JOIN requisition_subs s ON r.id = s.requisition_id
                  LEFT JOIN requisition_items i ON s.id = i.sub_requisition_id
                  {$whereReqSql}
                  GROUP BY r.id
                  ORDER BY r.requisition_date DESC, r.id DESC
                  LIMIT 5";
$recentRequisitions = Database::query($recentReqsSql, $paramsReq);

// Fetch active override status
$activeOverride = Database::queryOne("SELECT * FROM admin_date_overrides WHERE status = 'OPEN' AND expires_at > NOW() ORDER BY id DESC LIMIT 1");

// Fetch real top locations by issued quantity in this period
$topLocWhere = !empty($whereReq) ? ("WHERE l.status = 'ACTIVE' AND " . implode(" AND ", $whereReq)) : "WHERE l.status = 'ACTIVE'";
$topLocationsSql = "SELECT l.name, COALESCE(SUM(i.issued_quantity), 0) AS total_issued
                    FROM locations l
                    LEFT JOIN requisition_subs s ON l.id = s.location_id
                    LEFT JOIN requisitions r ON s.requisition_id = r.id
                    LEFT JOIN requisition_items i ON s.id = i.sub_requisition_id AND i.status IN ('ISSUED', 'PARTIALLY_ISSUED')
                    {$topLocWhere}
                    GROUP BY l.id
                    ORDER BY total_issued DESC, l.name ASC
                    LIMIT 5";
$topLocations = Database::query($topLocationsSql, $paramsReq);

// Calculate max location for chart scaling
$maxLocationIssued = 1;
foreach ($topLocations as $loc) {
    if ((float)$loc['total_issued'] > $maxLocationIssued) {
        $maxLocationIssued = (float)$loc['total_issued'];
    }
}

// Calculate Donut percentages from real metrics
$totalItems = $metrics['total_items'];
$pctIssued = $totalItems > 0 ? round(($metrics['issued_items'] / $totalItems) * 100, 1) : 0;
$pctPending = $totalItems > 0 ? round(($metrics['pending_items'] / $totalItems) * 100, 1) : 0;
$pctPartial = $totalItems > 0 ? round(($metrics['partial_items'] / $totalItems) * 100, 1) : 0;
$pctNotAvailable = $totalItems > 0 ? round(($metrics['not_available_items'] / $totalItems) * 100, 1) : 0;

// Dynamic Donut Slice Angles (conic-gradient)
$stop1 = $pctIssued;
$stop2 = $stop1 + $pctPending;
$stop3 = $stop2 + $pctPartial;
$donutConicStyle = $totalItems > 0 
    ? "background: conic-gradient(#22c55e 0% {$stop1}%, #f59e0b {$stop1}% {$stop2}%, #3b82f6 {$stop2}% {$stop3}%, #ef4444 {$stop3}% 100%);" 
    : "background: #e2e8f0;";

// System counts
$totalUsersCount = Database::queryOne("SELECT COUNT(*) AS total FROM users WHERE status = 'ACTIVE'")['total'] ?? 0;
$totalMaterialsCount = Database::queryOne("SELECT COUNT(*) AS total FROM materials WHERE status = 'ACTIVE'")['total'] ?? 0;
$totalLocationsCount = Database::queryOne("SELECT COUNT(*) AS total FROM locations WHERE status = 'ACTIVE'")['total'] ?? 0;
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Admin Dashboard - <?= htmlspecialchars(Config::get('APP_NAME')) ?></title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="/assets/css/admin.css">
</head>
<body>

<div class="app-container">
    <?php require __DIR__ . '/includes/sidebar.php'; ?>

    <!-- Main Content Area -->
    <div class="main-wrapper">
        <!-- Top Navbar -->
        <header class="top-navbar">
            <div class="nav-title-block">
                <h1>Dashboard</h1>
                <p>Welcome back, <?= htmlspecialchars($currentUser['name']) ?>! Enterprise Store Requisition Monitor.</p>
            </div>

            <div class="nav-badges-group">
                <div class="nav-pill-badge">
                    <span>🏪 Store Window: <strong>06:00 AM - 09:00 PM (IST)</strong></span>
                    <span class="badge-status" style="background: <?= $timingStatus['store_window']['is_open'] ? '#dcfce7; color: #15803d;' : '#fee2e2; color: #b91c1c;' ?>">
                        <?= $timingStatus['store_window']['is_open'] ? 'OPEN' : 'CLOSED' ?>
                    </span>
                </div>
                <div class="nav-pill-badge" id="admin-header-clock">
                    📅 <?= date('d M Y, l h:i:s A') ?> (IST)
                </div>
                <div style="display: flex; align-items: center; gap: 10px;">
                    <div style="width: 34px; height: 34px; background: #e0e7ff; color: #4338ca; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: 700;">
                        <?= strtoupper(substr($currentUser['name'], 0, 1)) ?>
                    </div>
                    <div>
                        <div style="font-size: 13px; font-weight: 700; color: var(--text-main);"><?= htmlspecialchars($currentUser['name']) ?></div>
                        <div style="font-size: 11px; color: var(--text-muted);"><?= htmlspecialchars($currentUser['role']) ?></div>
                    </div>
                </div>
            </div>
        </header>

        <!-- Main Dashboard View -->
        <main class="dashboard-content">
            <!-- Interactive Date Filter Toolbar & Quick Presets -->
            <div class="dashboard-filter-card">
                <div class="dashboard-filter-row">
                    <div class="date-preset-pills">
                        <span style="font-size: 12.5px; font-weight: 700; color: var(--text-main); margin-right: 4px;">📅 Quick Filter:</span>
                        <a href="?preset=today" class="date-pill-btn <?= ($preset === 'today') ? 'active' : '' ?>">Today</a>
                        <a href="?preset=yesterday" class="date-pill-btn <?= ($preset === 'yesterday') ? 'active' : '' ?>">Yesterday</a>
                        <a href="?preset=last_7_days" class="date-pill-btn <?= ($preset === 'last_7_days') ? 'active' : '' ?>">Last 7 Days</a>
                        <a href="?preset=this_month" class="date-pill-btn <?= ($preset === 'this_month') ? 'active' : '' ?>">This Month</a>
                        <a href="?preset=last_month" class="date-pill-btn <?= ($preset === 'last_month') ? 'active' : '' ?>">Last Month</a>
                        <a href="?preset=last_3_months" class="date-pill-btn <?= ($preset === 'last_3_months') ? 'active' : '' ?>">Last 3 Months</a>
                        <a href="?preset=all_time" class="date-pill-btn <?= ($preset === 'all_time') ? 'active' : '' ?>">⚡ All Time</a>
                    </div>

                    <div style="font-size: 12.5px; color: var(--text-muted); font-weight: 600;">
                        Period: <strong style="color: var(--primary-color);"><?= htmlspecialchars($periodLabel) ?></strong>
                    </div>
                </div>

                <div class="dashboard-filter-row" style="border-top: 1px dashed var(--border-color); padding-top: 10px;">
                    <form method="GET" action="/admin/index.php" class="custom-range-form">
                        <span style="font-size: 12px; font-weight: 700; color: var(--text-muted);">Custom Range:</span>
                        <div class="range-input-box">
                            <span style="font-size: 11.5px; color: var(--text-muted); font-weight: 600;">From:</span>
                            <input type="date" name="date_from" value="<?= htmlspecialchars($dateFrom) ?>" max="<?= $todayStr ?>">
                        </div>
                        <div class="range-input-box">
                            <span style="font-size: 11.5px; color: var(--text-muted); font-weight: 600;">To:</span>
                            <input type="date" name="date_to" value="<?= htmlspecialchars($dateTo) ?>" max="<?= $todayStr ?>">
                        </div>
                        <button type="submit" class="btn-primary" style="padding: 5px 14px; font-size: 12px;">Apply Range</button>
                        <?php if ($preset !== 'today'): ?>
                            <a href="/admin/index.php?preset=today" style="font-size: 12px; color: var(--primary-color); text-decoration: none; font-weight: 600; padding: 4px 8px;">Reset to Today</a>
                        <?php endif; ?>
                    </form>

                    <div style="font-size: 12px; color: var(--text-muted);">
                        📊 Showing aggregated metrics and analytics for <?= htmlspecialchars($periodLabel) ?>
                    </div>
                </div>
            </div>

            <!-- 5 Metric Cards -->
            <section class="admin-metrics-grid">
                <div class="admin-metric-card">
                    <div class="metric-icon-sq blue">📋</div>
                    <div class="metric-data">
                        <span class="metric-data-title">Total Master Requisitions</span>
                        <span class="metric-data-val"><?= $metrics['total_master_reqs'] ?></span>
                        <span class="metric-data-sub"><?= htmlspecialchars($periodLabel) ?></span>
                    </div>
                </div>

                <div class="admin-metric-card">
                    <div class="metric-icon-sq orange">📑</div>
                    <div class="metric-data">
                        <span class="metric-data-title">Total Sub Requisitions</span>
                        <span class="metric-data-val"><?= $metrics['total_sub_reqs'] ?></span>
                        <span class="metric-data-sub"><?= htmlspecialchars($periodLabel) ?></span>
                    </div>
                </div>

                <div class="admin-metric-card">
                    <div class="metric-icon-sq green">📦</div>
                    <div class="metric-data">
                        <span class="metric-data-title">Issued Quantity (Total)</span>
                        <span class="metric-data-val"><?= number_format($metrics['total_issued_qty'], 2) ?></span>
                        <span class="metric-data-sub"><?= htmlspecialchars($periodLabel) ?></span>
                    </div>
                </div>

                <div class="admin-metric-card">
                    <div class="metric-icon-sq purple">❌</div>
                    <div class="metric-data">
                        <span class="metric-data-title">Not Available Items</span>
                        <span class="metric-data-val"><?= $metrics['not_available_items'] ?></span>
                        <span class="metric-data-sub"><?= htmlspecialchars($periodLabel) ?></span>
                    </div>
                </div>

                <div class="admin-metric-card">
                    <div class="metric-icon-sq teal">📊</div>
                    <div class="metric-data">
                        <span class="metric-data-title">Tally Exported Sub-Reqs</span>
                        <span class="metric-data-val"><?= $metrics['tally_exported_subs'] ?></span>
                        <span class="metric-data-sub"><?= htmlspecialchars($periodLabel) ?></span>
                    </div>
                </div>
            </section>

            <!-- Middle Analytics Row (Donut Chart, Location Bar Chart, Date Override Widget) -->
            <section class="analytics-grid">
                <!-- Requisition Summary Donut -->
                <div class="card-box">
                    <div class="card-box-header">
                        <span class="card-box-title">Requisition Summary (<?= htmlspecialchars($periodLabel) ?>)</span>
                    </div>
                    <div class="donut-container">
                        <div class="donut-graphic" style="<?= $donutConicStyle ?>">
                            <div class="donut-inner-hole">
                                <strong><?= $metrics['total_items'] ?></strong>
                                <span>Total Items</span>
                            </div>
                        </div>
                        <div class="donut-legend">
                            <div class="legend-row">
                                <div class="legend-row-left">
                                    <span class="dot-sq" style="background-color: #22c55e;"></span>
                                    <span>Issued (<?= $metrics['issued_items'] ?>)</span>
                                </div>
                                <strong><?= $pctIssued ?>%</strong>
                            </div>
                            <div class="legend-row">
                                <div class="legend-row-left">
                                    <span class="dot-sq" style="background-color: #f59e0b;"></span>
                                    <span>Pending (<?= $metrics['pending_items'] ?>)</span>
                                </div>
                                <strong><?= $pctPending ?>%</strong>
                            </div>
                            <div class="legend-row">
                                <div class="legend-row-left">
                                    <span class="dot-sq" style="background-color: #3b82f6;"></span>
                                    <span>Partially Issued (<?= $metrics['partial_items'] ?>)</span>
                                </div>
                                <strong><?= $pctPartial ?>%</strong>
                            </div>
                            <div class="legend-row">
                                <div class="legend-row-left">
                                    <span class="dot-sq" style="background-color: #ef4444;"></span>
                                    <span>Not Available (<?= $metrics['not_available_items'] ?>)</span>
                                </div>
                                <strong><?= $pctNotAvailable ?>%</strong>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Top Locations by Issued Quantity -->
                <div class="card-box">
                    <div class="card-box-header">
                        <span class="card-box-title">Top Locations (<?= htmlspecialchars($periodLabel) ?>)</span>
                    </div>
                    <div class="bar-chart-container">
                        <?php if (empty($topLocations)): ?>
                            <div style="display: flex; align-items: center; justify-content: center; height: 100%; color: var(--text-muted); font-size: 13px;">
                                No location consumption recorded yet.
                            </div>
                        <?php else: ?>
                            <?php foreach ($topLocations as $loc): 
                                $issuedVal = (float)$loc['total_issued'];
                                $pct = $maxLocationIssued > 0 ? max(8, round(($issuedVal / $maxLocationIssued) * 100)) : 8;
                            ?>
                                <div class="bar-column">
                                    <span class="bar-val-label"><?= number_format($issuedVal, 0) ?></span>
                                    <div class="bar-fill" style="height: <?= $pct ?>%;"></div>
                                    <span class="bar-name-label" title="<?= htmlspecialchars($loc['name']) ?>"><?= htmlspecialchars($loc['name']) ?></span>
                                </div>
                            <?php endforeach; ?>
                        <?php endif; ?>
                    </div>
                </div>

                <!-- Date Override Widget -->
                <?php $overrideHours = (int) Config::get('ADMIN_OVERRIDE_HOURS', 2); ?>
                <div class="card-box">
                    <div class="card-box-header">
                        <div>
                            <span class="card-box-title">Date Override (Store Edit Control)</span>
                            <span class="nav-badge-new" style="margin-left: 6px;"><?= $overrideHours ?>-HR WINDOW</span>
                        </div>
                    </div>
                    <p style="font-size: 12px; color: var(--text-muted); margin-bottom: 12px;">
                        Reopen past dates for store editing for <?= $overrideHours ?> hours with audit logging.
                    </p>

                    <form onsubmit="submitDateOverride(event)">
                        <input type="hidden" name="duration_hours" value="<?= $overrideHours ?>">
                        <div class="form-group">
                            <label style="font-size: 12px; font-weight: 600;">Target Past Date</label>
                            <input type="date" name="override_date" value="<?= date('Y-m-d', strtotime('-1 day')) ?>" class="form-control" required>
                        </div>
                        <div class="form-group" style="margin-top: 10px;">
                            <label style="font-size: 12px; font-weight: 600;">Reason *</label>
                            <input type="text" name="reason" placeholder="e.g. Voucher correction..." class="form-control" required>
                        </div>
                        <div style="display: flex; align-items: center; justify-content: space-between; margin-top: 10px; font-size: 12px;">
                            <span>Current Status:</span>
                            <?php if ($activeOverride): ?>
                                <span style="background: #dcfce7; color: #15803d; padding: 2px 8px; border-radius: 4px; font-weight: 700;">
                                    ACTIVE (<?= date('d M', strtotime($activeOverride['override_date'])) ?>)
                                </span>
                            <?php else: ?>
                                <span style="background: #fee2e2; color: #b91c1c; padding: 2px 8px; border-radius: 4px; font-weight: 700;">CLOSED</span>
                            <?php endif; ?>
                        </div>
                        <button type="submit" class="btn-open-override">
                            Open Date for <?= $overrideHours ?> Hours (IST)
                        </button>
                    </form>
                </div>
            </section>

            <!-- Bottom Section: Master Requisitions & System Overview -->
            <section class="bottom-split-grid">
                <!-- Master Requisitions Table -->
                <div class="table-card">
                    <div class="table-header-bar">
                        <span class="table-title">Recent Master Requisitions</span>
                        <a href="/admin/requisitions.php" class="view-all-link">View All Master Requisitions →</a>
                    </div>
                    <div class="table-responsive">
                        <table class="admin-table">
                            <thead>
                                <tr>
                                    <th>Requisition No.</th>
                                    <th>User</th>
                                    <th>Date</th>
                                    <th style="text-align: center;">Locations</th>
                                    <th style="text-align: center;">Items</th>
                                    <th style="text-align: center;">Issued Qty</th>
                                    <th>Status</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php if (empty($recentRequisitions)): ?>
                                    <tr>
                                        <td colspan="7" style="text-align: center; padding: 32px; color: var(--text-muted);">
                                            No requisitions recorded yet.
                                        </td>
                                    </tr>
                                <?php else: ?>
                                    <?php foreach ($recentRequisitions as $req): ?>
                                        <tr>
                                            <td>
                                                <a href="/store/index.php?user_id=<?= $req['user_id'] ?>&date=<?= urlencode($req['requisition_date']) ?>" style="color: var(--primary-color); font-weight: 700; text-decoration: none;">
                                                    <code><?= htmlspecialchars($req['requisition_no']) ?></code>
                                                </a>
                                            </td>
                                            <td>
                                                <strong><?= htmlspecialchars($req['user_name']) ?></strong>
                                                <small style="color: var(--text-muted); display: block;"><?= htmlspecialchars($req['employee_code']) ?></small>
                                            </td>
                                            <td><?= date('d M Y', strtotime($req['requisition_date'])) ?></td>
                                            <td style="text-align: center;"><strong><?= $req['sub_reqs_count'] ?></strong> Sites</td>
                                            <td style="text-align: center;"><?= $req['total_items_count'] ?> items</td>
                                            <td style="text-align: center; font-weight: 700; color: #16a34a;"><?= number_format($req['total_issued_qty'], 2) ?></td>
                                            <td>
                                                <span style="font-size: 11px; font-weight: 700; padding: 3px 8px; border-radius: 4px; background: #eff6ff; color: #1d4ed8;">
                                                    <?= $req['status'] ?>
                                                </span>
                                            </td>
                                        </tr>
                                    <?php endforeach; ?>
                                <?php endif; ?>
                            </tbody>
                        </table>
                    </div>
                </div>

                <!-- Live System Master Overview -->
                <div class="card-box">
                    <div class="card-box-header">
                        <span class="card-box-title">System Master Overview</span>
                    </div>

                    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-bottom: 16px;">
                        <div style="background: #f8fafc; padding: 12px; border-radius: 8px; border: 1px solid var(--border-color);">
                            <span style="font-size: 11.5px; color: var(--text-muted); display: block;">Active Users</span>
                            <span style="font-size: 18px; font-weight: 800; color: var(--text-main);"><?= $totalUsersCount ?></span>
                        </div>
                        <div style="background: #f8fafc; padding: 12px; border-radius: 8px; border: 1px solid var(--border-color);">
                            <span style="font-size: 11.5px; color: var(--text-muted); display: block;">Material Master</span>
                            <span style="font-size: 18px; font-weight: 800; color: var(--text-main);"><?= $totalMaterialsCount ?></span>
                        </div>
                        <div style="background: #f8fafc; padding: 12px; border-radius: 8px; border: 1px solid var(--border-color);">
                            <span style="font-size: 11.5px; color: var(--text-muted); display: block;">Locations Master</span>
                            <span style="font-size: 18px; font-weight: 800; color: var(--text-main);"><?= $totalLocationsCount ?></span>
                        </div>
                        <div style="background: #f8fafc; padding: 12px; border-radius: 8px; border: 1px solid var(--border-color);">
                            <span style="font-size: 11.5px; color: var(--text-muted); display: block;">Timezone</span>
                            <span style="font-size: 13px; font-weight: 800; color: #16a34a;">Asia/Kolkata</span>
                        </div>
                    </div>

                    <div class="card-box-header" style="margin-top: 20px; padding-top: 14px; border-top: 1px solid var(--border-color);">
                        <span class="card-box-title">Quick Administration</span>
                    </div>

                    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 10px;">
                        <a href="/admin/tally_export.php" class="shortcut-btn teal" style="text-decoration: none; justify-content: center; padding: 10px;">
                            📑 Tally Export
                        </a>
                        <a href="/admin/materials.php" class="shortcut-btn blue" style="text-decoration: none; justify-content: center; padding: 10px;">
                            🏷️ Materials Master
                        </a>
                        <a href="/admin/users.php" class="shortcut-btn green" style="text-decoration: none; justify-content: center; padding: 10px;">
                            👥 User Master
                        </a>
                        <a href="/admin/settings.php" class="shortcut-btn purple" style="text-decoration: none; justify-content: center; padding: 10px;">
                            ⚙️ System Settings
                        </a>
                    </div>
                </div>
            </section>
        </main>
    </div>
</div>

<script src="/assets/js/app-modal.js?v=<?= time() ?>"></script>
<script src="/assets/js/admin.js?v=<?= time() ?>"></script>
</body>
</html>
