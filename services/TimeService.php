<?php
/**
 * Authoritative IST Time & Business Window Service
 * Strictly enforces all server-side time windows and cutoffs
 */

require_once __DIR__ . '/../config/config.php';
require_once __DIR__ . '/../core/Database.php';

class TimeService {
    /**
     * Get current server time in Asia/Kolkata timezone
     */
    public static function now(): DateTimeImmutable {
        return new DateTimeImmutable('now', new DateTimeZone(Config::get('TIMEZONE', 'Asia/Kolkata')));
    }

    /**
     * Check if user request window is open (Default: 06:00 AM - 08:00 PM IST)
     */
    public static function isUserRequestWindowOpen(): bool {
        $now = self::now();
        $currentTimeStr = $now->format('H:i');
        
        $startTimeStr = Config::get('USER_REQUEST_START', '06:00');
        $endTimeStr = Config::get('USER_REQUEST_END', '20:00');
        
        return ($currentTimeStr >= $startTimeStr && $currentTimeStr < $endTimeStr);
    }

    /**
     * Check if Store edit window is open for a given requisition date
     * Standard: Today until 09:00 PM IST
     * Past date / after 09:00 PM: Requires valid, active Admin Date Override
     */
    public static function isStoreEditAllowed(string $requisitionDate): bool {
        $now = self::now();
        $todayStr = $now->format('Y-m-d');
        
        // 1. If today's requisition, check if within standard window (06:00 AM - 09:00 PM)
        if ($requisitionDate === $todayStr) {
            $currentTimeStr = $now->format('H:i');
            $storeStartStr = Config::get('STORE_EDIT_START', '06:00');
            $storeCutoffStr = Config::get('STORE_EDIT_END', '21:00');
            if ($currentTimeStr >= $storeStartStr && $currentTimeStr < $storeCutoffStr) {
                return true;
            }
        }

        // 2. Check if an active Admin Date Override exists for this date
        return self::isDateOverrideActive($requisitionDate);
    }

    /**
     * Check if an active Admin Date Override exists and is not expired
     */
    public static function isDateOverrideActive(string $date): bool {
        $sql = "SELECT id, expires_at 
                FROM admin_date_overrides 
                WHERE override_date = :date 
                  AND status = 'OPEN' 
                  AND expires_at > NOW() 
                ORDER BY id DESC 
                LIMIT 1";

        $override = Database::queryOne($sql, [':date' => $date]);
        return ($override !== null);
    }

    /**
     * Get active override details if any
     */
    public static function getActiveDateOverride(string $date): ?array {
        $sql = "SELECT o.*, u.name AS opened_by_name 
                FROM admin_date_overrides o
                JOIN users u ON o.opened_by = u.id
                WHERE o.override_date = :date 
                  AND o.status = 'OPEN' 
                  AND o.expires_at > NOW() 
                ORDER BY o.id DESC 
                LIMIT 1";

        return Database::queryOne($sql, [':date' => $date]);
    }

    /**
     * Get comprehensive timing metadata for UI and API clients
     */
    public static function getTimingStatus(string $date = ''): array {
        $now = self::now();
        $todayStr = $now->format('Y-m-d');
        $targetDate = $date ?: $todayStr;

        $userWindowOpen = self::isUserRequestWindowOpen();
        $storeEditAllowed = self::isStoreEditAllowed($targetDate);
        $activeOverride = self::getActiveDateOverride($targetDate);

        $userStart = Config::get('USER_REQUEST_START', '06:00');
        $userEnd = Config::get('USER_REQUEST_END', '20:00');
        $storeStart = Config::get('STORE_EDIT_START', '06:00');
        $storeCutoff = Config::get('STORE_EDIT_END', '21:00');

        $userStartFmt = date('h:i A', strtotime("2000-01-01 {$userStart}"));
        $userEndFmt = date('h:i A', strtotime("2000-01-01 {$userEnd}"));
        $storeCutoffFmt = date('h:i A', strtotime("2000-01-01 {$storeCutoff}"));

        return [
            'server_time_ist'      => $now->format('Y-m-d H:i:s'),
            'current_date'         => $todayStr,
            'target_date'          => $targetDate,
            'user_window' => [
                'start_time' => $userStart,
                'end_time'   => $userEnd,
                'is_open'    => $userWindowOpen,
                'display'    => "{$userStartFmt} - {$userEndFmt} IST"
            ],
            'store_window' => [
                'start_time'      => $storeStart,
                'standard_cutoff' => $storeCutoff,
                'is_open'         => $storeEditAllowed,
                'is_allowed'      => $storeEditAllowed,
                'override_active' => ($activeOverride !== null),
                'override_info'   => $activeOverride,
                'display'         => ($activeOverride !== null)
                    ? "Admin Override Active (Expires at " . date('h:i A', strtotime($activeOverride['expires_at'])) . ")"
                    : "Standard Window (Until {$storeCutoffFmt} IST)"
            ]
        ];
    }
}
