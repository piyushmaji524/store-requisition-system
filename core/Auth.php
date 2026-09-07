<?php
/**
 * Authentication & Role-Based Access Control (RBAC)
 * Supports Token-based Auth (Mobile/REST) & Session-based Auth (Web)
 */

require_once __DIR__ . '/Database.php';
require_once __DIR__ . '/Request.php';
require_once __DIR__ . '/Response.php';
require_once __DIR__ . '/Session.php';
require_once __DIR__ . '/../config/config.php';

class Auth {
    private static ?array $currentUser = null;

    /**
     * Attempt login with credentials (supports employee_code, email, or mobile)
     */
    public static function attempt(string $identifier, string $password): ?array {
        $sql = "SELECT u.*, d.name AS department_name 
                FROM users u
                LEFT JOIN departments d ON u.department_id = d.id
                WHERE (u.employee_code = :id1 OR u.email = :id2 OR u.mobile = :id3)
                  AND u.status = 'ACTIVE'
                LIMIT 1";

        $user = Database::queryOne($sql, [
            ':id1' => $identifier,
            ':id2' => $identifier,
            ':id3' => $identifier
        ]);

        if ($user && password_verify($password, $user['password_hash'])) {
            unset($user['password_hash']);
            return $user;
        }

        return null;
    }

    /**
     * Create an API Bearer token for Mobile app
     */
    public static function createApiToken(int $userId, ?string $deviceName = 'Mobile App'): string {
        $plainTextToken = bin2hex(random_bytes(32));
        $tokenHash = hash('sha256', $plainTextToken);
        $expiryDays = (int) Config::get('TOKEN_EXPIRY_DAYS', 30);
        $expiresAt = date('Y-m-d H:i:s', strtotime("+{$expiryDays} days"));

        $sql = "INSERT INTO user_tokens (user_id, token_hash, device_name, expires_at, created_at)
                VALUES (:user_id, :token_hash, :device_name, :expires_at, NOW())";
        
        Database::execute($sql, [
            ':user_id'     => $userId,
            ':token_hash'  => $tokenHash,
            ':device_name' => $deviceName,
            ':expires_at'  => $expiresAt
        ]);

        return $plainTextToken;
    }

    /**
     * Authenticate request from Bearer Token or PHP Session
     */
    public static function user(): ?array {
        if (self::$currentUser !== null) {
            return self::$currentUser;
        }

        // 1. Check Bearer Token (API / Flutter)
        $bearerToken = Request::bearerToken();
        if ($bearerToken) {
            $tokenHash = hash('sha256', $bearerToken);
            $sql = "SELECT u.*, d.name AS department_name, t.id AS token_id
                    FROM user_tokens t
                    JOIN users u ON t.user_id = u.id
                    LEFT JOIN departments d ON u.department_id = d.id
                    WHERE t.token_hash = :hash
                      AND t.expires_at > NOW()
                      AND u.status = 'ACTIVE'
                    LIMIT 1";

            $user = Database::queryOne($sql, [':hash' => $tokenHash]);
            if ($user) {
                // Update last used timestamp
                Database::execute("UPDATE user_tokens SET last_used_at = NOW() WHERE id = :id", [':id' => $user['token_id']]);
                unset($user['password_hash']);
                self::$currentUser = $user;
                return self::$currentUser;
            }
        }

        // 2. Check Session (Web Admin / Store)
        $sessionUserId = Session::get('user_id');
        if ($sessionUserId) {
            $sql = "SELECT u.*, d.name AS department_name
                    FROM users u
                    LEFT JOIN departments d ON u.department_id = d.id
                    WHERE u.id = :id AND u.status = 'ACTIVE'
                    LIMIT 1";

            $user = Database::queryOne($sql, [':id' => $sessionUserId]);
            if ($user) {
                unset($user['password_hash']);
                self::$currentUser = $user;
                return self::$currentUser;
            }
        }

        return null;
    }

    /**
     * Require authentication middleware
     */
    public static function requireAuth(): array {
        $user = self::user();
        if (!$user) {
            Response::unauthorized('Authentication required to access this resource.');
        }
        return $user;
    }

    /**
     * Require specific roles
     */
    public static function requireRole(array|string $roles): array {
        $user = self::requireAuth();
        $allowedRoles = is_array($roles) ? $roles : [$roles];

        if (!in_array($user['role'], $allowedRoles, true)) {
            Response::forbidden('You do not have permission to perform this action.');
        }

        return $user;
    }

    /**
     * Revoke current API token
     */
    public static function revokeCurrentToken(): bool {
        $bearerToken = Request::bearerToken();
        if ($bearerToken) {
            $tokenHash = hash('sha256', $bearerToken);
            Database::execute("DELETE FROM user_tokens WHERE token_hash = :hash", [':hash' => $tokenHash]);
            return true;
        }
        return false;
    }

    /**
     * Web login session initialization
     */
    public static function loginWeb(array $user): void {
        Session::start();
        session_regenerate_id(true);
        Session::set('user_id', $user['id']);
        Session::set('user_name', $user['name']);
        Session::set('user_role', $user['role']);
        Session::set('employee_code', $user['employee_code']);
    }

    /**
     * Web logout session termination
     */
    public static function logoutWeb(): void {
        Session::destroy();
    }
}
