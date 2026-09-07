<?php
/**
 * STORE PANEL - EMERGENCY ISSUES REGISTER
 * View, search, and record emergency issue transactions
 */

require_once __DIR__ . '/../config/config.php';
require_once __DIR__ . '/../core/Database.php';
require_once __DIR__ . '/../core/Session.php';
require_once __DIR__ . '/../core/Auth.php';
require_once __DIR__ . '/../services/StoreService.php';

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

$page = max(1, (int)($_GET['page'] ?? 1));
$emergencyData = StoreService::getEmergencyHistory($page, 20);

$allUsers = Database::query("SELECT id, name, employee_code FROM users WHERE status = 'ACTIVE' AND role = 'REQUISITION_USER' ORDER BY name ASC");
$allMaterials = Database::query("SELECT id, name, unit, default_rate, COALESCE(current_stock, 0) AS current_stock FROM materials WHERE status = 'ACTIVE' ORDER BY name ASC");
$allLocations = Database::query("SELECT id, name, code FROM locations WHERE status = 'ACTIVE' ORDER BY name ASC");
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Emergency Register - <?= htmlspecialchars(Config::get('APP_NAME')) ?></title>
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
                <h2 style="font-size: 18px; font-weight: 700; color: var(--text-main);">⚡ Emergency Issue Register</h2>
            </div>
            <div class="nav-right">
                <button class="btn-primary" onclick="openModal('emergency-modal')">
                    + New Emergency Issue
                </button>
            </div>
        </header>

        <main class="dashboard-body">
            <div class="sub-requisition-card">
                <div class="sub-card-header">
                    <span style="font-weight: 700;">Recorded Emergency Issues (Total: <?= $emergencyData['total_records'] ?>)</span>
                </div>
                <div class="table-responsive">
                    <table class="items-table">
                        <thead>
                            <tr>
                                <th>#</th>
                                <th>Date & Time</th>
                                <th>User</th>
                                <th>Material</th>
                                <th>Quantity</th>
                                <th>Location</th>
                                <th>Reason</th>
                                <th>Linked Requisition</th>
                                <th>Issued By</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php if (empty($emergencyData['items'])): ?>
                                <tr>
                                    <td colspan="9" style="text-align: center; padding: 36px; color: var(--text-muted);">
                                        No emergency issues recorded yet.
                                    </td>
                                </tr>
                            <?php else: ?>
                                <?php foreach ($emergencyData['items'] as $idx => $row): ?>
                                    <tr>
                                        <td><?= $idx + 1 ?></td>
                                        <td><?= date('d M Y, h:i A', strtotime($row['issued_at'])) ?></td>
                                        <td><strong><?= htmlspecialchars($row['user_name']) ?></strong> (<?= htmlspecialchars($row['employee_code']) ?>)</td>
                                        <td><strong><?= htmlspecialchars($row['material_name_snapshot']) ?></strong></td>
                                        <td><span style="font-weight: 700;"><?= $row['quantity'] ?></span> <?= htmlspecialchars($row['unit']) ?></td>
                                        <td><?= htmlspecialchars($row['location_name']) ?></td>
                                        <td><em style="color: var(--text-muted);"><?= htmlspecialchars($row['reason']) ?></em></td>
                                        <td>
                                            <?php if ($row['requisition_no']): ?>
                                                <a href="/store/index.php?user_id=<?= $row['user_id'] ?>" style="color: var(--primary); font-weight: 600; text-decoration: none;">
                                                    <?= htmlspecialchars($row['requisition_no']) ?>
                                                </a>
                                            <?php else: ?>
                                                <span style="color: var(--text-muted);">-</span>
                                            <?php endif; ?>
                                        </td>
                                        <td><?= htmlspecialchars($row['issued_by_name']) ?></td>
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

<!-- Modal for Emergency Issue -->
<div class="modal-backdrop" id="emergency-modal">
    <div class="modal-box">
        <div class="modal-header">
            <h4>⚡ Emergency Material Issue</h4>
            <button class="modal-close-btn">✕</button>
        </div>
        <form onsubmit="submitEmergencyIssue(event)">
            <div class="modal-body">
                <div class="form-group">
                    <label>Target User *</label>
                    <select name="user_id" class="form-control" required>
                        <option value="">-- Select User --</option>
                        <?php foreach ($allUsers as $u): ?>
                            <option value="<?= $u['id'] ?>"><?= htmlspecialchars($u['name']) ?> (<?= htmlspecialchars($u['employee_code']) ?>)</option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <div class="form-group">
                    <label>Material *</label>
                    <select name="material_id" class="form-control" required>
                        <option value="">-- Select Material --</option>
                        <?php foreach ($allMaterials as $m): ?>
                            <option value="<?= $m['id'] ?>"><?= htmlspecialchars($m['name']) ?> (Unit: <?= htmlspecialchars($m['unit']) ?>)</option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px;">
                    <div class="form-group">
                        <label>Quantity *</label>
                        <input type="number" name="quantity" step="any" min="0.01" class="form-control" placeholder="e.g. 10" required>
                    </div>
                    <div class="form-group">
                        <label>Location *</label>
                        <select name="location_id" class="form-control" required>
                            <option value="">-- Location --</option>
                            <?php foreach ($allLocations as $l): ?>
                                <option value="<?= $l['id'] ?>"><?= htmlspecialchars($l['name']) ?></option>
                            <?php endforeach; ?>
                        </select>
                    </div>
                </div>
                <div class="form-group">
                    <label>Emergency Reason *</label>
                    <textarea name="reason" class="form-control" rows="2" placeholder="Urgent requirement..." required></textarea>
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn-secondary btn-modal-cancel">Cancel</button>
                <button type="submit" class="btn-primary">⚡ Issue Material</button>
            </div>
        </form>
    </div>
</div>

<script src="/assets/js/app-modal.js"></script>
<script src="/assets/js/store.js"></script>
</body>
</html>
