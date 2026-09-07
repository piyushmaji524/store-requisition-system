<?php
/**
 * Store Requisition & Inventory Management System
 * Unified Enterprise Portal & App Download Hub
 * Designed & Developed by Piyush Maji
 */

// Helper to format file size
function getApkSizeFormatted($filePath) {
    if (file_exists($filePath)) {
        $bytes = filesize($filePath);
        if ($bytes >= 1048576) {
            return number_format($bytes / 1048576, 1) . ' MB';
        } elseif ($bytes >= 1024) {
            return number_format($bytes / 1024, 1) . ' KB';
        }
        return $bytes . ' B';
    }
    return '55+ MB';
}

$userApkSize = getApkSizeFormatted(__DIR__ . '/StoreRequisition.apk');
$storeApkSize = getApkSizeFormatted(__DIR__ . '/StoreTerminal.apk');
$adminApkSize = getApkSizeFormatted(__DIR__ . '/Gunayatan_Admin.apk');

$baseUrl = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? "https" : "http") . "://$_SERVER[HTTP_HOST]";
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Requisition System by Piyush — Store & Material Distribution Hub</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&family=Outfit:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
    
    <style>
        :root {
            /* Light Theme Color Palette */
            --bg-base: #f8fafc;
            --bg-surface: #ffffff;
            --bg-card: rgba(255, 255, 255, 0.88);
            --bg-card-hover: rgba(255, 255, 255, 0.98);
            --border-subtle: rgba(226, 232, 240, 0.9);
            --border-focus: rgba(99, 102, 241, 0.45);
            
            --primary: #4f46e5;
            --primary-light: #6366f1;
            --primary-glow: rgba(99, 102, 241, 0.18);
            
            --emerald: #10b981;
            --emerald-glow: rgba(16, 185, 129, 0.18);
            --amber: #f59e0b;
            --amber-glow: rgba(245, 158, 11, 0.18);
            --cyan: #06b6d4;
            --rose: #f43f5e;
            
            --text-main: #0f172a;
            --text-muted: #475569;
            --text-dim: #94a3b8;
            
            --radius-sm: 8px;
            --radius-md: 14px;
            --radius-lg: 20px;
            --radius-xl: 28px;
            
            --shadow-sm: 0 2px 4px rgba(15, 23, 42, 0.04);
            --shadow-md: 0 10px 25px -5px rgba(15, 23, 42, 0.06), 0 4px 6px -2px rgba(15, 23, 42, 0.03);
            --shadow-lg: 0 20px 40px -12px rgba(15, 23, 42, 0.12), 0 8px 12px -4px rgba(15, 23, 42, 0.04);
        }

        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
            font-family: 'Plus Jakarta Sans', sans-serif;
        }

        body {
            background-color: var(--bg-base);
            color: var(--text-main);
            min-height: 100vh;
            overflow-x: hidden;
            position: relative;
            line-height: 1.5;
        }

        /* Fluid Animation Canvas */
        #fluidCanvas {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            z-index: 0;
            pointer-events: none;
        }

        /* Ambient Background Mesh */
        .ambient-mesh {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            pointer-events: none;
            z-index: 0;
            overflow: hidden;
        }
        .orb-1 {
            position: absolute;
            top: -10%;
            left: 15%;
            width: 650px;
            height: 650px;
            background: radial-gradient(circle, rgba(99, 102, 241, 0.12) 0%, rgba(255,255,255,0) 70%);
            border-radius: 50%;
            filter: blur(60px);
            animation: float-slow 18s ease-in-out infinite alternate;
        }
        .orb-2 {
            position: absolute;
            top: 45%;
            right: -8%;
            width: 550px;
            height: 550px;
            background: radial-gradient(circle, rgba(16, 185, 129, 0.1) 0%, rgba(255,255,255,0) 70%);
            border-radius: 50%;
            filter: blur(70px);
            animation: float-slow 22s ease-in-out infinite alternate-reverse;
        }
        .orb-3 {
            position: absolute;
            bottom: -5%;
            left: 5%;
            width: 600px;
            height: 600px;
            background: radial-gradient(circle, rgba(6, 182, 212, 0.08) 0%, rgba(255,255,255,0) 70%);
            border-radius: 50%;
            filter: blur(65px);
        }

        @keyframes float-slow {
            0% { transform: translate(0, 0) scale(1); }
            50% { transform: translate(30px, -20px) scale(1.05); }
            100% { transform: translate(-25px, 25px) scale(0.95); }
        }

        .container {
            max-width: 1240px;
            margin: 0 auto;
            padding: 0 24px;
            position: relative;
            z-index: 1;
        }

        /* Top Navbar */
        nav.navbar {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 24px 0;
            border-bottom: 1px solid var(--border-subtle);
        }
        .brand {
            display: flex;
            align-items: center;
            gap: 14px;
            text-decoration: none;
            color: var(--text-main);
        }
        .brand-logo-badge {
            width: 44px;
            height: 44px;
            background: linear-gradient(135deg, var(--primary-light), #3b82f6);
            border-radius: 12px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 22px;
            color: white;
            box-shadow: 0 4px 15px var(--primary-glow);
        }
        .brand-text h1 {
            font-size: 20px;
            font-weight: 800;
            letter-spacing: -0.5px;
            font-family: 'Outfit', sans-serif;
            color: #0f172a;
        }
        .brand-text span {
            font-size: 12.5px;
            color: var(--text-muted);
            font-weight: 500;
            display: block;
        }
        .nav-status {
            display: flex;
            align-items: center;
            gap: 8px;
            background: rgba(16, 185, 129, 0.08);
            border: 1px solid rgba(16, 185, 129, 0.25);
            padding: 6px 14px;
            border-radius: 999px;
            font-size: 13px;
            font-weight: 600;
            color: #059669;
        }
        .status-dot {
            width: 8px;
            height: 8px;
            border-radius: 50%;
            background: #10b981;
            box-shadow: 0 0 10px #10b981;
            animation: pulse-dot 2s infinite ease-in-out;
        }

        @keyframes pulse-dot {
            0%, 100% { opacity: 1; transform: scale(1); }
            50% { opacity: 0.4; transform: scale(0.8); }
        }

        /* Hero Section */
        .hero {
            padding: 55px 0 35px;
            text-align: center;
        }
        .hero-pill {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            background: #eef2ff;
            border: 1px solid rgba(99, 102, 241, 0.25);
            color: #4f46e5;
            padding: 6px 16px;
            border-radius: 999px;
            font-size: 13px;
            font-weight: 700;
            margin-bottom: 20px;
            box-shadow: 0 2px 6px rgba(99, 102, 241, 0.08);
        }
        .hero h2 {
            font-size: 46px;
            font-weight: 800;
            font-family: 'Outfit', sans-serif;
            letter-spacing: -1.2px;
            line-height: 1.15;
            max-width: 860px;
            margin: 0 auto 18px;
            background: linear-gradient(180deg, #0f172a 20%, #334155 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        .hero p {
            font-size: 17px;
            color: var(--text-muted);
            max-width: 650px;
            margin: 0 auto 36px;
            font-weight: 400;
        }

        /* Section Headings */
        .section-header {
            display: flex;
            justify-content: space-between;
            align-items: flex-end;
            margin-bottom: 24px;
            padding-bottom: 12px;
            border-bottom: 1px solid var(--border-subtle);
        }
        .section-header h3 {
            font-size: 22px;
            font-weight: 700;
            font-family: 'Outfit', sans-serif;
            color: #0f172a;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .section-header h3 i {
            color: var(--primary);
        }
        .section-header span {
            font-size: 13px;
            color: var(--text-muted);
            font-weight: 500;
        }

        /* Grid Layouts */
        .grid-2 {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 24px;
            margin-bottom: 50px;
        }
        .grid-3 {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 24px;
            margin-bottom: 50px;
        }

        /* Glass Cards (Light Theme) */
        .card {
            background: var(--bg-card);
            backdrop-filter: blur(20px);
            -webkit-backdrop-filter: blur(20px);
            border: 1px solid var(--border-subtle);
            border-radius: var(--radius-lg);
            padding: 28px;
            transition: all 0.35s cubic-bezier(0.16, 1, 0.3, 1);
            position: relative;
            overflow: hidden;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
            box-shadow: var(--shadow-md);
        }
        .card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 4px;
            background: transparent;
            transition: background 0.3s ease;
        }
        .card:hover {
            transform: translateY(-6px);
            background: var(--bg-card-hover);
            border-color: var(--border-focus);
            box-shadow: var(--shadow-lg);
        }

        /* Web Portal Cards */
        .portal-admin:hover::before {
            background: linear-gradient(90deg, #4f46e5, #818cf8);
        }
        .portal-store:hover::before {
            background: linear-gradient(90deg, #059669, #34d399);
        }

        .portal-top {
            display: flex;
            align-items: flex-start;
            gap: 18px;
            margin-bottom: 20px;
        }
        .portal-icon-wrapper {
            width: 60px;
            height: 60px;
            border-radius: 16px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 26px;
            flex-shrink: 0;
        }
        .portal-icon-admin {
            background: #eef2ff;
            color: #4f46e5;
            border: 1px solid rgba(99, 102, 241, 0.2);
        }
        .portal-icon-store {
            background: #ecfdf5;
            color: #059669;
            border: 1px solid rgba(16, 185, 129, 0.2);
        }
        .portal-info h4 {
            font-size: 20px;
            font-weight: 700;
            color: #0f172a;
            margin-bottom: 6px;
            font-family: 'Outfit', sans-serif;
        }
        .portal-info p {
            font-size: 14px;
            color: var(--text-muted);
            line-height: 1.45;
        }

        .feature-bullets {
            list-style: none;
            margin-bottom: 24px;
            display: flex;
            flex-direction: column;
            gap: 10px;
        }
        .feature-bullets li {
            font-size: 13.5px;
            color: #334155;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .feature-bullets li i {
            font-size: 12px;
            width: 20px;
            height: 20px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .portal-admin .feature-bullets li i {
            background: #eef2ff;
            color: #4f46e5;
        }
        .portal-store .feature-bullets li i {
            background: #ecfdf5;
            color: #059669;
        }

        /* Action Buttons */
        .btn {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            gap: 10px;
            padding: 14px 22px;
            border-radius: var(--radius-md);
            font-size: 15px;
            font-weight: 600;
            text-decoration: none;
            cursor: pointer;
            transition: all 0.25s ease;
            border: none;
            width: 100%;
        }
        .btn-primary {
            background: linear-gradient(135deg, var(--primary), #4338ca);
            color: white;
            box-shadow: 0 4px 15px var(--primary-glow);
        }
        .btn-primary:hover {
            background: linear-gradient(135deg, var(--primary-light), var(--primary));
            box-shadow: 0 6px 20px rgba(99, 102, 241, 0.35);
            color: white;
            transform: translateY(-2px);
        }
        .btn-emerald {
            background: linear-gradient(135deg, #059669, #047857);
            color: white;
            box-shadow: 0 4px 15px var(--emerald-glow);
        }
        .btn-emerald:hover {
            background: linear-gradient(135deg, #10b981, #059669);
            box-shadow: 0 6px 20px rgba(16, 185, 129, 0.35);
            color: white;
            transform: translateY(-2px);
        }
        .btn-amber {
            background: linear-gradient(135deg, #d97706, #b45309);
            color: white;
            box-shadow: 0 4px 15px var(--amber-glow);
        }
        .btn-amber:hover {
            background: linear-gradient(135deg, #f59e0b, #d97706);
            box-shadow: 0 6px 20px rgba(245, 158, 11, 0.35);
            color: white;
            transform: translateY(-2px);
        }
        .btn-outline {
            background: #ffffff;
            color: #334155;
            border: 1px solid var(--border-subtle);
            box-shadow: var(--shadow-sm);
        }
        .btn-outline:hover {
            background: #f1f5f9;
            border-color: #cbd5e1;
            color: #0f172a;
        }

        /* App Cards */
        .app-card {
            display: flex;
            flex-direction: column;
            justify-content: space-between;
        }
        .app-top {
            display: flex;
            align-items: center;
            gap: 16px;
            margin-bottom: 18px;
        }
        .app-logo {
            width: 58px;
            height: 58px;
            border-radius: 16px;
            object-fit: cover;
            border: 1px solid var(--border-subtle);
            background: #ffffff;
            padding: 4px;
            flex-shrink: 0;
            box-shadow: 0 4px 12px rgba(15, 23, 42, 0.08);
        }
        .app-meta h4 {
            font-size: 18px;
            font-weight: 700;
            color: #0f172a;
            margin-bottom: 3px;
            font-family: 'Outfit', sans-serif;
        }
        .app-badge {
            display: inline-block;
            font-size: 11px;
            font-weight: 700;
            padding: 2px 8px;
            border-radius: 999px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        .badge-user {
            background: #eff6ff;
            color: #2563eb;
            border: 1px solid #bfdbfe;
        }
        .badge-store {
            background: #ecfdf5;
            color: #059669;
            border: 1px solid #a7f3d0;
        }
        .badge-admin {
            background: #fffbeb;
            color: #d97706;
            border: 1px solid #fde68a;
        }

        .app-desc {
            font-size: 13.5px;
            color: var(--text-muted);
            line-height: 1.5;
            margin-bottom: 20px;
        }

        .app-specs {
            display: flex;
            justify-content: space-between;
            align-items: center;
            background: #f8fafc;
            border: 1px solid var(--border-subtle);
            border-radius: var(--radius-sm);
            padding: 10px 14px;
            margin-bottom: 20px;
            font-size: 12.5px;
            color: var(--text-muted);
        }
        .app-specs span {
            color: #0f172a;
            font-weight: 700;
        }

        .app-action-group {
            display: flex;
            gap: 10px;
        }
        .btn-qr {
            width: 48px;
            height: 48px;
            flex-shrink: 0;
            padding: 0;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 16px;
            border-radius: var(--radius-md);
        }

        /* How it Works Section */
        .workflow-box {
            background: var(--bg-card);
            border: 1px solid var(--border-subtle);
            border-radius: var(--radius-xl);
            padding: 36px;
            margin-bottom: 60px;
            box-shadow: var(--shadow-md);
        }
        .workflow-grid {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 20px;
            position: relative;
        }
        .step-card {
            display: flex;
            flex-direction: column;
            gap: 10px;
            position: relative;
        }
        .step-num {
            width: 34px;
            height: 34px;
            border-radius: 50%;
            background: #eef2ff;
            border: 1px solid rgba(99, 102, 241, 0.3);
            color: #4f46e5;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 14px;
            font-weight: 800;
        }
        .step-card h5 {
            font-size: 16px;
            font-weight: 700;
            color: #0f172a;
        }
        .step-card p {
            font-size: 13px;
            color: var(--text-muted);
            line-height: 1.45;
        }

        /* Footer */
        footer {
            border-top: 1px solid var(--border-subtle);
            padding: 36px 0 28px;
            text-align: center;
            color: var(--text-muted);
            font-size: 13.5px;
        }
        footer a {
            color: var(--text-main);
            text-decoration: none;
            transition: color 0.2s;
        }
        .footer-dev-badge {
            margin-top: 12px;
            display: inline-flex;
            align-items: center;
            gap: 8px;
            background: #ffffff;
            border: 1px solid var(--border-subtle);
            padding: 7px 18px;
            border-radius: 999px;
            font-size: 13px;
            color: #475569;
            box-shadow: var(--shadow-sm);
        }
        .dev-link {
            color: #4f46e5 !important;
            font-weight: 700;
            text-decoration: underline;
            text-underline-offset: 3px;
            cursor: pointer;
            transition: all 0.2s ease;
        }
        .dev-link:hover {
            color: #4338ca !important;
        }

        /* Developer & License Modal (Light Theme) */
        .modal-overlay {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(15, 23, 42, 0.55);
            backdrop-filter: blur(8px);
            z-index: 999;
            display: none;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .modal-overlay.active {
            display: flex;
        }
        .dev-modal-content {
            background: #ffffff;
            border: 1px solid var(--border-subtle);
            border-radius: var(--radius-xl);
            max-width: 580px;
            width: 100%;
            padding: 32px;
            text-align: left;
            position: relative;
            box-shadow: var(--shadow-lg);
            max-height: 90vh;
            overflow-y: auto;
            animation: modal-pop 0.3s cubic-bezier(0.16, 1, 0.3, 1);
        }
        .dev-header {
            display: flex;
            align-items: center;
            gap: 18px;
            padding-bottom: 20px;
            border-bottom: 1px solid var(--border-subtle);
            margin-bottom: 20px;
        }
        .dev-avatar {
            width: 64px;
            height: 64px;
            border-radius: 18px;
            background: linear-gradient(135deg, #4f46e5, #3b82f6);
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 26px;
            font-weight: 800;
            color: #fff;
            box-shadow: 0 6px 20px var(--primary-glow);
            flex-shrink: 0;
        }
        .dev-title h3 {
            font-size: 22px;
            font-weight: 800;
            color: #0f172a;
            font-family: 'Outfit', sans-serif;
            letter-spacing: -0.5px;
        }
        .dev-title p {
            font-size: 13.5px;
            color: #4f46e5;
            font-weight: 600;
        }
        .dev-pill {
            display: inline-block;
            background: #ecfdf5;
            border: 1px solid #a7f3d0;
            color: #059669;
            padding: 2px 10px;
            border-radius: 999px;
            font-size: 11px;
            font-weight: 700;
            margin-top: 4px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        .dev-section-title {
            font-size: 13.5px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.8px;
            color: #64748b;
            margin-bottom: 10px;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        .license-box {
            background: #f8fafc;
            border: 1px solid var(--border-subtle);
            border-radius: var(--radius-md);
            padding: 16px;
            font-family: 'Courier New', Courier, monospace;
            font-size: 12px;
            line-height: 1.6;
            color: #334155;
            max-height: 200px;
            overflow-y: auto;
            margin-bottom: 20px;
            white-space: pre-wrap;
        }
        .license-box::-webkit-scrollbar {
            width: 6px;
        }
        .license-box::-webkit-scrollbar-thumb {
            background: #cbd5e1;
            border-radius: 4px;
        }
        .dev-tech-tags {
            display: flex;
            flex-wrap: wrap;
            gap: 8px;
            margin-bottom: 22px;
        }
        .dev-tag {
            background: #f1f5f9;
            border: 1px solid var(--border-subtle);
            padding: 4px 10px;
            border-radius: 6px;
            font-size: 12px;
            color: #334155;
            font-weight: 500;
        }

        /* QR Modal */
        .modal-content {
            background: #ffffff;
            border: 1px solid var(--border-subtle);
            border-radius: var(--radius-lg);
            max-width: 380px;
            width: 100%;
            padding: 30px;
            text-align: center;
            position: relative;
            box-shadow: var(--shadow-lg);
            animation: modal-pop 0.3s cubic-bezier(0.16, 1, 0.3, 1);
        }
        @keyframes modal-pop {
            0% { transform: scale(0.9); opacity: 0; }
            100% { transform: scale(1); opacity: 1; }
        }
        .modal-close {
            position: absolute;
            top: 16px;
            right: 16px;
            background: none;
            border: none;
            color: var(--text-dim);
            font-size: 20px;
            cursor: pointer;
            padding: 4px;
            transition: color 0.2s;
        }
        .modal-close:hover { color: #0f172a; }
        .qr-img-container {
            background: #ffffff;
            padding: 16px;
            border: 1px solid var(--border-subtle);
            border-radius: 12px;
            display: inline-block;
            margin: 18px 0;
            box-shadow: var(--shadow-sm);
        }
        .qr-img-container img {
            display: block;
            width: 180px;
            height: 180px;
        }

        /* Mobile Responsive */
        @media (max-width: 1024px) {
            .grid-3 { grid-template-columns: repeat(2, 1fr); }
            .workflow-grid { grid-template-columns: repeat(2, 1fr); }
        }
        @media (max-width: 768px) {
            .grid-2, .grid-3, .workflow-grid { grid-template-columns: 1fr; }
            .hero h2 { font-size: 32px; }
            .hero p { font-size: 15px; }
            nav.navbar { flex-direction: column; gap: 14px; text-align: center; }
            .dev-header { flex-direction: column; text-align: center; }
        }
    </style>
</head>
<body>

    <!-- Fluid Interactive Particles Canvas -->
    <canvas id="fluidCanvas"></canvas>

    <!-- Ambient Mesh Gradients -->
    <div class="ambient-mesh">
        <div class="orb-1"></div>
        <div class="orb-2"></div>
        <div class="orb-3"></div>
    </div>

    <div class="container">
        <!-- Navbar -->
        <nav class="navbar">
            <a href="/" class="brand">
                <div class="brand-logo-badge">
                    <i class="fa-solid fa-boxes-stacked"></i>
                </div>
                <div class="brand-text">
                    <h1>Requisition System</h1>
                    <span>Store Management & Distribution System • by Piyush</span>
                </div>
            </a>
            <div class="nav-status">
                <div class="status-dot"></div>
                <span>Server Online • 24/7 Live</span>
            </div>
        </nav>

        <!-- Hero Section -->
        <header class="hero">
            <div class="hero-pill">
                <i class="fa-solid fa-layer-group"></i> Unified Gateway & Apps Hub
            </div>
            <h2>Single Access Point for Web Panels & Mobile Terminals</h2>
            <p>Directly access the Admin & Store web management panels or download the dedicated Android APKs for Requesters, Storekeepers, and System Admins.</p>
        </header>

        <!-- 1. Web Portals Navigation -->
        <section>
            <div class="section-header">
                <h3><i class="fa-solid fa-globe"></i> Web Portals (Direct Navigation)</h3>
                <span>Access directly from any desktop or mobile browser</span>
            </div>

            <div class="grid-2">
                <!-- Admin Web Portal Card -->
                <div class="card portal-admin">
                    <div>
                        <div class="portal-top">
                            <div class="portal-icon-wrapper portal-icon-admin">
                                <i class="fa-solid fa-shield-halved"></i>
                            </div>
                            <div class="portal-info">
                                <h4>Admin Control Panel</h4>
                                <p>Master governance, user lifecycle, location masters, inventory rates, audit logs & system analytics.</p>
                            </div>
                        </div>

                        <ul class="feature-bullets">
                            <li><i class="fa-solid fa-check"></i> Manage Users, Roles & Department Assignments</li>
                            <li><i class="fa-solid fa-check"></i> Master Materials, Unit Rates & Quick Stock Control</li>
                            <li><i class="fa-solid fa-check"></i> Location & Department Requisition Analytics</li>
                            <li><i class="fa-solid fa-check"></i> Date Overrides & Security Activity Logs</li>
                        </ul>
                    </div>

                    <a href="/admin/" class="btn btn-primary">
                        <span>Launch Admin Portal</span>
                        <i class="fa-solid fa-arrow-up-right-from-square"></i>
                    </a>
                </div>

                <!-- Store Terminal Web Portal Card -->
                <div class="card portal-store">
                    <div>
                        <div class="portal-top">
                            <div class="portal-icon-wrapper portal-icon-store">
                                <i class="fa-solid fa-warehouse"></i>
                            </div>
                            <div class="portal-info">
                                <h4>Storekeeper Issue Terminal</h4>
                                <p>Live requisition queue, barcode scanning, stock register verification, partial issuance & Tally export.</p>
                            </div>
                        </div>

                        <ul class="feature-bullets">
                            <li><i class="fa-solid fa-check"></i> Real-time Live Pending & Emergency Indents Queue</li>
                            <li><i class="fa-solid fa-check"></i> 1-Click Material Issue, Balance Check & Sub-Orders</li>
                            <li><i class="fa-solid fa-check"></i> Print Issue Vouchers & Gatepass Slips</li>
                            <li><i class="fa-solid fa-check"></i> Automated Tally Prime / ERP Sales XML Export</li>
                        </ul>
                    </div>

                    <a href="/store/" class="btn btn-emerald">
                        <span>Launch Store Terminal</span>
                        <i class="fa-solid fa-arrow-up-right-from-square"></i>
                    </a>
                </div>
            </div>
        </section>

        <!-- 2. Mobile App Download Section -->
        <section>
            <div class="section-header">
                <h3><i class="fa-solid fa-mobile-screen-button"></i> Mobile Applications (Direct APK Download)</h3>
                <span>Install directly on Android devices (No Play Store required)</span>
            </div>

            <div class="grid-3">
                <!-- User App Card -->
                <div class="card app-card">
                    <div>
                        <div class="app-top">
                            <img src="/assets/images/user_app_logo.png" alt="User App Logo" class="app-logo" onerror="this.src='/assets/images/admin_app_logo.png'">
                            <div class="app-meta">
                                <h4>User Indent App</h4>
                                <span class="app-badge badge-user">For Employees / Departments</span>
                            </div>
                        </div>
                        <p class="app-desc">Create material requisitions, search real-time store catalogue, track approval & issue status, and flag emergency breakdowns.</p>
                        
                        <div class="app-specs">
                            <div>Version: <span>v1.0.4 (Release)</span></div>
                            <div>Size: <span><?= htmlspecialchars($userApkSize) ?></span></div>
                        </div>
                    </div>

                    <div class="app-action-group">
                        <a href="/StoreRequisition.apk" download="StoreRequisition.apk" class="btn btn-primary" style="flex: 1;">
                            <i class="fa-solid fa-download"></i>
                            <span>Download APK</span>
                        </a>
                        <button class="btn btn-outline btn-qr" title="Scan QR Code to Download" onclick="openQrModal('User Requisition App', '<?= $baseUrl ?>/StoreRequisition.apk')">
                            <i class="fa-solid fa-qrcode"></i>
                        </button>
                    </div>
                </div>

                <!-- Store App Card -->
                <div class="card app-card">
                    <div>
                        <div class="app-top">
                            <img src="/assets/images/store_app_logo.png" alt="Store App Logo" class="app-logo" onerror="this.src='/assets/images/admin_app_logo.png'">
                            <div class="app-meta">
                                <h4>Store Terminal App</h4>
                                <span class="app-badge badge-store">For Store Incharge / Staff</span>
                            </div>
                        </div>
                        <p class="app-desc">On-the-go material issuance terminal. Physical stock audit, quick stock corrections, barcode search, and offline receipt queue.</p>
                        
                        <div class="app-specs">
                            <div>Version: <span>v1.0.2 (Release)</span></div>
                            <div>Size: <span><?= htmlspecialchars($storeApkSize) ?></span></div>
                        </div>
                    </div>

                    <div class="app-action-group">
                        <a href="/StoreTerminal.apk" download="StoreTerminal.apk" class="btn btn-emerald" style="flex: 1;">
                            <i class="fa-solid fa-download"></i>
                            <span>Download APK</span>
                        </a>
                        <button class="btn btn-outline btn-qr" title="Scan QR Code to Download" onclick="openQrModal('Store Terminal App', '<?= $baseUrl ?>/StoreTerminal.apk')">
                            <i class="fa-solid fa-qrcode"></i>
                        </button>
                    </div>
                </div>

                <!-- Admin App Card -->
                <div class="card app-card">
                    <div>
                        <div class="app-top">
                            <img src="/assets/images/admin_app_logo.png" alt="Admin App Logo" class="app-logo">
                            <div class="app-meta">
                                <h4>Admin Mobile App</h4>
                                <span class="app-badge badge-admin">For Management & Super Admins</span>
                            </div>
                        </div>
                        <p class="app-desc">Executive oversight terminal. Real-time consumption KPIs, emergency notifications, user password resets, and stock balance adjustments.</p>
                        
                        <div class="app-specs">
                            <div>Version: <span>v1.0.3 (Release)</span></div>
                            <div>Size: <span><?= htmlspecialchars($adminApkSize) ?></span></div>
                        </div>
                    </div>

                    <div class="app-action-group">
                        <a href="/Gunayatan_Admin.apk" download="Gunayatan_Admin.apk" class="btn btn-amber" style="flex: 1;">
                            <i class="fa-solid fa-download"></i>
                            <span>Download APK</span>
                        </a>
                        <button class="btn btn-outline btn-qr" title="Scan QR Code to Download" onclick="openQrModal('Admin Management App', '<?= $baseUrl ?>/Gunayatan_Admin.apk')">
                            <i class="fa-solid fa-qrcode"></i>
                        </button>
                    </div>
                </div>
            </div>
        </section>

        <!-- 3. System Architecture & Workflow -->
        <section class="workflow-box">
            <div class="section-header" style="border: none; margin-bottom: 24px; padding: 0;">
                <h3><i class="fa-solid fa-arrows-split-up-and-left"></i> End-to-End Enterprise Workflow</h3>
            </div>
            <div class="workflow-grid">
                <div class="step-card">
                    <div class="step-num">1</div>
                    <h5>Indent Creation</h5>
                    <p>Department users raise indents via User Mobile App or Web Portal with quantities and location tags.</p>
                </div>
                <div class="step-card">
                    <div class="step-num">2</div>
                    <h5>Store Processing</h5>
                    <p>Storekeeper receives instant notification, verifies available balance, and issues materials.</p>
                </div>
                <div class="step-card">
                    <div class="step-num">3</div>
                    <h5>Voucher & Gatepass</h5>
                    <p>Automated issue voucher generated with item snapshots, rates, and recipient signatures.</p>
                </div>
                <div class="step-card">
                    <div class="step-num">4</div>
                    <h5>Tally ERP Sync</h5>
                    <p>Seamless automated XML export for Tally Prime ledger adjustments and cost center tracking.</p>
                </div>
            </div>
        </section>

        <!-- Footer -->
        <footer>
            <p>© <?= date('Y') ?> Requisition System by Piyush. All rights reserved.</p>
            <div class="footer-dev-badge">
                <span>Designed & Developed with <i class="fa-solid fa-heart" style="color: #f43f5e;"></i> by</span>
                <a href="javascript:void(0)" class="dev-link" onclick="openDeveloperModal()">Piyush Maji</a>
            </div>
            <p style="margin-top: 10px; font-size: 12px; color: var(--text-dim);">Open-Source System • Licensed under the MIT License</p>
        </footer>
    </div>

    <!-- Developer & MIT License Modal (Light Theme) -->
    <div class="modal-overlay" id="devModal" onclick="closeDeveloperModal(event)">
        <div class="dev-modal-content" onclick="event.stopPropagation()">
            <button class="modal-close" onclick="closeDeveloperModal()"><i class="fa-solid fa-xmark"></i></button>
            
            <div class="dev-header">
                <div class="dev-avatar">PM</div>
                <div class="dev-title">
                    <h3>Piyush Maji</h3>
                    <p>Lead System Architect & Full-Stack Developer</p>
                    <span class="dev-pill"><i class="fa-solid fa-code"></i> Project Author & Maintainer</span>
                </div>
            </div>

            <div class="dev-section-title">
                <i class="fa-solid fa-layer-group"></i> Architecture Highlights
            </div>
            <div class="dev-tech-tags">
                <span class="dev-tag"><i class="fa-brands fa-php"></i> High-Speed REST API Engine</span>
                <span class="dev-tag"><i class="fa-solid fa-mobile"></i> Flutter Enterprise Clients (Android/iOS)</span>
                <span class="dev-tag"><i class="fa-solid fa-database"></i> MySQL / MariaDB Relational Architecture</span>
                <span class="dev-tag"><i class="fa-solid fa-file-invoice"></i> Tally Prime ERP XML Sync</span>
                <span class="dev-tag"><i class="fa-solid fa-shield-halved"></i> Role-Based Access Control (RBAC)</span>
            </div>

            <div class="dev-section-title">
                <i class="fa-solid fa-scale-balanced"></i> MIT Open Source License
            </div>
            <div class="license-box">MIT License

Copyright (c) <?= date('Y') ?> Piyush Maji

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.</div>

            <button class="btn btn-outline" style="width: 100%;" onclick="closeDeveloperModal()">
                <i class="fa-solid fa-check"></i> Close Window
            </button>
        </div>
    </div>

    <!-- QR Code Modal (Light Theme) -->
    <div class="modal-overlay" id="qrModal" onclick="closeQrModal(event)">
        <div class="modal-content" onclick="event.stopPropagation()">
            <button class="modal-close" onclick="closeQrModal()"><i class="fa-solid fa-xmark"></i></button>
            <h4 id="modalAppTitle" style="font-size: 18px; font-weight: 700; color: #0f172a; font-family: 'Outfit', sans-serif;">Download App</h4>
            <p style="font-size: 13px; color: var(--text-muted); margin-top: 4px;">Scan this QR code with your mobile camera to download the APK directly</p>
            
            <div class="qr-img-container">
                <img id="qrCodeImage" src="" alt="App Download QR Code">
            </div>

            <div style="background: #f1f5f9; padding: 10px 14px; border-radius: 8px; font-size: 12px; color: #475569; word-break: break-all;" id="modalApkUrl">
            </div>
        </div>
    </div>

    <!-- Fluid Interactive Particles Animation Script -->
    <script>
        const canvas = document.getElementById('fluidCanvas');
        const ctx = canvas.getContext('2d');

        let width, height;
        let particles = [];
        let mouse = { x: null, y: null, radius: 150 };

        function resizeCanvas() {
            width = canvas.width = window.innerWidth;
            height = canvas.height = window.innerHeight;
            initParticles();
        }

        class FluidParticle {
            constructor() {
                this.x = Math.random() * width;
                this.y = Math.random() * height;
                this.vx = (Math.random() - 0.5) * 0.7;
                this.vy = (Math.random() - 0.5) * 0.7;
                this.radius = Math.random() * 2.5 + 1.2;
                
                // Color palette: Indigo, Emerald, Amber, Cyan
                const colors = [
                    'rgba(99, 102, 241, 0.45)', // Indigo
                    'rgba(16, 185, 129, 0.45)', // Emerald
                    'rgba(245, 158, 11, 0.40)', // Amber
                    'rgba(6, 182, 212, 0.45)',  // Cyan
                    'rgba(139, 92, 246, 0.40)'  // Purple
                ];
                this.color = colors[Math.floor(Math.random() * colors.length)];
                this.baseX = this.x;
                this.baseY = this.y;
                this.density = (Math.random() * 20) + 1;
            }

            update() {
                // Mouse interaction / Fluid push effect
                if (mouse.x !== null && mouse.y !== null) {
                    let dx = mouse.x - this.x;
                    let dy = mouse.y - this.y;
                    let distance = Math.sqrt(dx * dx + dy * dy);
                    if (distance < mouse.radius) {
                        let force = (mouse.radius - distance) / mouse.radius;
                        let directionX = (dx / distance) * force * this.density * 0.6;
                        let directionY = (dy / distance) * force * this.density * 0.6;
                        this.x -= directionX;
                        this.y -= directionY;
                    }
                }

                // Normal drift
                this.x += this.vx;
                this.y += this.vy;

                // Bounce at edges
                if (this.x < 0 || this.x > width) this.vx = -this.vx;
                if (this.y < 0 || this.y > height) this.vy = -this.vy;
            }

            draw() {
                ctx.beginPath();
                ctx.arc(this.x, this.y, this.radius, 0, Math.PI * 2);
                ctx.fillStyle = this.color;
                ctx.fill();
            }
        }

        function initParticles() {
            particles = [];
            // Responsive particle count
            const count = Math.min(80, Math.floor((width * height) / 16000));
            for (let i = 0; i < count; i++) {
                particles.push(new FluidParticle());
            }
        }

        function connectParticles() {
            for (let a = 0; a < particles.length; a++) {
                for (let b = a + 1; b < particles.length; b++) {
                    let dx = particles[a].x - particles[b].x;
                    let dy = particles[a].y - particles[b].y;
                    let distance = Math.sqrt(dx * dx + dy * dy);

                    if (distance < 130) {
                        let opacity = (1 - (distance / 130)) * 0.18;
                        ctx.strokeStyle = `rgba(99, 102, 241, ${opacity})`;
                        ctx.lineWidth = 1;
                        ctx.beginPath();
                        ctx.moveTo(particles[a].x, particles[a].y);
                        ctx.lineTo(particles[b].x, particles[b].y);
                        ctx.stroke();
                    }
                }
            }
        }

        function animate() {
            ctx.clearRect(0, 0, width, height);

            for (let i = 0; i < particles.length; i++) {
                particles[i].update();
                particles[i].draw();
            }
            connectParticles();

            requestAnimationFrame(animate);
        }

        window.addEventListener('resize', resizeCanvas);
        window.addEventListener('mousemove', (e) => {
            mouse.x = e.x;
            mouse.y = e.y;
        });
        window.addEventListener('mouseleave', () => {
            mouse.x = null;
            mouse.y = null;
        });

        // Initialize Canvas
        resizeCanvas();
        animate();

        // Modals Logic
        function openQrModal(appName, apkUrl) {
            document.getElementById('modalAppTitle').innerText = appName;
            document.getElementById('modalApkUrl').innerText = apkUrl;
            
            const qrApiUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=' + encodeURIComponent(apkUrl);
            document.getElementById('qrCodeImage').src = qrApiUrl;
            
            document.getElementById('qrModal').classList.add('active');
        }

        function closeQrModal(event) {
            document.getElementById('qrModal').classList.remove('active');
        }

        function openDeveloperModal() {
            document.getElementById('devModal').classList.add('active');
        }

        function closeDeveloperModal(event) {
            document.getElementById('devModal').classList.remove('active');
        }

        // Close on ESC
        document.addEventListener('keydown', function(e) {
            if (e.key === 'Escape') {
                closeQrModal();
                closeDeveloperModal();
            }
        });
    </script>
</body>
</html>
