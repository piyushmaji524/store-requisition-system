<?php
/**
 * ADMIN PANEL - LOGIN & AUTHENTICATION
 * Production-Ready, Secure & Premium ERP Admin Login UI
 */

require_once __DIR__ . '/../config/config.php';
require_once __DIR__ . '/../core/Database.php';
require_once __DIR__ . '/../core/Session.php';
require_once __DIR__ . '/../core/Auth.php';

Session::start();

// Handle Logout
if (isset($_GET['action']) && $_GET['action'] === 'logout') {
    Auth::logoutWeb();
    header('Location: /admin/login.php');
    exit;
}

// Redirect if already logged in as Admin
if (Session::get('user_id')) {
    $user = Auth::user();
    if ($user && in_array($user['role'], ['SUPER_ADMIN', 'ADMIN'])) {
        header('Location: /admin/index.php');
        exit;
    }
}

$error = null;
$identifier = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $identifier = trim($_POST['identifier'] ?? '');
    $password = trim($_POST['password'] ?? '');

    if (empty($identifier) || empty($password)) {
        $error = 'Employee Code / Email and Password are required.';
    } else {
        $user = Auth::attempt($identifier, $password);
        if ($user && in_array($user['role'], ['SUPER_ADMIN', 'ADMIN'])) {
            Auth::loginWeb($user);
            header('Location: /admin/index.php');
            exit;
        } else {
            $error = 'Invalid admin credentials or unauthorized role.';
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Admin Login - <?= htmlspecialchars(Config::get('APP_NAME')) ?></title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        }
        body {
            background-color: #070d1e;
            background-image: 
                radial-gradient(at 0% 0%, rgba(79, 70, 229, 0.25) 0px, transparent 50%),
                radial-gradient(at 100% 100%, rgba(15, 23, 42, 0.9) 0px, transparent 50%),
                radial-gradient(at 50% 50%, rgba(37, 99, 235, 0.12) 0px, transparent 60%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 24px;
            color: #1e293b;
        }
        .login-card {
            background: #ffffff;
            width: 100%;
            max-width: 440px;
            border-radius: 20px;
            padding: 40px 36px;
            box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.4), 0 0 0 1px rgba(255, 255, 255, 0.1);
            position: relative;
            overflow: hidden;
        }
        .login-card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 5px;
            background: linear-gradient(90deg, #4f46e5, #6366f1, #3b82f6);
        }
        .brand-header {
            text-align: center;
            margin-bottom: 30px;
        }
        .brand-logo-wrap {
            width: 64px;
            height: 64px;
            background: linear-gradient(135deg, #3730a3, #4f46e5);
            border-radius: 18px;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            font-size: 30px;
            margin-bottom: 16px;
            box-shadow: 0 10px 20px -5px rgba(79, 70, 229, 0.4);
        }
        .brand-title {
            font-size: 22px;
            font-weight: 800;
            color: #0f172a;
            letter-spacing: -0.5px;
        }
        .brand-badge {
            display: inline-block;
            margin-top: 6px;
            background: #eef2ff;
            color: #4f46e5;
            font-size: 11.5px;
            font-weight: 700;
            padding: 3px 10px;
            border-radius: 20px;
            letter-spacing: 0.5px;
            text-transform: uppercase;
        }
        .alert-error {
            background: #fef2f2;
            color: #b91c1c;
            border: 1px solid #fecaca;
            border-radius: 12px;
            padding: 12px 14px;
            font-size: 13px;
            font-weight: 500;
            margin-bottom: 22px;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .form-group {
            margin-bottom: 20px;
        }
        .form-label {
            display: block;
            font-size: 12.5px;
            font-weight: 700;
            color: #334155;
            margin-bottom: 7px;
        }
        .input-wrapper {
            position: relative;
            display: flex;
            align-items: center;
        }
        .input-icon {
            position: absolute;
            left: 14px;
            color: #94a3b8;
            font-size: 16px;
            pointer-events: none;
            user-select: none;
        }
        .form-input {
            width: 100%;
            padding: 12px 14px 12px 42px;
            font-size: 14px;
            color: #0f172a;
            background: #f8fafc;
            border: 1.5px solid #e2e8f0;
            border-radius: 12px;
            outline: none;
            transition: all 0.2s ease;
        }
        .form-input:focus {
            background: #ffffff;
            border-color: #4f46e5;
            box-shadow: 0 0 0 4px rgba(79, 70, 229, 0.12);
        }
        .toggle-password {
            position: absolute;
            right: 12px;
            background: none;
            border: none;
            color: #94a3b8;
            cursor: pointer;
            padding: 4px;
            font-size: 14px;
            display: flex;
            align-items: center;
            justify-content: center;
            border-radius: 6px;
        }
        .toggle-password:hover {
            color: #475569;
        }
        .btn-submit {
            width: 100%;
            padding: 13px;
            background: linear-gradient(135deg, #4f46e5, #4338ca);
            color: #ffffff;
            font-size: 14.5px;
            font-weight: 700;
            border: none;
            border-radius: 12px;
            cursor: pointer;
            box-shadow: 0 4px 12px rgba(79, 70, 229, 0.3);
            transition: all 0.2s ease;
            margin-top: 6px;
        }
        .btn-submit:hover {
            background: linear-gradient(135deg, #4338ca, #3730a3);
            box-shadow: 0 6px 16px rgba(79, 70, 229, 0.4);
            transform: translateY(-1px);
        }
        .btn-submit:active {
            transform: translateY(0);
        }
        .login-footer {
            margin-top: 26px;
            padding-top: 18px;
            border-top: 1px solid #f1f5f9;
            display: flex;
            align-items: center;
            justify-content: space-between;
            font-size: 12px;
            color: #64748b;
        }
        .system-status {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            font-weight: 600;
            color: #16a34a;
        }
        .status-dot {
            width: 7px;
            height: 7px;
            background: #16a34a;
            border-radius: 50%;
            box-shadow: 0 0 0 2px rgba(22, 163, 74, 0.2);
        }
    </style>
</head>
<body>

<div class="login-card">
    <div class="brand-header">
        <div class="brand-logo-wrap">🏢</div>
        <h1 class="brand-title">ADMIN PORTAL</h1>
        <span class="brand-badge">Central ERP Administration</span>
    </div>

    <?php if ($error): ?>
        <div class="alert-error">
            <span>⚠️</span>
            <span><?= htmlspecialchars($error) ?></span>
        </div>
    <?php endif; ?>

    <form method="POST" autocomplete="off">
        <div class="form-group">
            <label class="form-label" for="identifier">Employee Code or Email Address</label>
            <div class="input-wrapper">
                <span class="input-icon">👤</span>
                <input 
                    type="text" 
                    id="identifier"
                    name="identifier" 
                    class="form-input" 
                    placeholder="e.g. EMP-001 or admin@store.local" 
                    value="<?= htmlspecialchars($identifier) ?>" 
                    required 
                    autofocus
                >
            </div>
        </div>

        <div class="form-group">
            <label class="form-label" for="password">Password</label>
            <div class="input-wrapper">
                <span class="input-icon">🔒</span>
                <input 
                    type="password" 
                    id="password"
                    name="password" 
                    class="form-input" 
                    placeholder="Enter your admin password" 
                    required
                >
                <button type="button" class="toggle-password" id="togglePasswordBtn" title="Show / Hide Password">
                    👁️
                </button>
            </div>
        </div>

        <button type="submit" class="btn-submit">
            Sign In to Admin Portal →
        </button>
    </form>

    <div class="login-footer">
        <div class="system-status">
            <span class="status-dot"></span>
            <span>Admin Gateway Secure</span>
        </div>
        <span>Gunayatan ERP v2.0</span>
    </div>
</div>

<script>
    const toggleBtn = document.getElementById('togglePasswordBtn');
    const pwdInput = document.getElementById('password');

    if (toggleBtn && pwdInput) {
        toggleBtn.addEventListener('click', () => {
            const isPwd = pwdInput.type === 'password';
            pwdInput.type = isPwd ? 'text' : 'password';
            toggleBtn.style.opacity = isPwd ? '1' : '0.6';
        });
    }
</script>
</body>
</html>
