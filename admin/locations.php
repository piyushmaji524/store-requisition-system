<?php
/**
 * ADMIN PANEL - LOCATIONS MASTER
 * Location CRUD, Tally Ledger mappings, Edit modal, Active/Inactive status toggle & filtering
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

$msg = $_GET['msg'] ?? null;
$error = null;

// 1. Handle Create Location
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['create_location'])) {
    $data = [
        'name'              => trim($_POST['name']),
        'code'              => trim($_POST['code']),
        'tally_ledger_name' => trim($_POST['tally_ledger_name']),
        'tally_ledger_code' => trim($_POST['tally_ledger_code']),
        'status'            => $_POST['status'] ?? 'ACTIVE'
    ];
    try {
        AdminService::saveLocation($data, null, (int)$currentUser['id']);
        header('Location: /admin/locations.php?msg=created');
        exit;
    } catch (Throwable $e) {
        $error = $e->getMessage();
    }
}

// 2. Handle Update Location (from Edit Modal)
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['update_location'])) {
    $locationId = (int)$_POST['location_id'];
    $data = [
        'name'              => trim($_POST['name']),
        'code'              => trim($_POST['code']),
        'tally_ledger_name' => trim($_POST['tally_ledger_name']),
        'tally_ledger_code' => trim($_POST['tally_ledger_code']),
        'status'            => $_POST['status'] ?? 'ACTIVE'
    ];
    try {
        AdminService::saveLocation($data, $locationId, (int)$currentUser['id']);
        header('Location: /admin/locations.php?msg=updated');
        exit;
    } catch (Throwable $e) {
        $error = $e->getMessage();
    }
}

// 3. Handle 1-Click Toggle Status (Active <-> Inactive)
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['toggle_status'])) {
    $locationId = (int)$_POST['location_id'];
    try {
        $newStatus = AdminService::toggleLocationStatus($locationId, (int)$currentUser['id']);
        header('Location: /admin/locations.php?msg=status_toggled');
        exit;
    } catch (Throwable $e) {
        $error = $e->getMessage();
    }
}

$locations = Database::query("SELECT * FROM locations ORDER BY name ASC");
$totalCount = count($locations);
$activeCount = count(array_filter($locations, fn($l) => $l['status'] === 'ACTIVE'));
$inactiveCount = $totalCount - $activeCount;
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Locations Master - <?= htmlspecialchars(Config::get('APP_NAME')) ?></title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="/assets/css/admin.css">
    <style>
        .filter-tab-bar {
            display: flex;
            gap: 8px;
            margin-bottom: 14px;
        }
        .tab-btn {
            padding: 7px 14px;
            border-radius: 8px;
            font-size: 13px;
            font-weight: 700;
            cursor: pointer;
            border: 1px solid transparent;
            background: #f1f5f9;
            color: #475569;
            transition: all 0.15s ease;
        }
        .tab-btn.active {
            background: #2563eb;
            color: #ffffff;
        }
        .btn-action-sm {
            padding: 4px 8px;
            font-size: 11.5px;
            font-weight: 700;
            border-radius: 6px;
            cursor: pointer;
            border: 1px solid transparent;
            display: inline-flex;
            align-items: center;
            gap: 4px;
            text-decoration: none;
            transition: all 0.15s ease;
        }
        .btn-edit { background: #eff6ff; color: #2563eb; border-color: #bfdbfe; }
        .btn-edit:hover { background: #2563eb; color: #ffffff; }
        .btn-deactivate { background: #fef2f2; color: #dc2626; border-color: #fecaca; }
        .btn-deactivate:hover { background: #dc2626; color: #ffffff; }
        .btn-activate { background: #f0fdf4; color: #16a34a; border-color: #bbf7d0; }
        .btn-activate:hover { background: #16a34a; color: #ffffff; }

        /* Modal styling */
        .modal-backdrop {
            position: fixed;
            top: 0; left: 0; width: 100vw; height: 100vh;
            background: rgba(15, 23, 42, 0.6);
            display: none;
            align-items: center;
            justify-content: center;
            z-index: 9999;
            backdrop-filter: blur(4px);
        }
        .modal-box {
            background: #ffffff;
            border-radius: 16px;
            width: 100%;
            max-width: 520px;
            box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
            overflow: hidden;
            animation: modalPop 0.2s ease-out;
        }
        @keyframes modalPop {
            from { transform: scale(0.95); opacity: 0; }
            to { transform: scale(1); opacity: 1; }
        }
        .modal-header {
            padding: 18px 24px;
            border-bottom: 1px solid #e2e8f0;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }
        .modal-body {
            padding: 24px;
        }
        .modal-footer {
            padding: 14px 24px;
            background: #f8fafc;
            border-top: 1px solid #e2e8f0;
            display: flex;
            justify-content: flex-end;
            gap: 10px;
        }
    </style>
</head>
<body>
<div class="app-container">
    <?php require __DIR__ . '/includes/sidebar.php'; ?>

    <div class="main-wrapper">
        <header class="top-navbar">
            <div class="nav-title-block">
                <h1>📍 Location Master & Tally Ledgers</h1>
                <p>Manage site locations, Tally Party Ledger mappings, and Active/Inactive status.</p>
            </div>
        </header>

        <main class="dashboard-content">
            <?php if ($msg === 'created'): ?>
                <div class="alert alert-success" style="margin-bottom: 20px;">
                    ✓ New site location registered successfully!
                </div>
            <?php elseif ($msg === 'updated'): ?>
                <div class="alert alert-success" style="margin-bottom: 20px;">
                    ✓ Location details updated successfully!
                </div>
            <?php elseif ($msg === 'status_toggled'): ?>
                <div class="alert alert-success" style="margin-bottom: 20px;">
                    ✓ Location status updated! Inactive locations are completely hidden when users create requisitions.
                </div>
            <?php endif; ?>

            <?php if ($error): ?>
                <div class="alert alert-danger" style="margin-bottom: 20px;">
                    <strong>✕ Error:</strong> <?= htmlspecialchars($error) ?>
                </div>
            <?php endif; ?>

            <!-- Add Location Form -->
            <div class="card-box" style="margin-bottom: 20px;">
                <div class="card-box-header">
                    <span class="card-box-title">+ Add New Location</span>
                </div>
                <form method="POST" style="display: grid; grid-template-columns: 2fr 1fr 2fr 1fr auto; gap: 12px; align-items: flex-end;">
                    <input type="hidden" name="create_location" value="1">
                    <div class="form-group">
                        <label style="font-size: 12px; font-weight: 600;">Location Name *</label>
                        <input type="text" name="name" class="form-control" placeholder="e.g. Manali Site Maintenance" required>
                    </div>
                    <div class="form-group">
                        <label style="font-size: 12px; font-weight: 600;">Location Code *</label>
                        <input type="text" name="code" class="form-control" placeholder="LOC-06" required>
                    </div>
                    <div class="form-group">
                        <label style="font-size: 12px; font-weight: 600;">Tally Party Ledger Name *</label>
                        <input type="text" name="tally_ledger_name" class="form-control" placeholder="Manali Site Maintenance" required>
                    </div>
                    <div class="form-group">
                        <label style="font-size: 12px; font-weight: 600;">Tally Ledger Code</label>
                        <input type="text" name="tally_ledger_code" class="form-control" placeholder="LED-MN-06">
                    </div>
                    <button type="submit" class="btn-open-override" style="margin: 0; padding: 9px 18px; background: #2563eb;">
                        Add Location
                    </button>
                </form>
            </div>

            <!-- Locations Table Card -->
            <div class="table-card">
                <div class="table-header-bar" style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 12px;">
                    <div>
                        <span style="font-size: 15px; font-weight: 800;">Location Catalog (<?= $totalCount ?> Locations)</span>
                        <p style="font-size: 12px; color: var(--text-muted); margin: 2px 0 0 0;">
                            Inactive locations are hidden from User & Store requisition dropdowns.
                        </p>
                    </div>
                    <input type="text" id="locSearch" placeholder="🔍 Search location name, code, ledger..." onkeyup="filterLocations()" style="padding: 7px 14px; border-radius: 8px; border: 1px solid #cbd5e1; font-size: 13px; width: 300px;">
                </div>

                <!-- Status Filter Tabs -->
                <div style="padding: 12px 18px 0 18px; background: #ffffff;">
                    <div class="filter-tab-bar">
                        <button type="button" class="tab-btn active" onclick="setTab('ALL', this)">All Locations (<?= $totalCount ?>)</button>
                        <button type="button" class="tab-btn" onclick="setTab('ACTIVE', this)">🟢 Active (<?= $activeCount ?>)</button>
                        <button type="button" class="tab-btn" onclick="setTab('INACTIVE', this)">🔴 Inactive / Disabled (<?= $inactiveCount ?>)</button>
                    </div>
                </div>

                <div class="table-responsive">
                    <table class="admin-table" id="locTable">
                        <thead>
                            <tr style="background: #f8fafc;">
                                <th style="width: 45px;">#</th>
                                <th style="width: 110px;">Code</th>
                                <th>Location Name</th>
                                <th>Tally Ledger Name</th>
                                <th style="width: 140px;">Tally Ledger Code</th>
                                <th style="width: 100px; text-align: center;">Status</th>
                                <th style="width: 180px; text-align: center;">Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php foreach ($locations as $idx => $loc): 
                                $isActive = ($loc['status'] === 'ACTIVE');
                            ?>
                                <tr class="loc-row" data-status="<?= $loc['status'] ?>" data-search="<?= strtolower(htmlspecialchars($loc['name'] . ' ' . $loc['code'] . ' ' . $loc['tally_ledger_name'])) ?>">
                                    <td style="color: var(--text-muted); font-size: 11.5px;"><?= $idx + 1 ?></td>
                                    <td><code><?= htmlspecialchars($loc['code']) ?></code></td>
                                    <td><strong style="color: <?= $isActive ? '#0f172a' : '#94a3b8' ?>; font-size: 13.5px;"><?= htmlspecialchars($loc['name']) ?></strong></td>
                                    <td><?= htmlspecialchars($loc['tally_ledger_name']) ?></td>
                                    <td><code><?= htmlspecialchars($loc['tally_ledger_code'] ?: '-') ?></code></td>
                                    <td style="text-align: center;">
                                        <?php if ($isActive): ?>
                                            <span style="font-size: 11px; font-weight: 800; padding: 3px 8px; border-radius: 6px; background: #dcfce7; color: #15803d; border: 1px solid #86efac;">
                                                ACTIVE
                                            </span>
                                        <?php else: ?>
                                            <span style="font-size: 11px; font-weight: 800; padding: 3px 8px; border-radius: 6px; background: #fee2e2; color: #b91c1c; border: 1px solid #fca5a5;">
                                                INACTIVE
                                            </span>
                                        <?php endif; ?>
                                    </td>
                                    <td style="text-align: center;">
                                        <div style="display: inline-flex; gap: 6px;">
                                            <!-- Edit Button -->
                                            <button type="button" class="btn-action-sm btn-edit" onclick="openEditModal(<?= htmlspecialchars(json_encode($loc)) ?>)">
                                                ✏️ Edit
                                            </button>

                                            <!-- 1-Click Status Toggle -->
                                            <form method="POST" style="margin: 0;" onsubmit="return confirm('Kya aap is location ko <?= $isActive ? 'DEACTIVATE' : 'ACTIVATE' ?> karna chahte hain?')">
                                                <input type="hidden" name="toggle_status" value="1">
                                                <input type="hidden" name="location_id" value="<?= $loc['id'] ?>">
                                                <?php if ($isActive): ?>
                                                    <button type="submit" class="btn-action-sm btn-deactivate" title="Hide from requisition creation">
                                                        Deactivate
                                                    </button>
                                                <?php else: ?>
                                                    <button type="submit" class="btn-action-sm btn-activate" title="Make available for requisitions">
                                                        Activate
                                                    </button>
                                                <?php endif; ?>
                                            </form>
                                        </div>
                                    </td>
                                </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            </div>
        </main>
    </div>
</div>

<!-- EDIT LOCATION MODAL -->
<div class="modal-backdrop" id="editLocationModal">
    <div class="modal-box">
        <form method="POST" action="/admin/locations.php">
            <input type="hidden" name="update_location" value="1">
            <input type="hidden" name="location_id" id="edit_id">

            <div class="modal-header">
                <h3 style="font-size: 16px; font-weight: 800; color: #0f172a; margin: 0;">✏️ Edit Site Location</h3>
                <button type="button" onclick="closeEditModal()" style="background: none; border: none; font-size: 20px; cursor: pointer; color: #64748b;">✕</button>
            </div>

            <div class="modal-body">
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 14px;">
                    <div class="form-group" style="grid-column: span 2;">
                        <label style="font-size: 12px; font-weight: 600;">Location Name *</label>
                        <input type="text" name="name" id="edit_name" class="form-control" required>
                    </div>
                    <div class="form-group">
                        <label style="font-size: 12px; font-weight: 600;">Location Code *</label>
                        <input type="text" name="code" id="edit_code" class="form-control" required>
                    </div>
                    <div class="form-group">
                        <label style="font-size: 12px; font-weight: 600;">Status *</label>
                        <select name="status" id="edit_status" class="form-control" style="font-weight: 700;">
                            <option value="ACTIVE">🟢 ACTIVE (Shown in Requisitions)</option>
                            <option value="INACTIVE">🔴 INACTIVE (Hidden from Requisitions)</option>
                        </select>
                    </div>
                    <div class="form-group" style="grid-column: span 2;">
                        <label style="font-size: 12px; font-weight: 600;">Tally Party Ledger Name *</label>
                        <input type="text" name="tally_ledger_name" id="edit_tally_name" class="form-control" required>
                    </div>
                    <div class="form-group" style="grid-column: span 2;">
                        <label style="font-size: 12px; font-weight: 600;">Tally Ledger Code</label>
                        <input type="text" name="tally_ledger_code" id="edit_tally_code" class="form-control">
                    </div>
                </div>
            </div>

            <div class="modal-footer">
                <button type="button" onclick="closeEditModal()" class="btn-outline-action" style="padding: 8px 16px;">Cancel</button>
                <button type="submit" class="btn-open-override" style="background: #2563eb; padding: 8px 20px; font-weight: 800;">Save Changes</button>
            </div>
        </form>
    </div>
</div>

<script>
let currentStatusTab = 'ALL';

function setTab(tab, btn) {
    currentStatusTab = tab;
    document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    filterLocations();
}

function filterLocations() {
    const q = document.getElementById('locSearch').value.toLowerCase().trim();
    const rows = document.querySelectorAll('.loc-row');
    rows.forEach(r => {
        const rowStatus = r.getAttribute('data-status');
        const rowSearch = r.getAttribute('data-search');

        const matchesTab = (currentStatusTab === 'ALL' || rowStatus === currentStatusTab);
        const matchesSearch = (!q || rowSearch.includes(q));

        if (matchesTab && matchesSearch) {
            r.style.display = '';
        } else {
            r.style.display = 'none';
        }
    });
}

function openEditModal(loc) {
    document.getElementById('edit_id').value = loc.id;
    document.getElementById('edit_name').value = loc.name || '';
    document.getElementById('edit_code').value = loc.code || '';
    document.getElementById('edit_tally_name').value = loc.tally_ledger_name || loc.name || '';
    document.getElementById('edit_tally_code').value = loc.tally_ledger_code || '';
    document.getElementById('edit_status').value = loc.status || 'ACTIVE';

    const modal = document.getElementById('editLocationModal');
    modal.style.display = 'flex';
}

function closeEditModal() {
    document.getElementById('editLocationModal').style.display = 'none';
}

window.onclick = function(event) {
    const modal = document.getElementById('editLocationModal');
    if (event.target === modal) {
        closeEditModal();
    }
};
</script>
</body>
</html>
