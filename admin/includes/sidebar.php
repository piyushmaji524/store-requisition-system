<?php
/**
 * Shared Admin Panel Sidebar
 * Consistent navigation across all Admin pages
 */
$currentPage = basename($_SERVER['PHP_SELF']);
?>
<aside class="sidebar">
    <div class="sidebar-header">
        <div class="brand-icon">🏢</div>
        <div class="brand-info">
            <span class="brand-title">REQUISITION SYSTEM</span>
            <span class="brand-sub">ADMIN PANEL</span>
        </div>
    </div>
    <div class="sidebar-content">
        <div class="nav-group">
            <div class="nav-section-title">MAIN</div>
            <ul class="nav-list">
                <li class="nav-item <?= $currentPage === 'index.php' ? 'active' : '' ?>">
                    <a href="/admin/index.php"><span class="nav-link-left"><span class="icon">📊</span> Dashboard</span></a>
                </li>
                <li class="nav-item <?= $currentPage === 'requisitions.php' ? 'active' : '' ?>">
                    <a href="/admin/requisitions.php"><span class="nav-link-left"><span class="icon">📋</span> Requisitions</span></a>
                </li>
                <li class="nav-item <?= $currentPage === 'tally_export.php' ? 'active' : '' ?>">
                    <a href="/admin/tally_export.php"><span class="nav-link-left"><span class="icon">📑</span> Tally Export</span></a>
                </li>
                <li class="nav-item <?= $currentPage === 'reports.php' ? 'active' : '' ?>">
                    <a href="/admin/reports.php"><span class="nav-link-left"><span class="icon">📈</span> Reports & Analytics</span></a>
                </li>
            </ul>
        </div>
        <div class="nav-group">
            <div class="nav-section-title">MASTER DATA</div>
            <ul class="nav-list">
                <li class="nav-item <?= $currentPage === 'users.php' ? 'active' : '' ?>">
                    <a href="/admin/users.php"><span class="nav-link-left"><span class="icon">👥</span> Users</span></a>
                </li>
                <li class="nav-item <?= $currentPage === 'locations.php' ? 'active' : '' ?>">
                    <a href="/admin/locations.php"><span class="nav-link-left"><span class="icon">📍</span> Locations</span></a>
                </li>
                <li class="nav-item <?= $currentPage === 'materials.php' ? 'active' : '' ?>">
                    <a href="/admin/materials.php"><span class="nav-link-left"><span class="icon">🏷️</span> Materials</span></a>
                </li>
                <li class="nav-item <?= $currentPage === 'material_import.php' ? 'active' : '' ?>">
                    <a href="/admin/material_import.php"><span class="nav-link-left"><span class="icon">📥</span> Tally Import</span></a>
                </li>
            </ul>
        </div>
        <div class="nav-group">
            <div class="nav-section-title">ADMINISTRATION</div>
            <ul class="nav-list">
                <li class="nav-item <?= $currentPage === 'date_overrides.php' ? 'active' : '' ?>">
                    <a href="/admin/date_overrides.php"><span class="nav-link-left"><span class="icon">🛡️</span> Date Override</span></a>
                </li>
                <li class="nav-item <?= $currentPage === 'settings.php' ? 'active' : '' ?>">
                    <a href="/admin/settings.php"><span class="nav-link-left"><span class="icon">⚙️</span> Settings</span></a>
                </li>
                <li class="nav-item <?= $currentPage === 'activity_logs.php' ? 'active' : '' ?>">
                    <a href="/admin/activity_logs.php"><span class="nav-link-left"><span class="icon">📜</span> Activity Logs</span></a>
                </li>
            </ul>
        </div>
    </div>
    <div class="sidebar-footer">
        <a href="/admin/login.php?action=logout" class="logout-link"><span class="icon">🚪</span> Logout</a>
    </div>
</aside>
