<?php
/**
 * ADMIN PANEL - DATE OVERRIDES MANAGER
 * Open any past date for 2 hours Store editing, view audit history, force close windows
 */

require_once __DIR__ . '/../config/config.php';
require_once __DIR__ . '/../core/Database.php';
require_once __DIR__ . '/../core/Session.php';
require_once __DIR__ . '/../core/Auth.php';
require_once __DIR__ . '/../services/AdminService.php';

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

$overrides = AdminService::listDateOverrides(50);
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Date Overrides - <?= htmlspecialchars(Config::get('APP_NAME')) ?></title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="/assets/css/admin.css">
</head>
<body>
<div class="app-container">
    <?php require __DIR__ . '/includes/sidebar.php'; ?>

    <div class="main-wrapper">
        <header class="top-navbar">
            <?php $overrideHours = (int) Config::get('ADMIN_OVERRIDE_HOURS', 2); ?>
            <div class="nav-title-block">
                <h1>🛡️ Admin Date Override Manager</h1>
                <p>Temporarily reopen past dates for Store editing (Default: <?= $overrideHours ?> hours).</p>
            </div>
        </header>

        <main class="dashboard-content">
            <!-- Create Override Card -->
            <div class="card-box" style="max-width: 580px;">
                <div class="card-box-header">
                    <span class="card-box-title">Create Temporary Override Window</span>
                </div>
                <form onsubmit="submitDateOverride(event)">
                    <div style="display: grid; grid-template-columns: 1fr 140px; gap: 12px; margin-bottom: 12px;">
                        <div class="form-group">
                            <label style="font-size: 12px; font-weight: 600;">Target Requisition Date *</label>
                            <input type="date" name="override_date" value="<?= date('Y-m-d', strtotime('-1 day')) ?>" class="form-control" required>
                        </div>
                        <div class="form-group">
                            <label style="font-size: 12px; font-weight: 600;">Duration</label>
                            <select name="duration_hours" class="form-control">
                                <?php for ($h = 1; $h <= 24; $h++): ?>
                                    <option value="<?= $h ?>" <?= $h === $overrideHours ? 'selected' : '' ?>><?= $h ?> Hour<?= $h > 1 ? 's' : '' ?></option>
                                <?php endfor; ?>
                            </select>
                        </div>
                    </div>
                    <div class="form-group" style="margin-bottom: 16px;">
                        <label style="font-size: 12px; font-weight: 600;">Reason for Override *</label>
                        <input type="text" name="reason" class="form-control" placeholder="e.g. Correction required in Tally voucher..." required>
                    </div>
                    <button type="submit" class="btn-open-override" style="margin-top: 0;">
                        🔓 Open Date Override Window (IST)
                    </button>
                </form>
            </div>

            <!-- Overrides History Table -->
            <div class="table-card" style="margin-top: 20px;">
                <div class="table-header-bar">
                    <span style="font-size: 14.5px; font-weight: 700;">Date Override Audit Trail</span>
                </div>
                <div class="table-responsive">
                    <table class="admin-table">
                        <thead>
                            <tr>
                                <th>#</th>
                                <th>Override Date</th>
                                <th>Opened By</th>
                                <th>Opened At</th>
                                <th>Expires At</th>
                                <th>Reason</th>
                                <th>Status</th>
                                <th style="text-align: center;">Action</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php if (empty($overrides)): ?>
                                <tr>
                                    <td colspan="8" style="text-align: center; padding: 28px; color: var(--text-muted);">
                                        No date override records created yet.
                                    </td>
                                </tr>
                            <?php else: ?>
                                <?php foreach ($overrides as $idx => $ov): ?>
                                    <tr>
                                        <td><?= $idx + 1 ?></td>
                                        <td><strong><?= date('d M Y', strtotime($ov['override_date'])) ?></strong></td>
                                        <td><?= htmlspecialchars($ov['opened_by_name']) ?></td>
                                        <td><?= date('d M Y, h:i A', strtotime($ov['opened_at'])) ?></td>
                                        <td><?= date('d M Y, h:i A', strtotime($ov['expires_at'])) ?></td>
                                        <td><em><?= htmlspecialchars($ov['reason']) ?></em></td>
                                        <td>
                                            <?php if ($ov['live_status'] === 'OPEN'): ?>
                                                <span style="background: #dcfce7; color: #15803d; font-weight: 700; padding: 3px 8px; border-radius: 4px; font-size: 11px;">OPEN (ACTIVE)</span>
                                            <?php else: ?>
                                                <span style="background: #f1f5f9; color: #64748b; font-weight: 600; padding: 3px 8px; border-radius: 4px; font-size: 11px;"><?= $ov['live_status'] ?></span>
                                            <?php endif; ?>
                                        </td>
                                        <td style="text-align: center;">
                                            <?php if ($ov['live_status'] === 'OPEN'): ?>
                                                <button onclick="closeDateOverride(<?= $ov['id'] ?>)" style="background: #fee2e2; color: #b91c1c; border: 1px solid #fecaca; border-radius: 4px; padding: 4px 10px; font-size: 12px; font-weight: 600; cursor: pointer;">
                                                    🔒 Force Close
                                                </button>
                                            <?php else: ?>
                                                <span style="color: var(--text-muted); font-size: 12px;">Closed</span>
                                            <?php endif; ?>
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

<script src="/assets/js/app-modal.js?v=<?= time() ?>"></script>
<script src="/assets/js/admin.js?v=<?= time() ?>"></script>
</body>
</html>
