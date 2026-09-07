<?php
/**
 * Database Core Wrapper
 * PDO Singleton with Transaction management & Query helpers
 */

require_once __DIR__ . '/../config/config.php';

class Database {
    private static ?PDO $instance = null;

    public static function getConnection(): PDO {
        if (self::$instance === null) {
            $config = require __DIR__ . '/../config/database.php';
            $dsn = "mysql:host={$config['host']};port={$config['port']};dbname={$config['database']};charset={$config['charset']}";
            
            try {
                self::$instance = new PDO($dsn, $config['username'], $config['password'], $config['options']);
            } catch (PDOException $e) {
                // In production, log internal error and throw user-friendly exception
                error_log("Database Connection Failed: " . $e->getMessage());
                throw new Exception("Database connection could not be established. Please check server configuration.");
            }
        }
        return self::$instance;
    }

    /**
     * Execute a callback inside a database transaction
     */
    public static function transaction(callable $callback): mixed {
        $db = self::getConnection();
        $db->beginTransaction();
        try {
            $result = $callback($db);
            if ($db->inTransaction()) {
                $db->commit();
            }
            return $result;
        } catch (Throwable $e) {
            if ($db->inTransaction()) {
                $db->rollBack();
            }
            throw $e;
        }
    }

    /**
     * Helper for prepared statement execution returning fetched rows
     */
    public static function query(string $sql, array $params = []): array {
        $stmt = self::getConnection()->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetchAll();
    }

    /**
     * Helper for prepared statement returning a single row
     */
    public static function queryOne(string $sql, array $params = []): ?array {
        $stmt = self::getConnection()->prepare($sql);
        $stmt->execute($params);
        $row = $stmt->fetch();
        return $row ?: null;
    }

    /**
     * Helper for write operations (INSERT, UPDATE, DELETE)
     */
    public static function execute(string $sql, array $params = []): int {
        $stmt = self::getConnection()->prepare($sql);
        $stmt->execute($params);
        return $stmt->rowCount();
    }

    /**
     * Get last insert ID
     */
    public static function lastInsertId(): int {
        return (int) self::getConnection()->lastInsertId();
    }
}
