<?php
/**
 * Shared Store Panel Sidebar
 * Consistent navigation across all Store pages
 */
$currentPage = basename($_SERVER['PHP_SELF']);
?>
<aside class="sidebar">
    <div class="sidebar-header">
        <div class="brand-icon">🏪</div>
        <div class="brand-title">STORE PANEL</div>
    </div>

    <div class="sidebar-content">
        <div class="nav-group">
            <div class="nav-section-title">MAIN</div>
            <ul class="nav-list">
                <li class="nav-item <?= $currentPage === 'index.php' ? 'active' : '' ?>">
                    <a href="/store/index.php"><span class="icon">📋</span> Requisition List</a>
                </li>
                <li class="nav-item <?= $currentPage === 'emergency.php' ? 'active' : '' ?>">
                    <a href="/store/emergency.php"><span class="icon">⚡</span> Emergency Issue</a>
                </li>
                <li class="nav-item <?= $currentPage === 'history.php' ? 'active' : '' ?>">
                    <a href="/store/history.php"><span class="icon">🕒</span> Issue History</a>
                </li>
                <li class="nav-item <?= $currentPage === 'stock.php' ? 'active' : '' ?>">
                    <a href="/store/stock.php"><span class="icon">🏷️</span> Material & Stock Master</a>
                </li>
            </ul>
        </div>
    </div>

    <div class="sidebar-footer">
        <a href="/store/login.php?action=logout" class="logout-link">
            <span class="icon">🚪</span> Logout
        </a>
    </div>
</aside>
