<?php

class Http
{
    public static function json(int $code, array $data): void
    {
        http_response_code($code);
        header('Content-Type: application/json');
        echo json_encode($data);
        exit;
    }

    public static function fail(int $code, string $message): void
    {
        self::json($code, ['success' => false, 'message' => $message]);
    }

    public static function body(): array
    {
        $data = json_decode(file_get_contents('php://input'), true);
        if (!is_array($data)) {
            self::fail(400, 'Invalid JSON data');
        }
        return $data;
    }

    /** Character count that works with or without the mbstring extension. */
    public static function len(string $s): int
    {
        return function_exists('mb_strlen') ? mb_strlen($s) : (int) preg_match_all('/./us', $s);
    }

    public static function bearerToken(): ?string
    {
        $auth = $_SERVER['HTTP_AUTHORIZATION']
            ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION']
            ?? '';

        if ($auth === '' && function_exists('getallheaders')) {
            $h = getallheaders();
            $auth = $h['Authorization'] ?? $h['authorization'] ?? '';
        }

        if ($auth !== '' && preg_match('/Bearer\s+(.+)/i', $auth, $m)) {
            return trim($m[1]);
        }
        return null;
    }
}
