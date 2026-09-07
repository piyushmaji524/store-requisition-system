<?php
/**
 * ADMIN PANEL - SYSTEM SETTINGS
 * Central management of window timings, override durations, timezones, and Tally export parameters
 */

require_once __DIR__ . '/../config/config.php';
require_once __DIR__ . '/../core/Database.php';
require_once __DIR__ . '/../core/Session.php';
require_once __DIR__ . '/../core/Auth.php';
require_once __DIR__ . '/../core/Logger.php';
require_once __DIR__ . '/../services/TimeService.php';

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

$successMsg = '';
$errorMsg = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    try {
        if (!empty($_POST['settings']) && is_array($_POST['settings'])) {
            $updatedKeys = [];
            foreach ($_POST['settings'] as $key => $val) {
                $cleanKey = trim($key);
                $cleanVal = trim((string)$val);
                
                $sql = "INSERT INTO settings (setting_key, setting_value, updated_by, updated_at)
                        VALUES (:k, :v, :uid, NOW())
                        ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value), updated_by = VALUES(updated_by), updated_at = NOW()";
                Database::execute($sql, [
                    ':k'   => $cleanKey,
                    ':v'   => $cleanVal,
                    ':uid' => $currentUser['id']
                ]);
                $updatedKeys[$cleanKey] = $cleanVal;
            }

            // Immediately reload memory cache
            Config::reload();

            Logger::logActivity($currentUser['id'], 'SETTINGS_UPDATED', 'settings', 'GLOBAL', null, $updatedKeys);
            $successMsg = 'All settings saved and applied to system successfully!';
        }
    } catch (Throwable $e) {
        $errorMsg = 'Error saving settings: ' . $e->getMessage();
    }
}

// Reload fresh settings
Config::reload();
$dbSettings = Database::query("SELECT * FROM settings ORDER BY setting_key ASC");
$settingsMap = [];
foreach ($dbSettings as $s) {
    $settingsMap[$s['setting_key']] = $s['setting_value'];
}

$timingStatus = TimeService::getTimingStatus();
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Settings - <?= htmlspecialchars(Config::get('APP_NAME')) ?></title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="/assets/css/admin.css">
</head>
<body>
<div class="app-container">
    <?php require __DIR__ . '/includes/sidebar.php'; ?>

    <div class="main-wrapper">
        <header class="top-navbar">
            <div class="nav-title-block">
                <h1>⚙️ System Settings & Business Windows</h1>
                <p>Configure operational cut-offs, admin override durations, timezone, and Tally defaults.</p>
            </div>
        </header>

        <main class="dashboard-content">
            <?php if (!empty($successMsg)): ?>
                <div style="background: #dcfce7; color: #15803d; border: 1px solid #bbf7d0; padding: 12px 16px; border-radius: 8px; font-weight: 700; margin-bottom: 20px; display: flex; align-items: center; gap: 8px;">
                    <span>✓</span> <?= htmlspecialchars($successMsg) ?>
                </div>
            <?php endif; ?>

            <?php if (!empty($errorMsg)): ?>
                <div style="background: #fee2e2; color: #b91c1c; border: 1px solid #fecaca; padding: 12px 16px; border-radius: 8px; font-weight: 700; margin-bottom: 20px; display: flex; align-items: center; gap: 8px;">
                    <span>⚠️</span> <?= htmlspecialchars($errorMsg) ?>
                </div>
            <?php endif; ?>

            <div style="display: grid; grid-template-columns: 1fr 340px; gap: 24px; align-items: start;">
                <!-- Main Settings Form -->
                <div class="card-box">
                    <div class="card-box-header" style="margin-bottom: 20px;">
                        <span class="card-box-title">System Configurations</span>
                    </div>

                    <form method="POST">
                        <div class="form-group" style="margin-bottom: 18px;">
                            <label style="font-weight: 700; font-size: 13px;">Application Title</label>
                            <input type="text" name="settings[APP_NAME]" value="<?= htmlspecialchars($settingsMap['APP_NAME'] ?? Config::get('APP_NAME')) ?>" class="form-control" required>
                        </div>

                        <div class="form-group" style="margin-bottom: 18px;">
                            <label style="font-weight: 700; font-size: 13px;">Timezone (Authoritative)</label>
                            <input type="text" name="settings[TIMEZONE]" value="<?= htmlspecialchars($settingsMap['TIMEZONE'] ?? 'Asia/Kolkata') ?>" class="form-control" readonly style="background: #f1f5f9; font-weight: 600;">
                            <small style="color: var(--text-muted); font-size: 11.5px; margin-top: 4px; display: block;">IST (Asia/Kolkata) is authoritative for all operational cutoffs and override timers.</small>
                        </div>

                        <hr style="border: none; border-top: 1px solid var(--border-color); margin: 20px 0;">
                        <h4 style="font-size: 14px; font-weight: 800; color: #0f172a; margin-bottom: 14px;">🕒 User Requisition Window (Staff Requests)</h4>

                        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-bottom: 18px;">
                            <div class="form-group">
                                <label style="font-weight: 700; font-size: 12.5px;">User Window Opens (IST)</label>
                                <input type="time" name="settings[USER_REQUEST_START]" value="<?= htmlspecialchars($settingsMap['USER_REQUEST_START'] ?? '06:00') ?>" class="form-control" required>
                            </div>
                            <div class="form-group">
                                <label style="font-weight: 700; font-size: 12.5px;">User Window Cut-off (IST)</label>
                                <input type="time" name="settings[USER_REQUEST_END]" value="<?= htmlspecialchars($settingsMap['USER_REQUEST_END'] ?? '20:00') ?>" class="form-control" required>
                            </div>
                        </div>

                        <hr style="border: none; border-top: 1px solid var(--border-color); margin: 20px 0;">
                        <h4 style="font-size: 14px; font-weight: 800; color: #0f172a; margin-bottom: 14px;">📦 Store Fulfillment & Admin Override</h4>

                        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-bottom: 18px;">
                            <div class="form-group">
                                <label style="font-weight: 700; font-size: 12.5px;">Store Start Time (IST)</label>
                                <input type="time" name="settings[STORE_EDIT_START]" value="<?= htmlspecialchars($settingsMap['STORE_EDIT_START'] ?? '06:00') ?>" class="form-control" required>
                            </div>
                            <div class="form-group">
                                <label style="font-weight: 700; font-size: 12.5px;">Store Daily Cut-off (IST)</label>
                                <input type="time" name="settings[STORE_EDIT_END]" value="<?= htmlspecialchars($settingsMap['STORE_EDIT_END'] ?? '21:00') ?>" class="form-control" required>
                            </div>
                        </div>

                        <div class="form-group" style="margin-bottom: 18px;">
                            <label style="font-weight: 700; font-size: 12.5px;">Admin Override Duration (Hours) *</label>
                            <div style="display: flex; align-items: center; gap: 10px;">
                                <input type="number" name="settings[ADMIN_OVERRIDE_HOURS]" value="<?= htmlspecialchars($settingsMap['ADMIN_OVERRIDE_HOURS'] ?? '2') ?>" class="form-control" min="1" max="24" style="max-width: 140px;" required>
                                <span style="font-size: 12.5px; color: #64748b; font-weight: 600;">Hours (e.g. 2, 3, 4, 6 hrs)</span>
                            </div>
                            <small style="color: var(--text-muted); font-size: 11.5px; margin-top: 4px; display: block;">When an admin reopens a past date, the override window will stay open for exactly this many hours.</small>
                        </div>

                        <hr style="border: none; border-top: 1px solid var(--border-color); margin: 20px 0;">
                        <h4 style="font-size: 14px; font-weight: 800; color: #0f172a; margin-bottom: 14px;">📑 Tally Accounting & Numbering Defaults</h4>

                        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-bottom: 24px;">
                            <div class="form-group">
                                <label style="font-weight: 700; font-size: 12.5px;">Default Sales Ledger Name</label>
                                <input type="text" name="settings[DEFAULT_SALES_LEDGER]" value="<?= htmlspecialchars($settingsMap['DEFAULT_SALES_LEDGER'] ?? 'SALE') ?>" class="form-control" required>
                                <small style="color: var(--text-muted); font-size: 11px;">Default sales credit ledger in Tally.</small>
                            </div>
                            <div class="form-group">
                                <label style="font-weight: 700; font-size: 12.5px;">Sub-Requisition Suffix Mode</label>
                                <select name="settings[SUB_REQ_SUFFIX_MODE]" class="form-control">
                                    <option value="SEQUENTIAL" <?= ($settingsMap['SUB_REQ_SUFFIX_MODE'] ?? 'SEQUENTIAL') === 'SEQUENTIAL' ? 'selected' : '' ?>>Sequential (/01, /02, /03)</option>
                                    <option value="LOCATION_CODE" <?= ($settingsMap['SUB_REQ_SUFFIX_MODE'] ?? 'SEQUENTIAL') === 'LOCATION_CODE' ? 'selected' : '' ?>>Location Code (/MB, /PH)</option>
                                </select>
                                <small style="color: var(--text-muted); font-size: 11px;">Voucher number suffix style.</small>
                            </div>
                        </div>

                        <button type="submit" class="btn-open-override" style="margin: 0; background: #2563eb; padding: 12px 28px; font-size: 14px; font-weight: 800;">
                            💾 Save & Apply All Settings
                        </button>
                    </form>
                </div>

                <!-- Live Status & Helper Card -->
                <div>
                    <div class="card-box" style="margin-bottom: 16px; background: #f8fafc; border: 1px solid #e2e8f0;">
                        <div class="card-box-header">
                            <span class="card-box-title" style="font-size: 14px;">🟢 Live Effective Rules</span>
                        </div>
                        <div style="font-size: 12.5px; display: flex; flex-direction: column; gap: 10px; margin-top: 8px;">
                            <div>
                                <span style="color: #64748b; font-weight: 600;">Server Time (IST):</span>
                                <div style="font-weight: 800; color: #0f172a;"><?= date('d M Y, h:i:s A', strtotime($timingStatus['server_time_ist'])) ?></div>
                            </div>
                            <div>
                                <span style="color: #64748b; font-weight: 600;">User Request Window:</span>
                                <div style="font-weight: 800; color: <?= $timingStatus['user_window']['is_open'] ? '#15803d' : '#b91c1c' ?>;">
                                    <?= $timingStatus['user_window']['display'] ?>
                                    (<?= $timingStatus['user_window']['is_open'] ? 'OPEN' : 'CLOSED' ?>)
                                </div>
                            </div>
                            <div>
                                <span style="color: #64748b; font-weight: 600;">Store Daily Window:</span>
                                <div style="font-weight: 800; color: #0f172a;">
                                    <?= $timingStatus['store_window']['display'] ?>
                                </div>
                            </div>
                            <div>
                                <span style="color: #64748b; font-weight: 600;">Active Override Duration:</span>
                                <div style="font-weight: 800; color: #2563eb;">
                                    <?= (int)Config::get('ADMIN_OVERRIDE_HOURS', 2) ?> Hours
                                </div>
                            </div>
                            <div>
                                <span style="color: #64748b; font-weight: 600;">Tally Sales Ledger:</span>
                                <div style="font-weight: 800; color: #0f172a;">
                                    <?= htmlspecialchars(Config::get('DEFAULT_SALES_LEDGER', 'SALE')) ?>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="card-box" style="font-size: 12px; color: #475569; line-height: 1.5;">
                        <strong style="color: #0f172a; display: block; margin-bottom: 6px;">💡 How Settings Work:</strong>
                        Changes saved here take effect <strong>instantly across the entire system</strong> (Admin Panel, Store App, User App, and REST APIs) without requiring any server restart.
                    </div>
                </div>
            </div>
        </main>
    </div>
</div>
</body>
</html>
