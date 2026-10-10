<?php

require_once __DIR__ . '/../core/Http.php';

class AuthMiddleware
{
    private PDO $pdo;

    public function __construct(PDO $pdo)
    {
        $this->pdo = $pdo;
    }

    /** Returns the logged-in user (id, name, email, role) or sends 401. */
    public function authenticate(): array
    {
        $token = Http::bearerToken();

        if ($token === null || $token === '') {
            Http::fail(401, 'Authorization token is required');
        }

        $stmt = $this->pdo->prepare(
            "SELECT id, name, email, role FROM users
             WHERE auth_token = :token LIMIT 1"
        );
        $stmt->execute([':token' => $token]);
        $user = $stmt->fetch();

        if (!$user) {
            Http::fail(401, 'Invalid or expired token');
        }

        $user['id'] = (int) $user['id'];
        return $user;
    }

    /** Authenticate and make sure the user has one of the given roles. */
    public function requireRole(string ...$roles): array
    {
        $user = $this->authenticate();
        if (!in_array($user['role'], $roles, true)) {
            Http::fail(403, 'You do not have permission to do this');
        }
        return $user;
    }
}
