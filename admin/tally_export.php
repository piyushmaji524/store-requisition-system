<?php
/**
 * ADMIN PANEL - TALLY EXPORT & BATCH REGENERATION MANAGEMENT
 * Filters, Presets (Today, Yesterday, Last 7 Days, This Month, Last Month),
 * Live Preview, Voucher Selection Checkboxes, Regenerate / Re-export Support, Batch History
 */

require_once __DIR__ . '/../config/config.php';
require_once __DIR__ . '/../core/Database.php';
require_once __DIR__ . '/../core/Session.php';
require_once __DIR__ . '/../core/Auth.php';
require_once __DIR__ . '/../services/TallyService.php';

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

// Preset range calculations
$preset = $_GET['preset'] ?? 'last_7_days';
$today = date('Y-m-d');
$yesterday = date('Y-m-d', strtotime('-1 day'));
$last7Days = date('Y-m-d', strtotime('-7 days'));
$thisMonthStart = date('Y-m-01');
$lastMonthStart = date('Y-m-01', strtotime('first day of last month'));
$lastMonthEnd = date('Y-m-t', strtotime('last month'));

if (isset($_GET['date_from']) && isset($_GET['date_to']) && !isset($_GET['apply_preset'])) {
    $dateFrom = $_GET['date_from'];
    $dateTo = $_GET['date_to'];
} else {
    switch ($preset) {
        case 'today':
            $dateFrom = $today;
            $dateTo = $today;
            break;
        case 'yesterday':
            $dateFrom = $yesterday;
            $dateTo = $yesterday;
            break;
        case 'this_month':
            $dateFrom = $thisMonthStart;
            $dateTo = $today;
            break;
        case 'last_month':
            $dateFrom = $lastMonthStart;
            $dateTo = $lastMonthEnd;
            break;
        case 'last_7_days':
        default:
            $dateFrom = $last7Days;
            $dateTo = $today;
            $preset = 'last_7_days';
            break;
    }
}

$userId = !empty($_GET['user_id']) ? (int)$_GET['user_id'] : null;
$locationId = !empty($_GET['location_id']) ? (int)$_GET['location_id'] : null;
$exportStatus = $_GET['export_status'] ?? 'ALL';

// Fetch preview
$preview = TallyService::getExportPreview($dateFrom, $dateTo, $userId, $locationId, $exportStatus);

// Fetch previous batches
$batches = TallyService::getExportBatches(20);

$users = Database::query("SELECT id, name FROM users WHERE status = 'ACTIVE' ORDER BY name ASC");
$locations = Database::query("SELECT id, name FROM locations WHERE status = 'ACTIVE' ORDER BY name ASC");

// Calculate unique sub-requisition count
$uniqueVouchers = [];
foreach ($preview['records'] as $rec) {
    $uniqueVouchers[$rec['sub_requisition_id']] = true;
}
$voucherCount = count($uniqueVouchers);
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Tally Export & Regeneration - <?= htmlspecialchars(Config::get('APP_NAME')) ?></title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="/assets/css/admin.css">
    <style>
        .filter-card {
            background: #ffffff;
            border: 1px solid var(--border-color);
            border-radius: var(--radius-md);
            padding: 20px;
            margin-bottom: 20px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.03);
        }
        .preset-chip-row {
            display: flex;
            gap: 8px;
            margin-bottom: 16px;
            flex-wrap: wrap;
            align-items: center;
        }
        .preset-chip {
            padding: 6px 14px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
            background: #f1f5f9;
            color: #475569;
            text-decoration: none;
            border: 1px solid #e2e8f0;
            transition: all 0.2s ease;
            cursor: pointer;
        }
        .preset-chip:hover {
            background: #e2e8f0;
            color: #0f172a;
        }
        .preset-chip.active {
            background: #2563eb;
            color: #ffffff;
            border-color: #2563eb;
            box-shadow: 0 2px 4px rgba(37, 99, 235, 0.25);
        }
        .filter-row {
            display: flex;
            gap: 14px;
            align-items: flex-end;
            flex-wrap: wrap;
        }
        .status-tab-btn {
            padding: 6px 12px;
            border-radius: 6px;
            font-size: 11.5px;
            font-weight: 700;
            text-decoration: none;
            display: inline-flex;
            align-items: center;
            gap: 4px;
        }
        .status-tab-btn.active {
            background: #0f172a;
            color: #ffffff;
        }
        .btn-export-main {
            background: linear-gradient(135deg, #16a34a, #15803d);
            color: #ffffff;
            border: none;
            padding: 9px 18px;
            border-radius: 8px;
            font-weight: 700;
            font-size: 13px;
            cursor: pointer;
            display: inline-flex;
            align-items: center;
            gap: 8px;
            transition: all 0.2s ease;
            box-shadow: 0 2px 6px rgba(22, 163, 74, 0.3);
        }
        .btn-export-main:hover {
            opacity: 0.95;
            transform: translateY(-1px);
        }
        .status-badge-exported {
            font-size: 10.5px;
            font-weight: 700;
            padding: 2.5px 8px;
            border-radius: 4px;
            background: #dcfce7;
            color: #15803d;
            border: 1px solid #bbf7d0;
        }
        .status-badge-unexported {
            font-size: 10.5px;
            font-weight: 700;
            padding: 2.5px 8px;
            border-radius: 4px;
            background: #fef3c7;
            color: #b45309;
            border: 1px solid #fde68a;
        }
        .status-badge-modified {
            font-size: 10.5px;
            font-weight: 700;
            padding: 2.5px 8px;
            border-radius: 4px;
            background: #e0e7ff;
            color: #4338ca;
            border: 1px solid #c7d2fe;
        }
    </style>
</head>
<body>
<div class="app-container">
    <?php require __DIR__ . '/includes/sidebar.php'; ?>

    <div class="main-wrapper">
        <header class="top-navbar">
            <div class="nav-title-block">
                <h1>📑 Tally Accounting Export & Regeneration</h1>
                <p>Generate & re-generate Tally Sales Vouchers for any date range with 100% fail-safe compatibility.</p>
            </div>
        </header>

        <main class="dashboard-content">
            <!-- Filter Bar & Preset Chips -->
            <div class="filter-card">
                <div class="preset-chip-row">
                    <span style="font-size: 12px; font-weight: 700; color: #64748b; margin-right: 4px;">⚡ Quick Range:</span>
                    <button type="button" class="preset-chip <?= ($dateFrom === $today && $dateTo === $today) ? 'active' : '' ?>" onclick="setPreset('<?= $today ?>', '<?= $today ?>', 'today')">Today</button>
                    <button type="button" class="preset-chip <?= ($dateFrom === $yesterday && $dateTo === $yesterday) ? 'active' : '' ?>" onclick="setPreset('<?= $yesterday ?>', '<?= $yesterday ?>', 'yesterday')">Yesterday</button>
                    <button type="button" class="preset-chip <?= ($dateFrom === $last7Days && $dateTo === $today) ? 'active' : '' ?>" onclick="setPreset('<?= $last7Days ?>', '<?= $today ?>', 'last_7_days')">Last 7 Days</button>
                    <button type="button" class="preset-chip <?= ($dateFrom === $thisMonthStart && $dateTo === $today) ? 'active' : '' ?>" onclick="setPreset('<?= $thisMonthStart ?>', '<?= $today ?>', 'this_month')">This Month</button>
                    <button type="button" class="preset-chip <?= ($dateFrom === $lastMonthStart && $dateTo === $lastMonthEnd) ? 'active' : '' ?>" onclick="setPreset('<?= $lastMonthStart ?>', '<?= $lastMonthEnd ?>', 'last_month')">Last Month</button>
                </div>

                <form method="GET" id="filterForm" class="filter-row">
                    <input type="hidden" name="preset" id="presetInput" value="<?= htmlspecialchars($preset) ?>">
                    
                    <div class="form-group">
                        <label style="font-size: 12px; font-weight: 600;">Date From</label>
                        <input type="date" name="date_from" id="dateFrom" value="<?= htmlspecialchars($dateFrom) ?>" class="form-control" style="width: 145px;">
                    </div>
                    <div class="form-group">
                        <label style="font-size: 12px; font-weight: 600;">Date To</label>
                        <input type="date" name="date_to" id="dateTo" value="<?= htmlspecialchars($dateTo) ?>" class="form-control" style="width: 145px;">
                    </div>
                    <div class="form-group">
                        <label style="font-size: 12px; font-weight: 600;">User / Recipient</label>
                        <select name="user_id" class="form-control" style="width: 160px;">
                            <option value="">All Users</option>
                            <?php foreach ($users as $u): ?>
                                <option value="<?= $u['id'] ?>" <?= $userId == $u['id'] ? 'selected' : '' ?>><?= htmlspecialchars($u['name']) ?></option>
                            <?php endforeach; ?>
                        </select>
                    </div>
                    <div class="form-group">
                        <label style="font-size: 12px; font-weight: 600;">Location (Site)</label>
                        <select name="location_id" class="form-control" style="width: 160px;">
                            <option value="">All Locations</option>
                            <?php foreach ($locations as $l): ?>
                                <option value="<?= $l['id'] ?>" <?= $locationId == $l['id'] ? 'selected' : '' ?>><?= htmlspecialchars($l['name']) ?></option>
                            <?php endforeach; ?>
                        </select>
                    </div>
                    <div class="form-group">
                        <label style="font-size: 12px; font-weight: 600;">Export Filter</label>
                        <select name="export_status" class="form-control" style="width: 170px;">
                            <option value="ALL" <?= $exportStatus === 'ALL' ? 'selected' : '' ?>>All (Re-exportable)</option>
                            <option value="NOT_EXPORTED" <?= $exportStatus === 'NOT_EXPORTED' ? 'selected' : '' ?>>Unexported Only</option>
                            <option value="EXPORTED" <?= $exportStatus === 'EXPORTED' ? 'selected' : '' ?>>Already Exported</option>
                        </select>
                    </div>
                    <button type="submit" class="btn-open-override" style="margin-top: 0; width: auto; padding: 9px 20px; background: #2563eb;">
                        🔍 Filter & Preview
                    </button>
                </form>
            </div>

            <!-- Preview & Action Card -->
            <div class="table-card">
                <div class="table-header-bar" style="flex-wrap: wrap; gap: 12px;">
                    <div>
                        <span style="font-size: 15px; font-weight: 800; color: #0f172a;">
                            Tally Export Preview (<?= $voucherCount ?> Vouchers, <?= $preview['record_count'] ?> Items)
                        </span>
                        <div style="font-size: 12.5px; color: var(--text-muted); margin-top: 4px;">
                            Total Quantity: <strong style="color: #0f172a;"><?= $preview['total_quantity'] ?></strong> | 
                            Total Value: <strong style="color: #16a34a;">₹ <?= number_format($preview['total_amount'], 2) ?></strong>
                            <span style="margin-left: 8px; font-size: 11.5px; color: #64748b;">(<?= date('d M Y', strtotime($dateFrom)) ?> - <?= date('d M Y', strtotime($dateTo)) ?>)</span>
                        </div>
                    </div>
                    <?php if ($preview['record_count'] > 0): ?>
                        <div style="display: flex; gap: 10px; align-items: center; flex-wrap: wrap;">
                            <button onclick="executeTallyExport()" class="btn-export-main" id="btnExportMain">
                                <span>📥</span> Export / Re-Generate Tally (.xlsx)
                            </button>
                        </div>
                    <?php endif; ?>
                </div>

                <div class="table-responsive">
                    <table class="admin-table" id="previewTable">
                        <thead>
                            <tr>
                                <th style="width: 40px; text-align: center;">
                                    <input type="checkbox" id="selectAllCheckbox" checked onchange="toggleSelectAll(this)">
                                </th>
                                <th>Voucher Number</th>
                                <th>Voucher Date</th>
                                <th>Party Ledger (Site)</th>
                                <th>Sales Ledger</th>
                                <th>Item Name</th>
                                <th style="text-align: center;">Issued Qty</th>
                                <th>Unit</th>
                                <th style="text-align: right;">Rate (₹)</th>
                                <th style="text-align: right;">Amount (₹)</th>
                                <th>Narration</th>
                                <th style="text-align: center;">Export Status</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php if (empty($preview['records'])): ?>
                                <tr>
                                    <td colspan="12" style="text-align: center; padding: 40px; color: var(--text-muted);">
                                        <div style="font-size: 14px; font-weight: 600;">No records found for the selected date range and filter.</div>
                                        <div style="font-size: 12px; margin-top: 6px; color: #94a3b8;">Try changing the date range above (e.g. This Month, Last 7 Days, or select "All (Re-exportable)").</div>
                                    </td>
                                </tr>
                            <?php else: ?>
                                <?php foreach ($preview['records'] as $r): ?>
                                    <tr data-sub-id="<?= $r['sub_requisition_id'] ?>">
                                        <td style="text-align: center;">
                                            <input type="checkbox" class="row-checkbox" value="<?= $r['sub_requisition_id'] ?>" checked onchange="updateSelectedCount()">
                                        </td>
                                        <td><code><?= htmlspecialchars($r['voucher_number']) ?></code></td>
                                        <td><?= htmlspecialchars($r['voucher_date']) ?></td>
                                        <td><strong><?= htmlspecialchars($r['party_ledger']) ?></strong></td>
                                        <td><code><?= htmlspecialchars($r['sales_ledger']) ?></code></td>
                                        <td><strong><?= htmlspecialchars($r['item_name']) ?></strong></td>
                                        <td style="text-align: center; font-weight: 700; color: #16a34a;"><?= $r['quantity'] ?></td>
                                        <td><?= htmlspecialchars($r['unit']) ?></td>
                                        <td style="text-align: right;">₹ <?= number_format($r['rate'], 2) ?></td>
                                        <td style="text-align: right; font-weight: 700;">₹ <?= number_format($r['amount'], 2) ?></td>
                                        <td style="font-size: 12px; color: var(--text-muted);"><?= htmlspecialchars($r['narration']) ?></td>
                                        <td style="text-align: center;">
                                            <?php if ($r['export_status'] === 'EXPORTED'): ?>
                                                <span class="status-badge-exported" title="Already exported previously - Safe to re-export">EXPORTED</span>
                                            <?php elseif ($r['export_status'] === 'EXPORTED_MODIFIED'): ?>
                                                <span class="status-badge-modified" title="Exported earlier, but modified since">MODIFIED</span>
                                            <?php else: ?>
                                                <span class="status-badge-unexported">PENDING</span>
                                            <?php endif; ?>
                                        </td>
                                    </tr>
                                <?php endforeach; ?>
                            <?php endif; ?>
                        </tbody>
                    </table>
                </div>
            </div>

            <!-- Export Batches History with Re-download and Regenerate actions -->
            <div class="table-card" style="margin-top: 24px;">
                <div class="table-header-bar">
                    <div>
                        <span style="font-size: 14.5px; font-weight: 700;">Previous Export Batches</span>
                        <span style="font-size: 12px; color: var(--text-muted); margin-left: 8px;">History of generated exports with instant re-download options</span>
                    </div>
                </div>
                <div class="table-responsive">
                    <table class="admin-table">
                        <thead>
                            <tr>
                                <th>Batch ID</th>
                                <th>Date Range</th>
                                <th>Record Count</th>
                                <th>File Name</th>
                                <th>Exported By</th>
                                <th>Exported At</th>
                                <th style="text-align: center;">Direct Downloads</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php if (empty($batches)): ?>
                                <tr>
                                    <td colspan="7" style="text-align: center; padding: 24px; color: var(--text-muted);">
                                        No previous export batches.
                                    </td>
                                </tr>
                            <?php else: ?>
                                <?php foreach ($batches as $b): 
                                    $xlsxName = str_ends_with($b['file_name'], '.xlsx') ? $b['file_name'] : "Tally_Sales_Voucher_" . $b['batch_id'] . ".xlsx";
                                    $xmlName = str_replace('.xlsx', '.xml', $xlsxName);
                                    $csvName = "Tally_Export_" . $b['batch_id'] . ".csv";
                                ?>
                                    <tr>
                                        <td><code><?= htmlspecialchars($b['batch_id']) ?></code></td>
                                        <td><strong><?= date('d M Y', strtotime($b['date_from'])) ?></strong> to <strong><?= date('d M Y', strtotime($b['date_to'])) ?></strong></td>
                                        <td><strong><?= $b['record_count'] ?></strong> items</td>
                                        <td><code><?= htmlspecialchars($b['file_name']) ?></code></td>
                                        <td><?= htmlspecialchars($b['created_by_name']) ?></td>
                                        <td><?= date('d M Y, h:i A', strtotime($b['created_at'])) ?></td>
                                        <td style="text-align: center;">
                                            <div style="display: inline-flex; gap: 6px;">
                                                <a href="/uploads/exports/<?= htmlspecialchars($xlsxName) ?>" download class="btn-action-sm" style="background: #f0fdf4; color: #16a34a; border: 1px solid #bbf7d0; padding: 4px 8px; border-radius: 6px; font-weight: 700; text-decoration: none; font-size: 11.5px;" title="Download TallyPrime Official Double-Entry Excel">
                                                    📊 Excel (.xlsx)
                                                </a>
                                                <a href="/uploads/exports/<?= htmlspecialchars($xmlName) ?>" download class="btn-action-sm" style="background: #fdf4ff; color: #9333ea; border: 1px solid #f0abfc; padding: 4px 8px; border-radius: 6px; font-weight: 700; text-decoration: none; font-size: 11.5px;" title="Download Tally Native XML Format">
                                                    ⚡ XML (.xml)
                                                </a>
                                                <a href="/uploads/exports/<?= htmlspecialchars($csvName) ?>" download class="btn-action-sm" style="background: #eff6ff; color: #2563eb; border: 1px solid #bfdbfe; padding: 4px 8px; border-radius: 6px; font-weight: 700; text-decoration: none; font-size: 11.5px;">
                                                    📄 CSV
                                                </a>
                                            </div>
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

<script src="/assets/js/app-modal.js"></script>
<script>
function setPreset(from, to, presetName) {
    document.getElementById('dateFrom').value = from;
    document.getElementById('dateTo').value = to;
    document.getElementById('presetInput').value = presetName;
    document.getElementById('filterForm').submit();
}

function toggleSelectAll(masterCheckbox) {
    const checkboxes = document.querySelectorAll('.row-checkbox');
    checkboxes.forEach(cb => cb.checked = masterCheckbox.checked);
    updateSelectedCount();
}

function updateSelectedCount() {
    const checked = document.querySelectorAll('.row-checkbox:checked');
    const btn = document.getElementById('btnExportMain');
    const selectedSubIds = new Set(Array.from(checked).map(cb => parseInt(cb.value)));
    
    if (btn) {
        if (selectedSubIds.size === 0) {
            btn.innerHTML = `<span>📥</span> Export / Re-Generate (0 Vouchers)`;
            btn.style.opacity = '0.5';
            btn.style.cursor = 'not-allowed';
        } else {
            btn.innerHTML = `<span>📥</span> Export / Re-Generate (${selectedSubIds.size} Vouchers)`;
            btn.style.opacity = '1';
            btn.style.cursor = 'pointer';
        }
    }
}

async function executeTallyExport() {
    const checked = document.querySelectorAll('.row-checkbox:checked');
    const subIds = Array.from(new Set(Array.from(checked).map(cb => parseInt(cb.value))));

    if (subIds.length === 0) {
        AppModal.alert('Please select at least one voucher to export.', 'No Vouchers Selected', 'warning');
        return;
    }

    const ok = await AppModal.confirm(
        `Confirm generating Tally Sales Voucher (.xlsx) for ${subIds.length} selected vouchers (${document.getElementById('dateFrom').value} to ${document.getElementById('dateTo').value})?\n\nThis will safely create a fresh export batch without affecting any existing system data.`,
        {
            title: 'Export / Re-Generate Tally Vouchers',
            type: 'green',
            confirmText: 'Generate & Download Now',
            cancelText: 'Cancel'
        }
    );
    if (!ok) return;

    try {
        const btn = document.getElementById('btnExportMain');
        if (btn) {
            btn.disabled = true;
            btn.innerHTML = `<span>⏳</span> Generating Tally Batch...`;
        }

        const res = await fetch('/api/admin/tally/export', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                date_from: document.getElementById('dateFrom').value,
                date_to: document.getElementById('dateTo').value,
                sub_requisition_ids: subIds
            })
        });

        const data = await res.json();
        if (data.success) {
            await AppModal.alert(`Tally Batch ${data.data.batch_id} generated successfully with ${data.data.record_count} items across ${data.data.sub_req_count} vouchers!`, 'Export Generated', 'success');
            // Trigger automatic download of the Excel file
            window.location.href = data.data.file_url;
            setTimeout(() => window.location.reload(), 1500);
        } else {
            AppModal.alert(data.message || 'Export failed.', 'Export Error', 'error');
            if (btn) {
                btn.disabled = false;
                updateSelectedCount();
            }
        }
    } catch (e) {
        AppModal.alert('Network error executing Tally export.', 'Network Error', 'error');
        const btn = document.getElementById('btnExportMain');
        if (btn) {
            btn.disabled = false;
            updateSelectedCount();
        }
    }
}

// Initial count update
document.addEventListener('DOMContentLoaded', () => {
    updateSelectedCount();
});
</script>
</body>
</html>
