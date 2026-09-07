<?php
/**
 * Lightweight REST Router for Core PHP API
 */

require_once __DIR__ . '/Request.php';
require_once __DIR__ . '/Response.php';

class Router {
    private static array $routes = [];

    public static function get(string $path, callable|array $handler, array $middlewares = []): void {
        self::addRoute('GET', $path, $handler, $middlewares);
    }

    public static function post(string $path, callable|array $handler, array $middlewares = []): void {
        self::addRoute('POST', $path, $handler, $middlewares);
    }

    public static function put(string $path, callable|array $handler, array $middlewares = []): void {
        self::addRoute('PUT', $path, $handler, $middlewares);
    }

    public static function delete(string $path, callable|array $handler, array $middlewares = []): void {
        self::addRoute('DELETE', $path, $handler, $middlewares);
    }

    private static function addRoute(string $method, string $path, callable|array $handler, array $middlewares = []): void {
        $cleanPath = '/' . trim($path, '/');
        self::$routes[] = [
            'method'      => $method,
            'path'        => $cleanPath,
            'handler'     => $handler,
            'middlewares' => $middlewares
        ];
    }

    public static function dispatch(?string $requestPath = null, ?string $requestMethod = null): void {
        $method = $requestMethod ?? Request::method();
        $path = $requestPath ?? Request::path();
        
        // Handle OPTIONS preflight requests for CORS
        if ($method === 'OPTIONS') {
            header('Access-Control-Allow-Origin: *');
            header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
            header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
            http_response_code(200);
            exit;
        }

        // Add standard CORS headers for API requests
        header('Access-Control-Allow-Origin: *');
        header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

        $cleanPath = '/' . trim($path, '/');

        foreach (self::$routes as $route) {
            if ($route['method'] !== $method) {
                continue;
            }

            // Convert route template (e.g., /api/items/{id} or /api/items/:id) to regex
            $pattern = preg_replace('/\{([a-zA-Z0-9_]+)\}/', '(?P<$1>[^/]+)', $route['path']);
            $pattern = preg_replace('/:([a-zA-Z0-9_]+)/', '(?P<$1>[^/]+)', $pattern);
            $pattern = '#^' . $pattern . '$#';

            if (preg_match($pattern, $cleanPath, $matches)) {
                $params = [];
                foreach ($matches as $key => $value) {
                    if (is_string($key)) {
                        $params[$key] = $value;
                    }
                }

                // Run middlewares
                foreach ($route['middlewares'] as $middleware) {
                    if (is_callable($middleware)) {
                        $middleware();
                    }
                }

                // Execute handler
                try {
                    if (is_callable($route['handler'])) {
                        call_user_func($route['handler'], $params);
                        return;
                    } elseif (is_array($route['handler']) && count($route['handler']) === 2) {
                        [$class, $action] = $route['handler'];
                        $instance = new $class();
                        $instance->$action($params);
                        return;
                    }
                } catch (Throwable $e) {
                    Logger::logError("Router Dispatch Exception on [{$method} {$path}]", $e);
                    Response::error($e->getMessage(), 'INTERNAL_SERVER_ERROR', 500);
                }
            }
        }

        Response::notFound("Endpoint [{$method} {$cleanPath}] not found.");
    }
}
