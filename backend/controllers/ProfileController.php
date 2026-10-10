<?php

require_once __DIR__ . '/../core/Http.php';

class ProfileController
{
    public function __construct(private PDO $pdo, private array $me) {}

    public function show(): void
    {
        $stmt = $this->pdo->prepare(
            "SELECT id, name, email, role, created_at FROM users WHERE id = :id"
        );
        $stmt->execute([':id' => $this->me['id']]);
        $user = $stmt->fetch();
        $user['id'] = (int) $user['id'];

        Http::json(200, ['success' => true, 'user' => $user]);
    }

    public function update(): void
    {
        $d = Http::body();
        $name  = trim($d['name'] ?? '');
        $email = trim($d['email'] ?? '');

        if ($name === '') Http::fail(400, 'Name is required');
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) Http::fail(400, 'Valid email is required');

        $stmt = $this->pdo->prepare("SELECT id FROM users WHERE email = :e AND id <> :id LIMIT 1");
        $stmt->execute([':e' => $email, ':id' => $this->me['id']]);
        if ($stmt->fetch()) Http::fail(409, 'Email already in use');

        $this->pdo->prepare("UPDATE users SET name = :n, email = :e WHERE id = :id")
            ->execute([':n' => $name, ':e' => $email, ':id' => $this->me['id']]);

        $this->show();
    }

    public function changePassword(): void
    {
        $d = Http::body();
        $current = $d['current_password'] ?? '';
        $new     = $d['new_password'] ?? '';

        if (strlen($new) < 6) Http::fail(400, 'New password must be at least 6 characters');

        $stmt = $this->pdo->prepare("SELECT password FROM users WHERE id = :id");
        $stmt->execute([':id' => $this->me['id']]);
        $hash = $stmt->fetchColumn();

        if (!password_verify($current, $hash)) {
            Http::fail(400, 'Current password is incorrect');
        }

        $this->pdo->prepare("UPDATE users SET password = :p WHERE id = :id")
            ->execute([':p' => password_hash($new, PASSWORD_DEFAULT), ':id' => $this->me['id']]);

        Http::json(200, ['success' => true, 'message' => 'Password updated']);
    }
}
