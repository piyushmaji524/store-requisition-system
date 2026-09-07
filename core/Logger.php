<?php
/**
 * Activity Audit & System Logger
 */

require_once __DIR__ . '/Database.php';
require_once __DIR__ . '/Request.php';

class Logger {
    /**
     * Record an audit activity into activity_logs
     */
    public static function logActivity(
        ?int $userId,
        string $action,
        string $entityType,
        ?string $entityId = null,
        ?array $oldData = null,
        ?array $newData = null
    ): void {
        try {
            $sql = "INSERT INTO activity_logs (
                        user_id, action, entity_type, entity_id, 
                        old_data, new_data, ip_address, user_agent, created_at
                    ) VALUES (
                        :user_id, :action, :entity_type, :entity_id, 
                        :old_data, :new_data, :ip_address, :user_agent, NOW()
                    )";
            
            Database::execute($sql, [
                ':user_id'     => $userId,
                ':action'      => $action,
                ':entity_type' => $entityType,
                ':entity_id'   => $entityId ? (string) $entityId : null,
                ':old_data'    => $oldData ? json_encode($oldData) : null,
                ':new_data'    => $newData ? json_encode($newData) : null,
                ':ip_address'  => Request::ip(),
                ':user_agent'  => substr(Request::userAgent(), 0, 255)
            ]);
        } catch (Throwable $e) {
            // Fallback to error log so auditing never crashes the main flow
            error_log("Failed to write activity log: " . $e->getMessage());
        }
    }

    /**
     * File based error logging
     */
    public static function logError(string $message, ?Throwable $exception = null): void {
        $logDir = __DIR__ . '/../logs';
        if (!is_dir($logDir)) {
            @mkdir($logDir, 0755, true);
        }
        
        $date = date('Y-m-d');
        $logFile = "{$logDir}/error_{$date}.log";
        $timestamp = date('Y-m-d H:i:s');
        
        $entry = "[{$timestamp} IST] {$message}";
        if ($exception) {
            $entry .= "\nException: " . $exception->getMessage() . "\nTrace:\n" . $exception->getTraceAsString();
        }
        $entry .= "\n" . str_repeat('-', 80) . "\n";
        
        @file_put_contents($logFile, $entry, FILE_APPEND);
    }
}
