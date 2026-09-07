<?php
/**
 * Standardized API & HTTP Response Helper
 */

class Response {
    public static function json(array $data, int $statusCode = 200): void {
        if (!headers_sent()) {
            http_response_code($statusCode);
            header('Content-Type: application/json; charset=utf-8');
            header('X-Content-Type-Options: nosniff');
            header('X-Frame-Options: DENY');
            header('X-XSS-Protection: 1; mode=block');
        }
        echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        exit;
    }

    public static function success(mixed $data = null, string $message = 'Success', int $statusCode = 200): void {
        self::json([
            'success'    => true,
            'status'     => 'success',
            'message'    => $message,
            'data'       => $data,
            'error_code' => null
        ], $statusCode);
    }

    public static function error(string $message = 'An error occurred', string $errorCode = 'SERVER_ERROR', int $statusCode = 400, mixed $data = null): void {
        self::json([
            'success'    => false,
            'status'     => 'error',
            'message'    => $message,
            'error_code' => $errorCode,
            'data'       => $data
        ], $statusCode);
    }

    public static function unauthorized(string $message = 'Unauthorized access'): void {
        self::error($message, 'UNAUTHORIZED', 401);
    }

    public static function forbidden(string $message = 'Forbidden access'): void {
        self::error($message, 'FORBIDDEN', 403);
    }

    public static function notFound(string $message = 'Resource not found'): void {
        self::error($message, 'NOT_FOUND', 404);
    }
}
