<?php
/**
 * HTTP Request Parser & Input Sanitizer
 */

class Request {
    private static ?array $jsonBody = null;

    /**
     * Get HTTP Request Method (GET, POST, PUT, DELETE, OPTIONS)
     */
    public static function method(): string {
        return strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');
    }

    /**
     * Get Request URI path without query strings
     */
    public static function path(): string {
        $uri = $_SERVER['REQUEST_URI'] ?? '/';
        $path = parse_url($uri, PHP_URL_PATH) ?? '/';
        
        // Remove index.php segment if present
        $path = preg_replace('#/index\.php#i', '', $path);
        
        // Ensure /api prefix if routed inside api directory
        $clean = '/' . trim($path, '/');
        if (!str_starts_with($clean, '/api') && (str_starts_with($_SERVER['SCRIPT_NAME'] ?? '', '/api') || str_starts_with($_SERVER['PHP_SELF'] ?? '', '/api'))) {
            $clean = '/api' . $clean;
        }

        return rtrim($clean, '/') ?: '/';
    }

    /**
     * Get all headers in a normalized array
     */
    public static function headers(): array {
        if (function_exists('getallheaders')) {
            return getallheaders() ?: [];
        }
        $headers = [];
        foreach ($_SERVER as $name => $value) {
            if (str_starts_with($name, 'HTTP_')) {
                $headerName = str_replace(' ', '-', ucwords(strtolower(str_replace('_', ' ', substr($name, 5)))));
                $headers[$headerName] = $value;
            }
        }
        return $headers;
    }

    /**
     * Get a specific header
     */
    public static function header(string $key, ?string $default = null): ?string {
        $headers = self::headers();
        foreach ($headers as $k => $v) {
            if (strcasecmp($k, $key) === 0) {
                return $v;
            }
        }
        return $default;
    }

    /**
     * Extract Bearer token from Authorization header
     */
    public static function bearerToken(): ?string {
        $authHeader = self::header('Authorization');
        if ($authHeader && preg_match('/Bearer\s+(\S+)/i', $authHeader, $matches)) {
            return $matches[1];
        }
        return null;
    }

    /**
     * Get JSON body as associative array
     */
    public static function json(): array {
        if (self::$jsonBody === null) {
            $input = file_get_contents('php://input');
            $data = json_decode($input, true);
            self::$jsonBody = is_array($data) ? $data : [];
        }
        return self::$jsonBody;
    }

    /**
     * Get request input value from JSON, POST, or GET
     */
    public static function input(string $key, mixed $default = null): mixed {
        $json = self::json();
        if (array_key_exists($key, $json)) {
            return self::sanitize($json[$key]);
        }
        if (array_key_exists($key, $_POST)) {
            return self::sanitize($_POST[$key]);
        }
        if (array_key_exists($key, $_GET)) {
            return self::sanitize($_GET[$key]);
        }
        return $default;
    }

    /**
     * Get all inputs merged (GET + POST + JSON)
     */
    public static function all(): array {
        $merged = array_merge($_GET, $_POST, self::json());
        return self::sanitize($merged);
    }

    /**
     * Get client IP address
     */
    public static function ip(): string {
        return $_SERVER['HTTP_X_FORWARDED_FOR'] ?? $_SERVER['REMOTE_ADDR'] ?? '127.0.0.1';
    }

    /**
     * Get User Agent
     */
    public static function userAgent(): string {
        return $_SERVER['HTTP_USER_AGENT'] ?? 'Unknown';
    }

    /**
     * Recursive input sanitization
     */
    private static function sanitize(mixed $data): mixed {
        if (is_array($data)) {
            foreach ($data as $k => $v) {
                $data[$k] = self::sanitize($v);
            }
            return $data;
        }
        if (is_string($data)) {
            return trim($data);
        }
        return $data;
    }
}
