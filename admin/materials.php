<?php
/**
 * ADMIN PANEL - MATERIALS MASTER
 * Material Master CRUD, default rates, units, stock, Tally mapping, Active/Inactive status toggle & modal editing
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

// 1. Handle Create Material
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['create_material'])) {
    $data = [
        'name'            => trim($_POST['name']),
        'code'            => trim($_POST['code']),
        'category_id'     => $_POST['category_id'] ? (int)$_POST['category_id'] : null,
        'unit'            => trim($_POST['unit']),
        'default_rate'    => (float)$_POST['default_rate'],
        'current_stock'   => (float)($_POST['current_stock'] ?? 0.0),
        'tally_item_name' => trim($_POST['tally_item_name']),
        'tally_item_code' => trim($_POST['tally_item_code']),
        'status'          => $_POST['status'] ?? 'ACTIVE'
    ];
    try {
        AdminService::saveMaterial($data, null, (int)$currentUser['id']);
        header('Location: /admin/materials.php?msg=created');
        exit;
    } catch (Throwable $e) {
        $error = $e->getMessage();
    }
}

// 2. Handle Update Material (from Edit Modal)
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['update_material'])) {
    $materialId = (int)$_POST['material_id'];
    $data = [
        'name'            => trim($_POST['name']),
        'code'            => trim($_POST['code']),
        'category_id'     => $_POST['category_id'] ? (int)$_POST['category_id'] : null,
        'unit'            => trim($_POST['unit']),
        'default_rate'    => (float)$_POST['default_rate'],
        'current_stock'   => (float)($_POST['current_stock'] ?? 0.0),
        'tally_item_name' => trim($_POST['tally_item_name']),
        'tally_item_code' => trim($_POST['tally_item_code']),
        'status'          => $_POST['status'] ?? 'ACTIVE'
    ];
    try {
        AdminService::saveMaterial($data, $materialId, (int)$currentUser['id']);
        header('Location: /admin/materials.php?msg=updated');
        exit;
    } catch (Throwable $e) {
        $error = $e->getMessage();
    }
}

// 3. Handle 1-Click Toggle Status (Active <-> Inactive)
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['toggle_status'])) {
    $materialId = (int)$_POST['material_id'];
    try {
        $newStatus = AdminService::toggleMaterialStatus($materialId, (int)$currentUser['id']);
        header('Location: /admin/materials.php?msg=status_toggled');
        exit;
    } catch (Throwable $e) {
        $error = $e->getMessage();
    }
}

$materials = Database::query("SELECT m.*, c.name AS category_name 
                              FROM materials m 
                              LEFT JOIN material_categories c ON m.category_id = c.id 
                              ORDER BY m.name ASC");

$categories = Database::query("SELECT * FROM material_categories WHERE status = 'ACTIVE' ORDER BY name ASC");
$nextMaterialCode = AdminService::generateNextMaterialCode();

$totalCount = count($materials);
$activeCount = count(array_filter($materials, fn($m) => $m['status'] === 'ACTIVE'));
$inactiveCount = $totalCount - $activeCount;
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Materials Master - <?= htmlspecialchars(Config::get('APP_NAME')) ?></title>
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

        /* Tally Notice Alert Box */
        .tally-warning-banner {
            background: #fff5f5;
            border: 1.5px solid #f87171;
            border-left: 6px solid #dc2626;
            border-radius: 8px;
            padding: 12px 16px;
            margin-bottom: 16px;
            color: #991b1b;
        }
        .tally-warning-banner .warning-title {
            font-weight: 800;
            font-size: 13.5px;
            color: #b91c1c;
            display: flex;
            align-items: center;
            gap: 6px;
            margin-bottom: 4px;
        }
        .tally-warning-banner .warning-desc {
            font-size: 12.5px;
            line-height: 1.5;
            color: #7f1d1d;
        }

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
            max-width: 580px;
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
                <h1>🏷️ Material Master & Rates</h1>
                <p>Manage materials, default rates, available stock, Tally mapping, and Active/Inactive status.</p>
            </div>
            <div class="nav-actions">
                <a href="/admin/material_import.php" class="btn-open-override" style="background: #16a34a; padding: 9px 18px; text-decoration: none; display: flex; align-items: center; gap: 6px;">
                    <span>📥</span> Import from Tally Excel
                </a>
            </div>
        </header>

        <main class="dashboard-content">
            <?php if ($msg === 'created'): ?>
                <div class="alert alert-success" style="margin-bottom: 20px;">
                    ✓ New material registered successfully in the catalog!
                </div>
            <?php elseif ($msg === 'updated'): ?>
                <div class="alert alert-success" style="margin-bottom: 20px;">
                    ✓ Material details and status updated successfully!
                </div>
            <?php elseif ($msg === 'status_toggled'): ?>
                <div class="alert alert-success" style="margin-bottom: 20px;">
                    ✓ Material status updated successfully! Inactive materials are now hidden from requisition creation.
                </div>
            <?php endif; ?>

            <?php if ($error): ?>
                <div class="alert alert-danger" style="margin-bottom: 20px;">
                    <strong>✕ Error:</strong> <?= htmlspecialchars($error) ?>
                </div>
            <?php endif; ?>

            <!-- Add Material Form -->
            <div class="card-box" style="margin-bottom: 20px;">
                <div class="card-box-header">
                    <span class="card-box-title">+ Add New Material Manually</span>
                </div>

                <!-- RED TALLY WARNING BANNER -->
                <div class="tally-warning-banner">
                    <div class="warning-title">
                        <span>⚠️</span> <span>DHYAN DEIN (IMPORTANT NOTICE):</span>
                    </div>
                    <div class="warning-desc">
                        Kripya <strong>Item Name</strong> aur uski <strong>Spelling</strong> bilkul exact wahi type karein jo aapke <strong>Tally Prime / ERP</strong> me bani hui hai. Agar spelling, space ya words me thoda sa bhi difference hua to <strong>Tally XML Export / Import me mismatch & error aayega</strong> aur entry Tally me accept nahi hogi!
                    </div>
                </div>

                <form method="POST" style="display: grid; grid-template-columns: 2fr 1fr 1fr 1fr 1fr auto; gap: 12px; align-items: flex-end;">
                    <input type="hidden" name="create_material" value="1">
                    <div class="form-group">
                        <label style="font-size: 12px; font-weight: 600;">Material Name (Match with Tally) *</label>
                        <input type="text" name="name" class="form-control" placeholder="Exact Tally Item Name..." required>
                    </div>
                    <div class="form-group">
                        <label style="font-size: 12px; font-weight: 600;">Material Code <span style="color: #2563eb; font-weight: 700; font-size: 11px;">(Auto)</span></label>
                        <input type="text" name="code" class="form-control" value="<?= htmlspecialchars($nextMaterialCode) ?>" placeholder="<?= htmlspecialchars($nextMaterialCode) ?>" required style="background: #f8fafc; font-weight: 700; color: #1e293b;">
                    </div>
                    <div class="form-group">
                        <label style="font-size: 12px; font-weight: 600;">Category</label>
                        <select name="category_id" class="form-control">
                            <option value="">General</option>
                            <?php foreach ($categories as $c): ?>
                                <option value="<?= $c['id'] ?>"><?= htmlspecialchars($c['name']) ?></option>
                            <?php endforeach; ?>
                        </select>
                    </div>
                    <div class="form-group">
                        <label style="font-size: 12px; font-weight: 600;">Unit *</label>
                        <input type="text" name="unit" class="form-control" placeholder="Pcs / Mtr / Ltr" required>
                    </div>
                    <div class="form-group">
                        <label style="font-size: 12px; font-weight: 600;">Default Rate (₹) *</label>
                        <input type="number" step="0.01" name="default_rate" class="form-control" placeholder="150.00" required>
                    </div>
                    <button type="submit" class="btn-open-override" style="margin: 0; padding: 9px 18px; background: #2563eb;">
                        Add Material
                    </button>
                </form>
            </div>

            <!-- Material Table Card -->
            <div class="table-card">
                <div class="table-header-bar" style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 12px;">
                    <div>
                        <span style="font-size: 15px; font-weight: 800;">Material Catalog (<?= $totalCount ?> Items)</span>
                        <p style="font-size: 12px; color: var(--text-muted); margin: 2px 0 0 0;">
                            Inactive materials are completely hidden when users create requisitions.
                        </p>
                    </div>
                    <input type="text" id="matSearch" placeholder="🔍 Search material name, code, category..." onkeyup="filterMaterials()" style="padding: 7px 14px; border-radius: 8px; border: 1px solid #cbd5e1; font-size: 13px; width: 300px;">
                </div>

                <!-- Status Filter Tabs -->
                <div style="padding: 12px 18px 0 18px; background: #ffffff;">
                    <div class="filter-tab-bar">
                        <button type="button" class="tab-btn active" onclick="setTab('ALL', this)">All Items (<?= $totalCount ?>)</button>
                        <button type="button" class="tab-btn" onclick="setTab('ACTIVE', this)">🟢 Active (<?= $activeCount ?>)</button>
                        <button type="button" class="tab-btn" onclick="setTab('INACTIVE', this)">🔴 Inactive / Disabled (<?= $inactiveCount ?>)</button>
                    </div>
                </div>

                <div class="table-responsive" style="max-height: 620px; overflow-y: auto;">
                    <table class="admin-table" id="matTable">
                        <thead>
                            <tr style="position: sticky; top: 0; background: #f8fafc; z-index: 10;">
                                <th style="width: 45px;">#</th>
                                <th style="width: 100px;">Code</th>
                                <th>Material Name</th>
                                <th style="width: 140px;">Category</th>
                                <th style="width: 80px;">Unit</th>
                                <th style="text-align: right; width: 120px;">Rate (₹)</th>
                                <th style="text-align: right; width: 120px;">Available Stock</th>
                                <th style="width: 100px; text-align: center;">Status</th>
                                <th style="width: 180px; text-align: center;">Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php foreach ($materials as $idx => $m): 
                                $isActive = ($m['status'] === 'ACTIVE');
                            ?>
                                <tr class="mat-row" data-status="<?= $m['status'] ?>" data-search="<?= strtolower(htmlspecialchars($m['name'] . ' ' . $m['code'] . ' ' . ($m['category_name'] ?? ''))) ?>">
                                    <td style="color: var(--text-muted); font-size: 11.5px;"><?= $idx + 1 ?></td>
                                    <td><code><?= htmlspecialchars($m['code']) ?></code></td>
                                    <td>
                                        <strong style="color: <?= $isActive ? '#0f172a' : '#94a3b8' ?>; font-size: 13.5px;"><?= htmlspecialchars($m['name']) ?></strong>
                                        <?php if (!empty($m['tally_item_name']) && $m['tally_item_name'] !== $m['name']): ?>
                                            <div style="font-size: 11px; color: var(--text-muted); margin-top: 2px;">
                                                Tally Name: <?= htmlspecialchars($m['tally_item_name']) ?>
                                            </div>
                                        <?php endif; ?>
                                    </td>
                                    <td><?= htmlspecialchars($m['category_name'] ?? 'General') ?></td>
                                    <td><?= htmlspecialchars($m['unit']) ?></td>
                                    <td style="text-align: right; font-weight: 700;">₹ <?= number_format($m['default_rate'], 2) ?></td>
                                    <td style="text-align: right; font-weight: 800; color: <?= ($m['current_stock'] > 0) ? '#16a34a' : '#94a3b8' ?>;">
                                        <?= number_format($m['current_stock'] ?? 0, 2) ?> <?= htmlspecialchars($m['unit']) ?>
                                    </td>
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
                                            <button type="button" class="btn-action-sm btn-edit" onclick="openEditModal(<?= htmlspecialchars(json_encode($m)) ?>)">
                                                ✏️ Edit
                                            </button>

                                            <!-- 1-Click Status Toggle -->
                                            <form method="POST" style="margin: 0;" onsubmit="return confirm('Kya aap is material ko <?= $isActive ? 'DEACTIVATE' : 'ACTIVATE' ?> karna chahte hain?')">
                                                <input type="hidden" name="toggle_status" value="1">
                                                <input type="hidden" name="material_id" value="<?= $m['id'] ?>">
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

<!-- EDIT MATERIAL MODAL -->
<div class="modal-backdrop" id="editMaterialModal">
    <div class="modal-box">
        <form method="POST" action="/admin/materials.php">
            <input type="hidden" name="update_material" value="1">
            <input type="hidden" name="material_id" id="edit_id">

            <div class="modal-header">
                <h3 style="font-size: 16px; font-weight: 800; color: #0f172a; margin: 0;">✏️ Edit Material Details</h3>
                <button type="button" onclick="closeEditModal()" style="background: none; border: none; font-size: 20px; cursor: pointer; color: #64748b;">✕</button>
            </div>

            <div class="modal-body">
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 14px;">
                    <div class="form-group" style="grid-column: span 2;">
                        <label style="font-size: 12px; font-weight: 600;">Material Name *</label>
                        <input type="text" name="name" id="edit_name" class="form-control" required>
                    </div>
                    <div class="form-group">
                        <label style="font-size: 12px; font-weight: 600;">Material Code *</label>
                        <input type="text" name="code" id="edit_code" class="form-control" required>
                    </div>
                    <div class="form-group">
                        <label style="font-size: 12px; font-weight: 600;">Category</label>
                        <select name="category_id" id="edit_category_id" class="form-control">
                            <option value="">General</option>
                            <?php foreach ($categories as $c): ?>
                                <option value="<?= $c['id'] ?>"><?= htmlspecialchars($c['name']) ?></option>
                            <?php endforeach; ?>
                        </select>
                    </div>
                    <div class="form-group">
                        <label style="font-size: 12px; font-weight: 600;">Unit *</label>
                        <input type="text" name="unit" id="edit_unit" class="form-control" required>
                    </div>
                    <div class="form-group">
                        <label style="font-size: 12px; font-weight: 600;">Default Rate (₹) *</label>
                        <input type="number" step="0.01" name="default_rate" id="edit_rate" class="form-control" required>
                    </div>
                    <div class="form-group">
                        <label style="font-size: 12px; font-weight: 600;">Available Stock Qty</label>
                        <input type="number" step="0.01" name="current_stock" id="edit_stock" class="form-control">
                    </div>
                    <div class="form-group">
                        <label style="font-size: 12px; font-weight: 600;">Status *</label>
                        <select name="status" id="edit_status" class="form-control" style="font-weight: 700;">
                            <option value="ACTIVE">🟢 ACTIVE (Shown in Requisitions)</option>
                            <option value="INACTIVE">🔴 INACTIVE (Hidden from Requisitions)</option>
                        </select>
                    </div>
                    <div class="form-group" style="grid-column: span 2;">
                        <label style="font-size: 12px; font-weight: 600;">Tally Item Name (For Export Parity)</label>
                        <input type="text" name="tally_item_name" id="edit_tally_name" class="form-control">
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
    filterMaterials();
}

function filterMaterials() {
    const q = document.getElementById('matSearch').value.toLowerCase().trim();
    const rows = document.querySelectorAll('.mat-row');
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

function openEditModal(mat) {
    document.getElementById('edit_id').value = mat.id;
    document.getElementById('edit_name').value = mat.name || '';
    document.getElementById('edit_code').value = mat.code || '';
    document.getElementById('edit_category_id').value = mat.category_id || '';
    document.getElementById('edit_unit').value = mat.unit || '';
    document.getElementById('edit_rate').value = mat.default_rate || 0;
    document.getElementById('edit_stock').value = mat.current_stock || 0;
    document.getElementById('edit_status').value = mat.status || 'ACTIVE';
    document.getElementById('edit_tally_name').value = mat.tally_item_name || mat.name || '';

    const modal = document.getElementById('editMaterialModal');
    modal.style.display = 'flex';
}

function closeEditModal() {
    document.getElementById('editMaterialModal').style.display = 'none';
}

// Close modal when clicking outside
window.onclick = function(event) {
    const modal = document.getElementById('editMaterialModal');
    if (event.target === modal) {
        closeEditModal();
    }
};
</script>
</body>
</html>
