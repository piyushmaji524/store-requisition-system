<?php
/**
 * ADMIN PANEL - ACTIVITY AUDIT LOGS
 * Complete system audit trail with user actions, old/new data diffs, IP, and timestamps
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

$page = max(1, (int) ($_GET['page'] ?? 1));
$rawLimit = (int) ($_GET['limit'] ?? 50);
$limit = ($rawLimit > 0 && in_array($rawLimit, [25, 50, 100, 200, 500], true)) ? $rawLimit : 50;
if ($limit <= 0) {
    $limit = 50;
}
$search = trim($_GET['q'] ?? '');
$actionFilter = trim($_GET['action_filter'] ?? '');

$where = [];
$params = [];

if (!empty($search)) {
    $where[] = "(a.action LIKE :s1 OR u.name LIKE :s2 OR u.employee_code LIKE :s3 OR a.ip_address LIKE :s4 OR a.entity_type LIKE :s5 OR a.entity_id LIKE :s6 OR CAST(a.new_data AS CHAR) LIKE :s7)";
    $params[':s1'] = "%{$search}%";
    $params[':s2'] = "%{$search}%";
    $params[':s3'] = "%{$search}%";
    $params[':s4'] = "%{$search}%";
    $params[':s5'] = "%{$search}%";
    $params[':s6'] = "%{$search}%";
    $params[':s7'] = "%{$search}%";
}

if (!empty($actionFilter)) {
    $where[] = "a.action = :action";
    $params[':action'] = $actionFilter;
}

$whereSql = !empty($where) ? ('WHERE ' . implode(' AND ', $where)) : '';

$total = 0;
$logs = [];
$distinctActions = [];
$errorMessage = null;

try {
    // Count total matching logs
    $countSql = "SELECT COUNT(*) AS total FROM activity_logs a LEFT JOIN users u ON a.user_id = u.id {$whereSql}";
    $totalRow = Database::queryOne($countSql, $params);
    $total = (int) ($totalRow['total'] ?? 0);

    $totalPages = max(1, (int) ceil($total / $limit));
    if ($page > $totalPages) {
        $page = $totalPages;
    }
    $offset = ($page - 1) * $limit;
    $limitInt = (int) $limit;
    $offsetInt = (int) $offset;

    // Fetch paginated logs
    $sql = "SELECT a.*, u.name AS user_name, u.employee_code, u.role AS user_role
            FROM activity_logs a
            LEFT JOIN users u ON a.user_id = u.id
            {$whereSql}
            ORDER BY a.id DESC
            LIMIT {$limitInt} OFFSET {$offsetInt}";

    $logs = Database::query($sql, $params);

    // Distinct actions for filter
    $distinctActions = Database::query("SELECT DISTINCT action FROM activity_logs WHERE action IS NOT NULL AND action != '' ORDER BY action ASC");
} catch (Throwable $e) {
    error_log("Activity Logs Error: " . $e->getMessage());
    $errorMessage = $e->getMessage();
    $totalPages = 1;
    $offset = 0;
}

// Helper for pagination query string
function buildPageUrl(int $p, int $l, string $q, string $af): string
{
    $params = ['page' => $p];
    if ($l > 0 && $l !== 50)
        $params['limit'] = $l;
    if (!empty($q))
        $params['q'] = $q;
    if (!empty($af))
        $params['action_filter'] = $af;
    return '/admin/activity_logs.php?' . http_build_query($params);
}
?>
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Activity Logs - <?= htmlspecialchars(Config::get('APP_NAME')) ?></title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="/assets/css/admin.css">
</head>

<body>
    <div class="app-container">
        <?php require __DIR__ . '/includes/sidebar.php'; ?>

        <div class="main-wrapper">
            <header class="top-navbar">
                <div class="nav-title-block">
                    <h1>📜 Activity Audit Logs</h1>
                    <p>Immutable log of every user action, store issue, admin override, and master change.</p>
                </div>
                <div class="nav-badges-group">
                    <div class="nav-pill-badge">
                        📊 Total Events: <strong><?= number_format($total) ?></strong>
                    </div>
                </div>
            </header>

            <main class="dashboard-content">
                <?php if (!empty($errorMessage)): ?>
                    <div
                        style="background: #fee2e2; color: #b91c1c; border: 1px solid #fca5a5; padding: 12px 16px; border-radius: 8px; margin-bottom: 16px; font-size: 13.5px;">
                        ⚠️ <strong>Unable to load logs:</strong> <?= htmlspecialchars($errorMessage) ?>
                    </div>
                <?php endif; ?>

                <div class="table-card">
                    <!-- Filter & Search Bar -->
                    <div class="table-header-bar"
                        style="display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 12px;">
                        <form method="GET" action="/admin/activity_logs.php"
                            style="display: flex; align-items: center; gap: 10px; flex-wrap: wrap; flex: 1;">
                            <input type="text" name="q" value="<?= htmlspecialchars($search) ?>"
                                placeholder="🔍 Search action, user, IP, ID..." class="form-control"
                                style="width: 260px; padding: 6px 12px; font-size: 13px;">

                            <select name="action_filter" class="form-control"
                                style="width: 220px; padding: 6px 10px; font-size: 13px;" onchange="this.form.submit()">
                                <option value="">-- All Action Types --</option>
                                <?php foreach ($distinctActions as $da): ?>
                                    <option value="<?= htmlspecialchars($da['action']) ?>"
                                        <?= ($actionFilter === $da['action']) ? 'selected' : '' ?>>
                                        <?= htmlspecialchars($da['action']) ?>
                                    </option>
                                <?php endforeach; ?>
                            </select>

                            <button type="submit" class="btn-primary"
                                style="padding: 6px 14px; font-size: 13px;">Search</button>
                            <?php if (!empty($search) || !empty($actionFilter)): ?>
                                <a href="/admin/activity_logs.php"
                                    style="font-size: 12.5px; color: var(--primary-color); text-decoration: none; font-weight: 600;">Clear
                                    Filters</a>
                            <?php endif; ?>
                        </form>

                        <div class="page-size-selector">
                            <span>Show:</span>
                            <select class="page-size-select" onchange="changePageSize(this.value)">
                                <option value="25" <?= $limit === 25 ? 'selected' : '' ?>>25</option>
                                <option value="50" <?= $limit === 50 ? 'selected' : '' ?>>50</option>
                                <option value="100" <?= $limit === 100 ? 'selected' : '' ?>>100</option>
                                <option value="200" <?= $limit === 200 ? 'selected' : '' ?>>200</option>
                                <option value="500" <?= $limit === 500 ? 'selected' : '' ?>>500</option>
                            </select>
                            <span>per page</span>
                        </div>
                    </div>

                    <!-- Table Content -->
                    <div class="table-responsive">
                        <table class="admin-table">
                            <thead>
                                <tr>
                                    <th style="width: 50px;">#</th>
                                    <th style="width: 170px;">Timestamp</th>
                                    <th style="width: 160px;">User</th>
                                    <th style="width: 200px;">Action</th>
                                    <th style="width: 140px;">Entity</th>
                                    <th>Details / Payload</th>
                                    <th style="width: 120px;">IP Address</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php if (empty($logs)): ?>
                                    <tr>
                                        <td colspan="7"
                                            style="text-align: center; padding: 36px; color: var(--text-muted);">
                                            No activity logs found matching the filter criteria.
                                        </td>
                                    </tr>
                                <?php else: ?>
                                    <?php foreach ($logs as $idx => $l): ?>
                                        <tr>
                                            <td><?= $offset + $idx + 1 ?></td>
                                            <td style="white-space: nowrap; font-size: 12.5px;">
                                                <?= date('d M Y, h:i:s A', strtotime($l['created_at'])) ?></td>
                                            <td>
                                                <?php if ($l['user_name']): ?>
                                                    <strong
                                                        style="color: var(--text-main);"><?= htmlspecialchars($l['user_name']) ?></strong><br>
                                                    <small
                                                        style="color: var(--text-muted); font-size: 11px;"><?= htmlspecialchars($l['user_role']) ?>
                                                        (<?= htmlspecialchars($l['employee_code'] ?? '-') ?>)</small>
                                                <?php else: ?>
                                                    <span style="color: var(--text-muted);">System / Guest</span>
                                                <?php endif; ?>
                                            </td>
                                            <td><code
                                                    style="font-weight: 700; color: #0369a1;"><?= htmlspecialchars($l['action']) ?></code>
                                            </td>
                                            <td><span class="badge"
                                                    style="background: #f1f5f9; color: #475569;"><?= htmlspecialchars($l['entity_type']) ?>
                                                    #<?= htmlspecialchars($l['entity_id'] ?: '-') ?></span></td>
                                            <td style="max-width: 320px; font-size: 11px;">
                                                <?php if ($l['new_data']): ?>
                                                    <pre
                                                        style="background: #f8fafc; padding: 6px; border-radius: 4px; overflow-x: auto; max-height: 90px;"><?= htmlspecialchars($l['new_data']) ?></pre>
                                                <?php else: ?>
                                                    <span style="color: var(--text-muted);">-</span>
                                                <?php endif; ?>
                                            </td>
                                            <td><small><code><?= htmlspecialchars($l['ip_address']) ?></code></small></td>
                                        </tr>
                                    <?php endforeach; ?>
                                <?php endif; ?>
                            </tbody>
                        </table>
                    </div>

                    <!-- Pagination Bar -->
                    <?php if ($total > 0): ?>
                        <?php
                        $fromItem = $offset + 1;
                        $toItem = min($offset + $limit, $total);
                        ?>
                        <div class="pagination-container">
                            <div class="pagination-info">
                                Showing <strong><?= $fromItem ?></strong> to <strong><?= $toItem ?></strong> of
                                <strong><?= number_format($total) ?></strong> audit events (Page
                                <strong><?= $page ?></strong> of <strong><?= $totalPages ?></strong>)
                            </div>

                            <?php if ($totalPages > 1): ?>
                                <div class="pagination-controls">
                                    <!-- First & Prev -->
                                    <a href="<?= buildPageUrl(1, $limit, $search, $actionFilter) ?>"
                                        class="page-btn <?= $page <= 1 ? 'disabled' : '' ?>" title="First Page">«</a>
                                    <a href="<?= buildPageUrl($page - 1, $limit, $search, $actionFilter) ?>"
                                        class="page-btn <?= $page <= 1 ? 'disabled' : '' ?>" title="Previous Page">‹</a>

                                    <!-- Numbered Pages (Sliding Window) -->
                                    <?php
                                    $startPage = max(1, $page - 2);
                                    $endPage = min($totalPages, $page + 2);
                                    if ($startPage > 1)
                                        echo '<span style="padding: 0 4px; color: var(--text-muted);">...</span>';
                                    for ($p = $startPage; $p <= $endPage; $p++):
                                        ?>
                                        <a href="<?= buildPageUrl($p, $limit, $search, $actionFilter) ?>"
                                            class="page-btn <?= $p === $page ? 'active' : '' ?>">
                                            <?= $p ?>
                                        </a>
                                    <?php endfor; ?>
                                    <?php if ($endPage < $totalPages)
                                        echo '<span style="padding: 0 4px; color: var(--text-muted);">...</span>'; ?>

                                    <!-- Next & Last -->
                                    <a href="<?= buildPageUrl($page + 1, $limit, $search, $actionFilter) ?>"
                                        class="page-btn <?= $page >= $totalPages ? 'disabled' : '' ?>" title="Next Page">›</a>
                                    <a href="<?= buildPageUrl($totalPages, $limit, $search, $actionFilter) ?>"
                                        class="page-btn <?= $page >= $totalPages ? 'disabled' : '' ?>" title="Last Page">»</a>
                                </div>
                            <?php endif; ?>
                        </div>
                    <?php endif; ?>
                </div>
            </main>
        </div>
    </div>

    <script>
        function changePageSize(val) {
            const url = new URL(window.location.href);
            url.searchParams.set('limit', val);
            url.searchParams.set('page', '1');
            window.location.href = url.toString();
        }
    </script>
</body>

</html>