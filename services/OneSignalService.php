<?php
/**
 * OneSignal Push Notification Service
 * Delivers targeted 1-to-1 push notifications to user mobile devices
 */

require_once __DIR__ . '/../config/config.php';
require_once __DIR__ . '/../core/Database.php';

class OneSignalService {
    private const API_URL = 'https://onesignal.com/api/v1/notifications';

    /**
     * Send targeted push notification directly to a single specific User ID
     * (Strict 1-to-1 User Targeting!)
     */
    public static function sendToUser(int $userId, string $title, string $message, array $data = [], string $accentColor = 'FF1E3A8A'): bool {
        $appId = Config::get('ONESIGNAL_APP_ID');
        $apiKey = Config::get('ONESIGNAL_REST_API_KEY');

        // If keys are placeholder or empty, skip sending gracefully
        if (empty($appId) || empty($apiKey) || $appId === 'YOUR_ONESIGNAL_APP_ID') {
            error_log("[OneSignal] Skipping notification: OneSignal App ID / REST API Key not yet configured.");
            return false;
        }

        $payload = [
            'app_id'               => $appId,
            'include_aliases'      => [
                'external_id' => [(string) $userId]
            ],
            'target_channel'       => 'push',
            'priority'             => 10, // Max priority: heads-up banner on Android
            'android_accent_color' => $accentColor,
            'android_sound'        => 'notification',
            'ios_sound'            => 'notification.wav',
            'android_group'        => 'store_requisitions',
            'headings'             => ['en' => $title],
            'contents'             => ['en' => $message],
            'data'                 => $data,
            'buttons'              => [
                ['id' => 'view_slip', 'text' => '📄 Slip Dekhein']
            ]
        ];

        return self::executeRequest($apiKey, $payload);
    }

    /**
     * Send push notification to all users with a specific role (e.g. STORE_USER)
     */
    public static function sendToRole(string $role, string $title, string $message, array $data = [], string $accentColor = 'FF1E3A8A'): bool {
        // If role is store keeper or admin, use Store Terminal App credentials
        if (in_array($role, ['STORE_USER', 'ADMIN', 'SUPER_ADMIN'])) {
            $appId = Config::get('ONESIGNAL_STORE_APP_ID') ?? Config::get('ONESIGNAL_APP_ID');
            $apiKey = Config::get('ONESIGNAL_STORE_REST_API_KEY') ?? Config::get('ONESIGNAL_REST_API_KEY');
        } else {
            $appId = Config::get('ONESIGNAL_APP_ID');
            $apiKey = Config::get('ONESIGNAL_REST_API_KEY');
        }

        if (empty($appId) || empty($apiKey) || $appId === 'YOUR_ONESIGNAL_APP_ID') {
            return false;
        }

        // Get user IDs with this role
        $users = Database::query("SELECT id FROM users WHERE role = :role AND status = 'ACTIVE'", [':role' => $role]);
        if (empty($users)) {
            return false;
        }

        $userIds = array_map(fn($u) => (string) $u['id'], $users);

        // Attach default voice announcement text for store keepers
        if (empty($data['voice_text'])) {
            $data['voice_text'] = 'Material request received hua hai';
        }

        $payload = [
            'app_id'               => $appId,
            'included_segments'    => ['Total Subscriptions'],
            'target_channel'       => 'push',
            'priority'             => 10,
            'android_accent_color' => $accentColor,
            'android_sound'        => 'notification',
            'ios_sound'            => 'notification.wav',
            'android_group'        => 'store_requisitions',
            'headings'             => ['en' => $title],
            'contents'             => ['en' => $message],
            'data'                 => $data
        ];

        return self::executeRequest($apiKey, $payload);
    }

    /**
     * Execute cURL POST to OneSignal API
     */
    private static function executeRequest(string $apiKey, array $payload): bool {
        try {
            $ch = curl_init();
            curl_setopt($ch, CURLOPT_URL, self::API_URL);
            curl_setopt($ch, CURLOPT_POST, true);
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
            curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, 0);
            curl_setopt($ch, CURLOPT_TIMEOUT, 8);
            curl_setopt($ch, CURLOPT_HTTPHEADER, [
                'Content-Type: application/json; charset=utf-8',
                'Authorization: Key ' . $apiKey
            ]);

            $response = curl_exec($ch);
            $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            $err = curl_error($ch);
            curl_close($ch);

            if ($err) {
                error_log("[OneSignal] cURL Error: " . $err);
                return false;
            }

            if ($httpCode >= 200 && $httpCode < 300) {
                return true;
            } else {
                error_log("[OneSignal] API Response ($httpCode): " . $response);
                return false;
            }
        } catch (Throwable $e) {
            error_log("[OneSignal] Exception: " . $e->getMessage());
            return false;
        }
    }
}
