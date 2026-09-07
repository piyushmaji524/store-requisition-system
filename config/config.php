<?php
/**
 * Application Global Configuration
 * Timezone: Asia/Kolkata
 */

// Force Authoritative Server Timezone
date_default_timezone_set('Asia/Kolkata');

class Config {
    private static array $settings = [
        'APP_NAME'              => 'Store Requisition Management System',
        'APP_ENV'               => 'production', // development | production
        'BASE_URL'              => 'http://localhost:8000',
        'TIMEZONE'              => 'Asia/Kolkata',
        
        // Business Windows (24-hr format)
        'USER_REQUEST_START'    => '06:00',
        'USER_REQUEST_END'      => '20:00',
        'STORE_EDIT_START'      => '06:00',
        'STORE_EDIT_END'        => '21:00',
        
        // Overrides & Defaults
        'ADMIN_OVERRIDE_HOURS'  => 2,
        'DEFAULT_SALES_LEDGER'  => 'SALE',
        'SUB_REQ_SUFFIX_MODE'   => 'SEQUENTIAL', // 'SEQUENTIAL' (e.g. 01, 02) or 'LOCATION_CODE'
        
        // Auth & Security
        'TOKEN_EXPIRY_DAYS'     => 30,
        'SESSION_LIFETIME_MINS' => 480, // 8 hours
        'SESSION_COOKIE_NAME'   => 'store_req_session',
        'CSRF_TOKEN_KEY'        => 'csrf_token',

        // OneSignal Push Notifications (User App)
        'ONESIGNAL_APP_ID'             => '',
        'ONESIGNAL_REST_API_KEY'       => '',

        // OneSignal Push Notifications (Store Terminal App)
        'ONESIGNAL_STORE_APP_ID'       => '',
        'ONESIGNAL_STORE_REST_API_KEY' => ''
    ];

    private static bool $dbLoaded = false;

    private static function loadDbSettings(): void {
        if (self::$dbLoaded) {
            return;
        }
        self::$dbLoaded = true;

        try {
            if (!class_exists('Database')) {
                $dbFile = __DIR__ . '/../core/Database.php';
                if (file_exists($dbFile)) {
                    require_once $dbFile;
                }
            }

            if (class_exists('Database')) {
                $rows = Database::query("SELECT setting_key, setting_value FROM settings");
                if (is_array($rows)) {
                    foreach ($rows as $r) {
                        if (!empty($r['setting_key'])) {
                            self::$settings[$r['setting_key']] = $r['setting_value'];
                        }
                    }
                }
            }
        } catch (Throwable $e) {
            // In case DB is not yet available or in installation phase, fallback to file defaults safely
        }
    }

    public static function get(string $key, mixed $default = null): mixed {
        self::loadDbSettings();
        return self::$settings[$key] ?? $default;
    }

    public static function set(string $key, mixed $value): void {
        self::$settings[$key] = $value;
    }

    public static function reload(): void {
        self::$dbLoaded = false;
        self::loadDbSettings();
    }

    public static function all(): array {
        self::loadDbSettings();
        return self::$settings;
    }
}
