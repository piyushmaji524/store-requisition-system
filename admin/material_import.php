<?php
/**
 * ADMIN PANEL - TALLY MATERIAL IMPORT & INCREMENTAL SYNC
 * Upload Tally Stock Summary Excel, Delta Diff Analysis, Staging Preview, Auto Code Generation, Atomic Catalog Sync
 */

require_once __DIR__ . '/../config/config.php';
require_once __DIR__ . '/../core/Database.php';
require_once __DIR__ . '/../core/Session.php';
require_once __DIR__ . '/../core/Auth.php';
require_once __DIR__ . '/../services/TallyImportService.php';

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

$error = null;
$success = null;
$analysisResult = null;
$uploadedFileName = null;

// 1. Handle File Upload and Preview Analysis
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action']) && $_POST['action'] === 'analyze_file') {
    if (empty($_FILES['tally_file']['tmp_name'])) {
        $error = "Please select a valid Tally Excel (.xlsx) file to upload.";
    } else {
        $file = $_FILES['tally_file'];
        $ext = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));

        if ($ext !== 'xlsx') {
            $error = "Invalid file format. Please upload a standard Excel (.xlsx) file exported from Tally.";
        } else {
            try {
                $rawItems = TallyImportService::parseTallyStockSummary($file['tmp_name']);
                if (empty($rawItems)) {
                    $error = "No valid stock items found in the uploaded sheet. Ensure the file is an active Tally Stock Summary export.";
                } else {
                    $analysisResult = TallyImportService::analyzeDelta($rawItems);
                    $uploadedFileName = htmlspecialchars($file['name']);
                    // Store staged analysis in session for confirmation
                    Session::set('staged_tally_analysis', $analysisResult);
                    Session::set('staged_tally_filename', $uploadedFileName);
                }
            } catch (Throwable $e) {
                $error = "Error parsing Tally file: " . $e->getMessage();
            }
        }
    }
}

// 2. Handle Final Sync Confirmation
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action']) && $_POST['action'] === 'confirm_sync') {
    $staged = Session::get('staged_tally_analysis');
    if (!$staged || empty($staged['staged_items'])) {
        $error = "Session expired or no staged items to synchronize. Please re-upload your Tally file.";
    } else {
        // Collect any user overrides from POST (e.g. customized units or categories)
        $itemsToSync = [];
        $postedItems = $_POST['items'] ?? [];

        foreach ($staged['staged_items'] as $idx => $stagedItem) {
            $action = $stagedItem['action'];

            $customUnit = trim((string)($postedItems[$idx]['unit'] ?? $stagedItem['unit']));
            $customCatId = !empty($postedItems[$idx]['category_id']) ? (int)$postedItems[$idx]['category_id'] : $stagedItem['category_id'];
            $customRate = isset($postedItems[$idx]['rate']) ? (float)$postedItems[$idx]['rate'] : $stagedItem['rate'];

            $itemsToSync[] = [
                'action'       => $action,
                'name'         => $stagedItem['name'] ?? $stagedItem['tally_name'],
                'tally_name'   => $stagedItem['tally_name'],
                'existing_id'  => $stagedItem['existing_id'],
                'unit'         => !empty($customUnit) ? $customUnit : 'Pcs',
                'category_id'  => $customCatId,
                'rate'         => $customRate,
                'closing_qty'  => $stagedItem['closing_qty'] ?? 0.0
            ];
        }

        try {
            $syncSummary = TallyImportService::executeSync($itemsToSync, (int)$currentUser['id']);
            Session::remove('staged_tally_analysis');
            Session::remove('staged_tally_filename');
            $success = $syncSummary;
        } catch (Throwable $e) {
            $error = "Sync Failed: " . $e->getMessage();
        }
    }
}

// Load cached staged analysis if returning
if (!$analysisResult && Session::get('staged_tally_analysis')) {
    $analysisResult = Session::get('staged_tally_analysis');
    $uploadedFileName = Session::get('staged_tally_filename');
}

// Clear staging session if cancelled
if (isset($_GET['cancel'])) {
    Session::remove('staged_tally_analysis');
    Session::remove('staged_tally_filename');
    header('Location: /admin/material_import.php');
    exit;
}

$categories = Database::query("SELECT id, name FROM material_categories WHERE status = 'ACTIVE' ORDER BY name ASC");
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Tally Material Excel Import - <?= htmlspecialchars(Config::get('APP_NAME')) ?></title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="/assets/css/admin.css">
    <style>
        .import-hero-card {
            background: #ffffff;
            border: 1px solid var(--border-color);
            border-radius: var(--radius-md);
            padding: 28px;
            margin-bottom: 24px;
            box-shadow: var(--shadow-sm);
        }
        .upload-dropzone {
            border: 2px dashed #93c5fd;
            background: #f8fafc;
            border-radius: 14px;
            padding: 36px 20px;
            text-align: center;
            cursor: pointer;
            transition: all 0.2s ease;
        }
        .upload-dropzone:hover {
            border-color: #2563eb;
            background: #eff6ff;
        }
        .kpi-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 16px;
            margin-bottom: 24px;
        }
        .kpi-card {
            background: #ffffff;
            border: 1px solid var(--border-color);
            border-radius: var(--radius-md);
            padding: 16px 20px;
            box-shadow: var(--shadow-sm);
            display: flex;
            align-items: center;
            gap: 14px;
        }
        .kpi-icon {
            width: 44px;
            height: 44px;
            border-radius: 10px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 20px;
        }
        .kpi-label {
            font-size: 11.5px;
            font-weight: 600;
            color: var(--text-muted);
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        .kpi-val {
            font-size: 20px;
            font-weight: 800;
            color: var(--text-main);
            margin-top: 2px;
        }
        .filter-tab-bar {
            display: flex;
            gap: 8px;
            border-bottom: 1px solid var(--border-color);
            padding-bottom: 12px;
            margin-bottom: 16px;
            flex-wrap: wrap;
        }
        .tab-btn {
            padding: 8px 16px;
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
        .tab-btn:hover:not(.active) {
            background: #e2e8f0;
        }
        .action-chip {
            display: inline-flex;
            align-items: center;
            gap: 4px;
            font-size: 11px;
            font-weight: 800;
            padding: 3px 8px;
            border-radius: 6px;
            text-transform: uppercase;
        }
        .chip-new { background: #dcfce7; color: #15803d; border: 1px solid #86efac; }
        .chip-update { background: #fef3c7; color: #b45309; border: 1px solid #fcd34d; }
        .chip-sync { background: #f1f5f9; color: #475569; border: 1px solid #cbd5e1; }
        .chip-review { background: #fee2e2; color: #b91c1c; border: 1px solid #fca5a5; }

        .form-select-sm, .form-input-sm {
            padding: 4px 8px;
            font-size: 12px;
            border-radius: 6px;
            border: 1px solid #cbd5e1;
            background: #f8fafc;
            color: #0f172a;
        }
        .search-box-wrap {
            max-width: 320px;
            display: flex;
            align-items: center;
            position: relative;
        }
        .search-box-wrap input {
            width: 100%;
            padding: 8px 12px 8px 34px;
            border-radius: 8px;
            border: 1px solid #cbd5e1;
            font-size: 13px;
        }
        .search-box-wrap span {
            position: absolute;
            left: 10px;
            color: #94a3b8;
            font-size: 14px;
        }
    </style>
</head>
<body>
<div class="app-container">
    <?php require __DIR__ . '/includes/sidebar.php'; ?>

    <div class="main-wrapper">
        <header class="top-navbar">
            <div class="nav-title-block">
                <h1>📥 Tally Material Import & Smart Delta Sync</h1>
                <p>Import Tally Stock Summary Excel, auto-generate codes, and update prices incrementally with zero duplicate errors.</p>
            </div>
            <div class="nav-actions">
                <a href="/admin/materials.php" class="btn-outline-action" style="padding: 8px 14px; font-size: 13px; text-decoration: none;">
                    ← Back to Materials
                </a>
            </div>
        </header>

        <main class="dashboard-content">
            <?php if ($error): ?>
                <div class="alert alert-danger" style="margin-bottom: 20px;">
                    <strong>✕ Error:</strong> <?= htmlspecialchars($error) ?>
                </div>
            <?php endif; ?>

            <?php if ($success): ?>
                <div class="card-box" style="margin-bottom: 24px; border-left: 5px solid #16a34a; background: #f0fdf4;">
                    <div style="display: flex; align-items: center; justify-content: space-between;">
                        <div>
                            <h3 style="color: #15803d; font-size: 18px; margin-bottom: 4px;">🎉 Catalog Synchronized Successfully!</h3>
                            <p style="color: #166534; font-size: 13.5px; margin: 0;">
                                <strong><?= $success['inserted_count'] ?></strong> new material(s) added &bull; 
                                <strong><?= $success['updated_count'] ?></strong> material price(s) updated in the system catalog.
                            </p>
                        </div>
                        <div style="display: flex; gap: 10px;">
                            <a href="/admin/material_import.php?cancel=1" class="btn-open-override" style="background: #ffffff; color: #15803d; border: 1px solid #86efac; padding: 8px 16px; text-decoration: none;">
                                Upload Another File
                            </a>
                            <a href="/admin/materials.php" class="btn-open-override" style="background: #16a34a; padding: 8px 18px; text-decoration: none;">
                                View Materials Catalog →
                            </a>
                        </div>
                    </div>
                </div>
            <?php endif; ?>

            <!-- UPLOAD CARD (If no active staging analysis) -->
            <?php if (!$analysisResult && !$success): ?>
                <div class="import-hero-card">
                    <form action="/admin/material_import.php" method="POST" enctype="multipart/form-data">
                        <input type="hidden" name="action" value="analyze_file">
                        
                        <div class="upload-dropzone" onclick="document.getElementById('tallyFileInput').click()">
                            <div style="font-size: 44px; margin-bottom: 10px;">📊</div>
                            <h3 style="font-size: 18px; font-weight: 800; color: #0f172a; margin-bottom: 6px;">
                                Click to Upload or Drag & Drop Tally Stock Summary (.xlsx)
                            </h3>
                            <p style="font-size: 13px; color: #64748b; max-width: 540px; margin: 0 auto 16px auto;">
                                Export your Stock Summary directly from Tally (<strong>Gateway of Tally ➔ Stock Summary ➔ Export ➔ Excel</strong>) and upload the file here.
                            </p>
                            <input type="file" id="tallyFileInput" name="tally_file" accept=".xlsx" style="display: none;" onchange="this.form.submit()">
                            
                            <button type="button" class="btn-open-override" style="background: #2563eb; padding: 10px 24px; font-size: 14px;">
                                Select Excel File (.xlsx)
                            </button>
                        </div>
                    </form>

                    <div style="margin-top: 24px; padding: 18px; background: #f8fafc; border-radius: 12px; border: 1px solid #e2e8f0;">
                        <h4 style="font-size: 13.5px; font-weight: 700; color: #0f172a; margin-bottom: 8px;">💡 How Tally Incremental Sync Works:</h4>
                        <ul style="font-size: 12.5px; color: #475569; line-height: 1.6; padding-left: 20px; margin: 0;">
                            <li><strong>Exact Spelling Parity:</strong> Matches items by exact Tally particulars name to guarantee zero export mismatches.</li>
                            <li><strong>Auto Material Codes:</strong> Automatically generates sequential codes like <code>MAT-0001</code> for any new items.</li>
                            <li><strong>Smart Price Updates:</strong> If an existing item's rate changes in Tally, only its rate is updated without breaking existing requisition history.</li>
                            <li><strong>Zero Data Deletion:</strong> Existing requisition records and fulfilled slips remain 100% safe and untouched.</li>
                        </ul>
                    </div>
                </div>
            <?php endif; ?>

            <!-- STAGING PREVIEW & REVIEW TABLE (When file is analyzed) -->
            <?php if ($analysisResult && !$success): ?>
                <!-- KPI Summary Row -->
                <div class="kpi-grid">
                    <div class="kpi-card">
                        <div class="kpi-icon" style="background: #eff6ff; color: #2563eb;">📦</div>
                        <div>
                            <div class="kpi-label">Total Tally Items</div>
                            <div class="kpi-val"><?= number_format($analysisResult['total_tally_items']) ?></div>
                        </div>
                    </div>
                    <div class="kpi-card">
                        <div class="kpi-icon" style="background: #dcfce7; color: #16a34a;">🟢</div>
                        <div>
                            <div class="kpi-label">New Items to Add</div>
                            <div class="kpi-val" style="color: #16a34a;"><?= number_format($analysisResult['new_items_count']) ?></div>
                        </div>
                    </div>
                    <div class="kpi-card">
                        <div class="kpi-icon" style="background: #fef3c7; color: #d97706;">🟡</div>
                        <div>
                            <div class="kpi-label">Price / Rate Updates</div>
                            <div class="kpi-val" style="color: #d97706;"><?= number_format($analysisResult['rate_update_count']) ?></div>
                        </div>
                    </div>
                    <div class="kpi-card">
                        <div class="kpi-icon" style="background: #f1f5f9; color: #64748b;">⚪</div>
                        <div>
                            <div class="kpi-label">Already in Sync</div>
                            <div class="kpi-val" style="color: #64748b;"><?= number_format($analysisResult['in_sync_count']) ?></div>
                        </div>
                    </div>
                </div>

                <form action="/admin/material_import.php" method="POST" id="confirmSyncForm">
                    <input type="hidden" name="action" value="confirm_sync">

                    <div class="table-card">
                        <div class="table-header-bar" style="flex-wrap: wrap; gap: 14px;">
                            <div>
                                <h3 style="font-size: 15px; font-weight: 800; color: #0f172a; margin: 0;">
                                    File Preview: <span style="color: #2563eb;"><?= $uploadedFileName ?></span>
                                </h3>
                                <p style="font-size: 12px; color: #64748b; margin: 2px 0 0 0;">
                                    Review the delta analysis below. You can customize Category and Unit before committing to catalog.
                                </p>
                            </div>

                            <div style="display: flex; gap: 10px; align-items: center;">
                                <div class="search-box-wrap">
                                    <span>🔍</span>
                                    <input type="text" id="filterInput" placeholder="Filter material name..." onkeyup="filterTable()">
                                </div>

                                <a href="/admin/material_import.php?cancel=1" class="btn-outline-action" style="padding: 8px 14px; text-decoration: none; font-size: 13px;">
                                    Cancel
                                </a>

                                <button type="submit" class="btn-open-override" style="background: #16a34a; padding: 9px 20px; font-size: 13.5px; font-weight: 800;">
                                    ✓ Confirm & Sync (<?= count($analysisResult['staged_items']) ?> Items & Stock)
                                </button>
                            </div>
                        </div>

                        <!-- Filter Tab Selector -->
                        <div style="padding: 12px 18px; background: #ffffff;">
                            <div class="filter-tab-bar">
                                <button type="button" class="tab-btn active" onclick="setTab('ALL', this)">All Items (<?= count($analysisResult['staged_items']) ?>)</button>
                                <button type="button" class="tab-btn" onclick="setTab('NEW_ITEM', this)">🟢 New Additions (<?= $analysisResult['new_items_count'] ?>)</button>
                                <button type="button" class="tab-btn" onclick="setTab('UPDATE_RATE', this)">🟡 Rate Updates (<?= $analysisResult['rate_update_count'] ?>)</button>
                                <button type="button" class="tab-btn" onclick="setTab('IN_SYNC', this)">⚪ In Sync (<?= $analysisResult['in_sync_count'] ?>)</button>
                                <?php if ($analysisResult['review_count'] > 0): ?>
                                    <button type="button" class="tab-btn" onclick="setTab('NEEDS_REVIEW', this)">🔴 Needs Review (<?= $analysisResult['review_count'] ?>)</button>
                                <?php endif; ?>
                            </div>
                        </div>

                        <!-- Table -->
                        <div class="table-responsive" style="max-height: 580px; overflow-y: auto;">
                            <table class="admin-table" id="stagedTable">
                                <thead>
                                    <tr style="position: sticky; top: 0; background: #f8fafc; z-index: 10;">
                                        <th style="width: 45px;">#</th>
                                        <th style="width: 130px;">Action</th>
                                        <th>Tally Particulars Name</th>
                                        <th style="width: 120px;">Assigned Code</th>
                                        <th style="width: 160px;">Category</th>
                                        <th style="width: 100px;">Unit</th>
                                        <th style="text-align: right; width: 130px;">Tally Rate (₹)</th>
                                        <th style="text-align: right; width: 110px;">Stock Qty</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <?php 
                                    $unitOptions = ['Pcs', 'Mtr', 'Ltr', 'Kg', 'Gm', 'Ml', 'Bag', 'Pkt', 'Set', 'Box', 'Roll', 'Bundle', 'Sheet', 'Sqft', 'Sqmtr', 'Rft', 'Bucket', 'Nos', 'Pair'];
                                    foreach ($analysisResult['staged_items'] as $idx => $it): 
                                        $action = $it['action'];
                                        $chipClass = $action === 'NEW_ITEM' ? 'chip-new' : ($action === 'UPDATE_RATE' ? 'chip-update' : ($action === 'IN_SYNC' ? 'chip-sync' : 'chip-review'));
                                        $chipLabel = $action === 'NEW_ITEM' ? '🟢 New Item' : ($action === 'UPDATE_RATE' ? '🟡 Price Update' : ($action === 'IN_SYNC' ? '⚪ In Sync' : '🔴 Review'));
                                        $curUnit = $it['unit'] ?? 'Pcs';
                                        $itemUnits = $unitOptions;
                                        if (!in_array($curUnit, $itemUnits)) {
                                            $itemUnits[] = $curUnit;
                                        }
                                    ?>
                                        <tr class="staged-row" data-action="<?= $action ?>" data-name="<?= strtolower(htmlspecialchars($it['tally_name'])) ?>">
                                            <td style="color: var(--text-muted); font-size: 11.5px;"><?= $idx + 1 ?></td>
                                            <td>
                                                <span class="action-chip <?= $chipClass ?>"><?= $chipLabel ?></span>
                                            </td>
                                            <td>
                                                <strong style="color: #0f172a; font-size: 13.5px;"><?= htmlspecialchars($it['tally_name']) ?></strong>
                                                <?php if ($action === 'UPDATE_RATE'): ?>
                                                    <div style="font-size: 11px; color: #b45309; margin-top: 2px;">
                                                        Old Rate: ₹ <?= number_format($it['old_rate'], 2) ?> ➔ New Rate: ₹ <?= number_format($it['rate'], 2) ?>
                                                    </div>
                                                <?php endif; ?>
                                            </td>
                                            <td>
                                                <code><?= htmlspecialchars($it['code']) ?></code>
                                            </td>
                                            <td>
                                                <select name="items[<?= $idx ?>][category_id]" class="form-select-sm" style="width: 100%;">
                                                    <option value="">General</option>
                                                    <?php foreach ($categories as $cat): ?>
                                                        <option value="<?= $cat['id'] ?>" <?= ($it['category_id'] == $cat['id']) ? 'selected' : '' ?>>
                                                            <?= htmlspecialchars($cat['name']) ?>
                                                        </option>
                                                    <?php endforeach; ?>
                                                </select>
                                            </td>
                                            <td>
                                                <select name="items[<?= $idx ?>][unit]" class="form-select-sm" style="width: 100%;">
                                                    <?php foreach ($itemUnits as $u): ?>
                                                        <option value="<?= $u ?>" <?= (strcasecmp($curUnit, $u) === 0) ? 'selected' : '' ?>>
                                                            <?= $u ?>
                                                        </option>
                                                    <?php endforeach; ?>
                                                </select>
                                            </td>
                                            <td style="text-align: right; font-weight: 800; color: #0f172a;">
                                                <input type="number" step="0.01" name="items[<?= $idx ?>][rate]" value="<?= $it['rate'] ?>" class="form-input-sm" style="width: 90px; text-align: right;">
                                            </td>
                                            <td style="text-align: right; color: #64748b; font-size: 12.5px;">
                                                <?= $it['closing_qty'] ?>
                                            </td>
                                        </tr>
                                    <?php endforeach; ?>
                                </tbody>
                            </table>
                        </div>
                    </div>
                </form>
            <?php endif; ?>
        </main>
    </div>
</div>

<script>
let currentTab = 'ALL';

function setTab(tab, btn) {
    currentTab = tab;
    document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    filterTable();
}

function filterTable() {
    const search = document.getElementById('filterInput').value.toLowerCase().trim();
    const rows = document.querySelectorAll('.staged-row');

    rows.forEach(row => {
        const action = row.getAttribute('data-action');
        const name = row.getAttribute('data-name');
        
        const matchesTab = (currentTab === 'ALL' || action === currentTab);
        const matchesSearch = (!search || name.includes(search));

        if (matchesTab && matchesSearch) {
            row.style.display = '';
        } else {
            row.style.display = 'none';
        }
    });
}
</script>
</body>
</html>
