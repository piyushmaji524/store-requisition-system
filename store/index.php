<?php
/**
 * STORE PANEL - MAIN WORKSPACE
 * High-Productivity Requisition Fulfillment & Pending Action Dashboard
 */

require_once __DIR__ . '/../config/config.php';
require_once __DIR__ . '/../core/Database.php';
require_once __DIR__ . '/../core/Session.php';
require_once __DIR__ . '/../core/Auth.php';
require_once __DIR__ . '/../services/TimeService.php';
require_once __DIR__ . '/../services/StoreService.php';
require_once __DIR__ . '/../services/RequisitionService.php';

Session::start();

// Ensure Authenticated Store User
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
$todayStr = date('Y-m-d');
$selectedDate = isset($_GET['date']) && preg_match('/^\d{4}-\d{2}-\d{2}$/', $_GET['date']) ? $_GET['date'] : $todayStr;
$isToday = ($selectedDate === $todayStr);

$timingStatus = TimeService::getTimingStatus($selectedDate);
$isStoreAllowed = TimeService::isStoreEditAllowed($selectedDate);
$activeOverride = TimeService::getActiveDateOverride($selectedDate);

// Check if any past date has an active override right now to alert store user
$allActiveOverrides = Database::query("SELECT * FROM admin_date_overrides WHERE status = 'OPEN' AND expires_at > NOW() ORDER BY override_date DESC");

// Fetch users with requisitions for selected date
$usersList = StoreService::getUsersWithRequisitions($selectedDate);

// Determine active user
$selectedUserId = isset($_GET['user_id']) ? (int)$_GET['user_id'] : 0;
if ($selectedUserId <= 0 && !empty($usersList)) {
    $selectedUserId = (int)$usersList[0]['id'];
}

// Fetch active user's full Master Requisition
$activeRequisition = null;
if ($selectedUserId > 0) {
    $masterReq = Database::queryOne("SELECT id FROM requisitions WHERE user_id = :uid AND requisition_date = :date LIMIT 1", [
        ':uid'  => $selectedUserId,
        ':date' => $selectedDate
    ]);
    if ($masterReq) {
        $activeRequisition = RequisitionService::formatFullRequisition((int)$masterReq['id']);
        
        // Auto-sort items within each sub-requisition so PENDING items always appear at the top
        if ($activeRequisition && !empty($activeRequisition['sub_requisitions'])) {
            foreach ($activeRequisition['sub_requisitions'] as &$sub) {
                usort($sub['items'], function ($a, $b) {
                    $order = ['PENDING' => 1, 'PARTIALLY_ISSUED' => 2, 'NOT_AVAILABLE' => 3, 'ISSUED' => 4];
                    $rankA = $order[$a['status']] ?? 5;
                    $rankB = $order[$b['status']] ?? 5;
                    return $rankA <=> $rankB;
                });
            }
            unset($sub);
        }
    }
}

// Global Master Materials and Locations for Emergency Modal
$allUsers = Database::query("SELECT id, name, employee_code FROM users WHERE status = 'ACTIVE' AND role = 'REQUISITION_USER' ORDER BY name ASC");
$allMaterials = Database::query("SELECT id, name, unit, default_rate, COALESCE(current_stock, 0) AS current_stock FROM materials WHERE status = 'ACTIVE' ORDER BY name ASC");
$allLocations = Database::query("SELECT id, name, code FROM locations WHERE status = 'ACTIVE' ORDER BY name ASC");

// Calculate aggregate metrics
$totalItemsCount = 0;
$pendingCount = 0;
$issuedCount = 0;
$partialCount = 0;
$notAvailableCount = 0;
$totalReqQty = 0;
$totalIssQty = 0;

if ($activeRequisition) {
    $totalItemsCount = $activeRequisition['stats']['total_items'];
    $pendingCount = $activeRequisition['stats']['pending_count'];
    $issuedCount = $activeRequisition['stats']['issued_count'];
    $partialCount = $activeRequisition['stats']['partial_count'];
    $notAvailableCount = $activeRequisition['stats']['not_available_count'];
    $totalIssQty = $activeRequisition['stats']['total_issued_qty'];

    foreach ($activeRequisition['sub_requisitions'] as $sub) {
        foreach ($sub['items'] as $it) {
            $totalReqQty += $it['requested_quantity'];
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Store Workspace - <?= htmlspecialchars(Config::get('APP_NAME')) ?></title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="/assets/css/store.css">
</head>
<body>

<div class="app-container">
    <!-- Sidebar -->
    <?php require __DIR__ . '/includes/sidebar.php'; ?>

    <!-- Main Workspace -->
    <div class="main-wrapper">
        <!-- Top Navbar -->
        <header class="top-navbar">
            <div class="nav-left">
                <button class="menu-toggle" aria-label="Toggle Menu">☰</button>
                <div class="nav-center-badges">
                    <!-- Date Selector Control -->
                    <form method="GET" action="/store/index.php" class="date-selector-form">
                        <div class="date-selector-container">
                            <span>📅 Date:</span>
                            <input type="date" name="date" value="<?= htmlspecialchars($selectedDate) ?>" max="<?= $todayStr ?>" onchange="this.form.submit()" class="store-date-input">
                        </div>
                        <a href="/store/index.php?date=<?= $todayStr ?>" class="quick-date-btn <?= $isToday ? 'active' : '' ?>">Today</a>
                        <a href="/store/index.php?date=<?= date('Y-m-d', strtotime('-1 day')) ?>" class="quick-date-btn <?= ($selectedDate === date('Y-m-d', strtotime('-1 day'))) ? 'active' : '' ?>">Yesterday</a>
                    </form>

                    <div class="header-badge" id="header-clock">
                        Current Time: <?= date('h:i A, d M Y') ?>
                    </div>
                </div>
            </div>

            <div class="nav-right">
                <?php if (!empty($allActiveOverrides) && $selectedDate !== $allActiveOverrides[0]['override_date']): ?>
                    <?php $ov = $allActiveOverrides[0]; ?>
                    <a href="/store/index.php?date=<?= urlencode($ov['override_date']) ?>" class="override-badge-pill" title="Click to view override date">
                        ⚡ Active Override: <?= date('d M', strtotime($ov['override_date'])) ?> (Till <?= date('h:i A', strtotime($ov['expires_at'])) ?>) &rarr;
                    </a>
                <?php endif; ?>

                <?php if ($pendingCount > 0): ?>
                    <div class="pending-alert-badge">
                        ⚡ <?= $pendingCount ?> Items Pending Action
                    </div>
                <?php else: ?>
                    <div class="done-alert-badge">
                        ✓ All Items Processed
                    </div>
                <?php endif; ?>

                <div class="user-profile-widget">
                    <div class="avatar-circle">👤</div>
                    <span class="user-name-text"><?= htmlspecialchars($currentUser['name'] ?? 'Store Incharge') ?></span>
                </div>
            </div>
        </header>

        <!-- User Selector Bar -->
        <div class="user-selector-container">
            <span class="selector-label">👥 Select User (<?= date('d M Y', strtotime($selectedDate)) ?>):</span>
            <div class="user-pills-wrapper">
                <?php foreach ($usersList as $u): ?>
                    <?php 
                        $isSel = ((int)$u['id'] === $selectedUserId);
                        $uPending = (int)($u['pending_count'] ?? 0);
                    ?>
                    <a href="/store/index.php?user_id=<?= $u['id'] ?>&date=<?= urlencode($selectedDate) ?>" class="user-pill <?= $isSel ? 'active' : '' ?>">
                        <span class="pill-avatar"><?= strtoupper(substr($u['name'], 0, 1)) ?></span>
                        <span class="pill-name"><?= htmlspecialchars($u['name']) ?></span>
                        <?php if ($uPending > 0): ?>
                            <span class="pill-badge-pending">⚡ <?= $uPending ?> Pending</span>
                        <?php else: ?>
                            <span class="pill-badge-done">✓ Done</span>
                        <?php endif; ?>
                    </a>
                <?php endforeach; ?>
                <?php if (empty($usersList)): ?>
                    <span style="font-size: 13px; color: var(--text-muted); padding: 8px 14px;">
                        ℹ️ No user requisitions found for <?= date('d M Y', strtotime($selectedDate)) ?>.
                    </span>
                <?php endif; ?>
            </div>
        </div>

        <!-- Main Body -->
        <main class="dashboard-body">
            <!-- Active Override or Locked Past Date Status Banner -->
            <?php if (!$isToday): ?>
                <?php if ($isStoreAllowed && $activeOverride): ?>
                    <div class="override-alert-banner">
                        <div>
                            🔓 <strong>Admin Date Override Active:</strong> Store fulfillment is enabled for <strong><?= date('d M Y', strtotime($selectedDate)) ?></strong> until <strong><?= date('h:i A', strtotime($activeOverride['expires_at'])) ?></strong>.
                            <span style="font-size: 12px; color: #166534; margin-left: 8px;">(Reason: <?= htmlspecialchars($activeOverride['reason']) ?>)</span>
                        </div>
                        <span style="background: #15803d; color: #fff; padding: 2px 8px; border-radius: 4px; font-size: 11px; font-weight: 700;">UNLOCKED</span>
                    </div>
                <?php elseif (!$isStoreAllowed): ?>
                    <div class="override-alert-banner locked">
                        <div>
                            🔒 <strong>Read-Only Mode (Date: <?= date('d M Y', strtotime($selectedDate)) ?>):</strong> Store editing window is closed for this date.
                            <span style="font-size: 12px; margin-left: 6px;">To make changes or issue materials, contact Admin to open a 2-Hour Date Override from the Admin Panel.</span>
                        </div>
                        <span style="background: #b45309; color: #fff; padding: 2px 8px; border-radius: 4px; font-size: 11px; font-weight: 700;">LOCKED</span>
                    </div>
                <?php endif; ?>
            <?php endif; ?>

            <!-- Filter & Search Toolbar -->
            <div class="workspace-toolbar-card">
                <div class="toolbar-left">
                    <span class="toolbar-title">Filter by Status:</span>
                    <div class="filter-tabs-group">
                        <button type="button" class="filter-tab-btn <?= $pendingCount > 0 ? 'active' : '' ?>" onclick="filterByStatus('PENDING', this)" style="border-color: #fde68a;">
                            ⏳ Pending Action <strong>(<?= $pendingCount ?>)</strong>
                        </button>
                        <button type="button" class="filter-tab-btn" onclick="filterByStatus('ALL', this)">
                            📋 All Items <strong>(<?= $totalItemsCount ?>)</strong>
                        </button>
                        <button type="button" class="filter-tab-btn" onclick="filterByStatus('ISSUED', this)">
                            ✅ Full Issued <strong>(<?= $issuedCount ?>)</strong>
                        </button>
                        <button type="button" class="filter-tab-btn" onclick="filterByStatus('PARTIALLY_ISSUED', this)">
                            ⚠️ Partial <strong>(<?= $partialCount ?>)</strong>
                        </button>
                        <button type="button" class="filter-tab-btn" onclick="filterByStatus('NOT_AVAILABLE', this)">
                            ❌ Not Available <strong>(<?= $notAvailableCount ?>)</strong>
                        </button>
                    </div>
                </div>

                <div class="toolbar-right">
                    <div class="search-input-wrapper">
                        <span class="search-icon">🔍</span>
                        <input type="text" id="table-search-input" placeholder="Quick search material, code, remark..." class="search-input">
                    </div>
                    <?php if ($isStoreAllowed): ?>
                        <button class="btn-primary" onclick="openModal('emergency-modal')" style="padding: 8px 14px; font-size: 13px; display: flex; align-items: center; gap: 6px;">
                            <span>⚡</span> Emergency Issue
                        </button>
                    <?php endif; ?>
                </div>
            </div>

            <!-- Workspace Layout -->
            <div class="main-workspace-grid">
                <!-- Left: Requisition & Item Cards -->
                <div class="requisition-work-area">
                    <?php if ($activeRequisition): ?>
                        <!-- Master Requisition Header -->
                        <div class="master-header-card">
                            <div class="master-header-left">
                                <div class="user-large-avatar">
                                    <?= strtoupper(substr($activeRequisition['user_name'], 0, 1)) ?>
                                </div>
                                <div class="user-meta-details">
                                    <h3><?= htmlspecialchars($activeRequisition['user_name']) ?></h3>
                                    <div class="req-no-tag" id="copy-req-no" data-req-no="<?= htmlspecialchars($activeRequisition['requisition_no']) ?>" title="Click to copy">
                                        Requisition No: <strong><?= htmlspecialchars($activeRequisition['requisition_no']) ?></strong> 📋
                                    </div>
                                </div>
                            </div>

                            <div class="master-header-meta">
                                <div class="meta-block">
                                    <span class="meta-label">Requisition Date</span>
                                    <span class="meta-val"><?= date('d M Y', strtotime($activeRequisition['requisition_date'])) ?></span>
                                </div>
                                <div class="meta-block">
                                    <span class="meta-label">Locations (Sites)</span>
                                    <span class="meta-val">📍 <?= count($activeRequisition['sub_requisitions']) ?> Locations</span>
                                </div>
                                <div class="meta-block">
                                    <span class="meta-label">Pending / Total Items</span>
                                    <span class="meta-val" style="color: <?= $pendingCount > 0 ? '#d97706' : '#16a34a' ?>; font-weight: 800;">
                                        <?= $pendingCount ?> Pending / <?= $totalItemsCount ?> Total
                                    </span>
                                </div>
                            </div>
                        </div>

                        <!-- Sub-Requisitions & Item Tables -->
                        <?php foreach ($activeRequisition['sub_requisitions'] as $idx => $sub): ?>
                            <?php 
                                $subPendingCount = 0;
                                foreach ($sub['items'] as $it) {
                                    if ($it['status'] === 'PENDING') $subPendingCount++;
                                }
                            ?>
                            <div class="sub-requisition-card" id="sub-card-<?= $sub['id'] ?>" data-sub-id="<?= $sub['id'] ?>">
                                <div class="sub-card-header">
                                    <div class="sub-header-title">
                                        <span class="sub-req-badge">Sub-Req: <?= htmlspecialchars($sub['sub_requisition_no']) ?></span>
                                        <span class="loc-pill-tag">📍 <?= htmlspecialchars($sub['location_name']) ?></span>
                                        <?php if ($subPendingCount > 0): ?>
                                            <span class="pending-count-chip">⏳ <?= $subPendingCount ?> items need action</span>
                                        <?php else: ?>
                                            <span class="done-count-chip">✓ All processed</span>
                                        <?php endif; ?>
                                    </div>
                                    
                                    <div class="sub-header-actions">
                                        <?php if ($isStoreAllowed && $subPendingCount > 0): ?>
                                            <button type="button" class="btn-quick-bulk" onclick="issueAllPendingInSub(<?= $sub['id'] ?>)">
                                                ⚡ Quick Issue All Pending (<?= $subPendingCount ?>)
                                            </button>
                                        <?php endif; ?>
                                    </div>
                                </div>

                                <div class="table-responsive">
                                    <table class="items-table">
                                        <thead>
                                            <tr>
                                                <th style="width: 40px;">#</th>
                                                <th>Material Details</th>
                                                <th style="text-align: center; width: 110px;">Requested</th>
                                                <th style="text-align: center; width: 130px;">Issued Quantity</th>
                                                <th style="width: 70px;">Unit</th>
                                                <th style="width: 220px;">Remarks & Notes</th>
                                                <th style="width: 140px; text-align: center;">Status</th>
                                                <th style="text-align: right; width: 180px;">Action Controls</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            <?php 
                                            $locReqTotal = 0;
                                            $locIssTotal = 0;
                                            foreach ($sub['items'] as $itemIdx => $item): 
                                                $locReqTotal += $item['requested_quantity'];
                                                $locIssTotal += $item['issued_quantity'];
                                                $isPending = ($item['status'] === 'PENDING');
                                                $isIssued = ($item['status'] === 'ISSUED');
                                                $isPartial = ($item['status'] === 'PARTIALLY_ISSUED');
                                                $isNa = ($item['status'] === 'NOT_AVAILABLE');
                                                $statusClass = strtolower($item['status']);
                                            ?>
                                                <tr class="item-row <?= $isPending ? 'pending-highlight' : 'processed-row' ?>" 
                                                    data-item-id="<?= $item['id'] ?>" 
                                                    data-item-status="<?= $item['status'] ?>"
                                                    data-req-qty="<?= $item['requested_quantity'] ?>" 
                                                    data-orig-issued="<?= $item['issued_quantity'] ?>">
                                                    
                                                    <td style="color: var(--text-muted); font-weight: 700; text-align: center;">
                                                        <?= $itemIdx + 1 ?>
                                                    </td>

                                                    <td>
                                                        <div class="material-name-cell">
                                                            <strong class="mat-name"><?= htmlspecialchars($item['material_name']) ?></strong>
                                                            <?php if ($item['is_emergency']): ?>
                                                                <span class="emergency-chip">🚨 EMERGENCY</span>
                                                            <?php endif; ?>
                                                        </div>
                                                        <?php if (!empty($item['material_code'])): ?>
                                                            <span class="item-code-sub">Code: <?= htmlspecialchars($item['material_code']) ?></span>
                                                        <?php endif; ?>
                                                    </td>

                                                    <td style="text-align: center; font-weight: 800; font-size: 14.5px; color: var(--text-main);">
                                                        <?= $item['requested_quantity'] ?>
                                                    </td>

                                                    <td style="text-align: center;">
                                                        <?php if ($isPending): ?>
                                                            <input type="number" step="any" min="0" max="<?= $item['requested_quantity'] ?>" 
                                                                   class="qty-input-box active-pending" 
                                                                   value="<?= $item['requested_quantity'] ?>" <?= !$isStoreAllowed ? 'disabled' : '' ?>>
                                                        <?php else: ?>
                                                            <input type="number" step="any" min="0" max="<?= $item['requested_quantity'] ?>" 
                                                                   class="qty-input-box" 
                                                                   value="<?= $item['issued_quantity'] ?>" <?= !$isStoreAllowed ? 'disabled' : '' ?>>
                                                        <?php endif; ?>
                                                    </td>

                                                    <td style="color: var(--text-muted); font-weight: 600;">
                                                        <?= htmlspecialchars($item['unit']) ?>
                                                    </td>

                                                    <!-- Separated Remarks Column -->
                                                    <td class="remarks-cell">
                                                        <?php if (!empty($item['remark'])): ?>
                                                            <div class="user-remark-bubble">
                                                                <span class="remark-label-user">👤 User:</span>
                                                                <span><?= htmlspecialchars($item['remark']) ?></span>
                                                            </div>
                                                        <?php endif; ?>
                                                        <?php if (!empty($item['store_remark'])): ?>
                                                            <div class="store-remark-bubble">
                                                                <span class="remark-label-store">🏪 Store Note:</span>
                                                                <span><?= htmlspecialchars($item['store_remark']) ?></span>
                                                            </div>
                                                        <?php endif; ?>
                                                        <?php if (empty($item['remark']) && empty($item['store_remark'])): ?>
                                                            <span style="color: var(--text-subtle); font-size: 12px;">No remarks</span>
                                                        <?php endif; ?>
                                                    </td>

                                                    <td style="text-align: center;">
                                                        <span class="status-badge <?= $statusClass ?>">
                                                            <?php if ($isPending): ?>⏳ PENDING<?php endif; ?>
                                                            <?php if ($isIssued): ?>✓ FULL ISSUED<?php endif; ?>
                                                            <?php if ($isPartial): ?>⚡ PARTIAL (<?= $item['issued_quantity'] ?>)<?php endif; ?>
                                                            <?php if ($isNa): ?>✕ NOT AVAILABLE<?php endif; ?>
                                                        </span>
                                                    </td>

                                                    <td style="text-align: right;">
                                                        <div class="action-btn-group">
                                                            <?php if (!$isStoreAllowed): ?>
                                                                <span style="font-size: 11px; color: var(--text-muted); font-weight: 600; padding: 4px 8px; background: #f1f5f9; border-radius: 4px;">🔒 Read Only</span>
                                                            <?php elseif ($isPending): ?>
                                                                <button type="button" class="btn-action-issue" onclick="issueFullQty(<?= $item['id'] ?>, <?= $item['requested_quantity'] ?>)" title="Issue Full Quantity">
                                                                    ✓ Issue
                                                                </button>
                                                                <button type="button" class="btn-action-partial" onclick="issuePartialQty(<?= $item['id'] ?>, <?= $item['requested_quantity'] ?>)" title="Issue Partial Quantity">
                                                                    Partial
                                                                </button>
                                                                <button type="button" class="btn-action-na" onclick="markNotAvailable(<?= $item['id'] ?>)" title="Mark Not Available">
                                                                    ✕ N/A
                                                                </button>
                                                            <?php else: ?>
                                                                <button type="button" class="btn-action-edit" onclick="issuePartialQty(<?= $item['id'] ?>, <?= $item['requested_quantity'] ?>)" title="Edit Quantity">
                                                                    ✏️ Edit
                                                                </button>
                                                                <button type="button" class="btn-action-na-sm" onclick="markNotAvailable(<?= $item['id'] ?>)" title="Mark Unavailable">
                                                                    ✕
                                                                </button>
                                                            <?php endif; ?>
                                                        </div>
                                                    </td>
                                                </tr>
                                            <?php endforeach; ?>
                                        </tbody>
                                    </table>
                                </div>

                                <div class="sub-empty-filter-notice" style="display: none; padding: 20px; text-align: center; color: var(--text-muted); font-size: 13px;">
                                    No items match the selected filter in this location.
                                </div>

                                <div class="sub-card-footer">
                                    <div class="sub-footer-totals">
                                        <span>Location Totals:</span>
                                        <span>Requested: <strong><?= $locReqTotal ?></strong></span>
                                        <span>Issued: <strong style="color: #16a34a;"><?= $locIssTotal ?></strong></span>
                                    </div>
                                    <?php if ($isStoreAllowed): ?>
                                        <button class="btn-save-changes" onclick="saveLocationChanges(<?= $sub['id'] ?>)">
                                            💾 Save Table Quantities
                                        </button>
                                    <?php endif; ?>
                                </div>
                            </div>
                        <?php endforeach; ?>

                    <?php else: ?>
                        <!-- Empty State -->
                        <div class="empty-state-card">
                            <div class="empty-state-icon">📋</div>
                            <h3>No Active Requisition Selected</h3>
                            <p>Select a user from the top bar to view and fulfill their daily requisitions.</p>
                        </div>
                    <?php endif; ?>
                </div>
            </div>
        </main>
    </div>
</div>

<!-- ================= EMERGENCY ISSUE MODAL ================= -->
<div class="modal-backdrop" id="emergency-modal">
    <div class="modal-dialog">
        <div class="modal-header">
            <h3>⚡ Direct Emergency Material Issue</h3>
            <button class="modal-close-btn" aria-label="Close">&times;</button>
        </div>
        <form onsubmit="submitEmergencyIssue(event)">
            <div class="modal-body">
                <div class="form-group">
                    <label>Employee / User *</label>
                    <select name="user_id" class="form-control" required>
                        <option value="">-- Select Employee --</option>
                        <?php foreach ($allUsers as $u): ?>
                            <option value="<?= $u['id'] ?>" <?= ((int)$u['id'] === $selectedUserId) ? 'selected' : '' ?>>
                                <?= htmlspecialchars($u['name']) ?> (<?= htmlspecialchars($u['employee_code']) ?>)
                            </option>
                        <?php endforeach; ?>
                    </select>
                </div>

                <div class="form-group">
                    <label>Material *</label>
                    <select name="material_id" class="form-control" required>
                        <option value="">-- Select Material --</option>
                        <?php foreach ($allMaterials as $m): ?>
                            <option value="<?= $m['id'] ?>">
                                <?= htmlspecialchars($m['name']) ?> (<?= htmlspecialchars($m['unit']) ?>) - ₹<?= number_format($m['default_rate'], 2) ?>
                            </option>
                        <?php endforeach; ?>
                    </select>
                </div>

                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 14px;">
                    <div class="form-group">
                        <label>Issued Quantity *</label>
                        <input type="number" step="any" min="0.01" name="quantity" class="form-control" placeholder="e.g. 5" required>
                    </div>
                    <div class="form-group">
                        <label>Location / Site *</label>
                        <select name="location_id" class="form-control" required>
                            <option value="">-- Select Site --</option>
                            <?php foreach ($allLocations as $l): ?>
                                <option value="<?= $l['id'] ?>">
                                    <?= htmlspecialchars($l['name']) ?> (<?= htmlspecialchars($l['code']) ?>)
                                </option>
                            <?php endforeach; ?>
                        </select>
                    </div>
                </div>

                <div class="form-group">
                    <label>Reason for Emergency *</label>
                    <textarea name="reason" rows="2" class="form-control" placeholder="e.g. Pipe breakdown, urgent machine repair..." required></textarea>
                </div>

                <div class="form-group">
                    <label>Store Remark</label>
                    <input type="text" name="remark" class="form-control" placeholder="Optional remark...">
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn-modal-cancel">Cancel</button>
                <button type="submit" class="btn-primary" style="background: #dc2626;">Issue Emergency Material</button>
            </div>
        </form>
    </div>
</div>

<script src="/assets/js/app-modal.js"></script>
<script src="/assets/js/store.js"></script>
</body>
</html>
