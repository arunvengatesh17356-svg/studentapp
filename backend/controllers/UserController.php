<?php

require_once __DIR__ . '/../core/Http.php';

/** Admin-only user management. */
class UserController
{
    private const ROLES = ['admin', 'staff', 'student'];

    public function __construct(private PDO $pdo, private array $me) {}

    public function index(): void
    {
        $where = [];
        $params = [];

        $search = trim($_GET['search'] ?? '');
        if ($search !== '') {
            $where[] = '(name LIKE :s OR email LIKE :s)';
            $params[':s'] = "%$search%";
        }
        $role = $_GET['role'] ?? '';
        if (in_array($role, self::ROLES, true)) {
            $where[] = 'role = :role';
            $params[':role'] = $role;
        }

        $sql = "SELECT id, name, email, role, created_at FROM users"
            . ($where ? ' WHERE ' . implode(' AND ', $where) : '')
            . " ORDER BY id DESC LIMIT 500";

        $stmt = $this->pdo->prepare($sql);
        $stmt->execute($params);

        Http::json(200, ['success' => true, 'users' => $stmt->fetchAll()]);
    }

    public function store(): void
    {
        $d = Http::body();
        [$name, $email, $role] = $this->validate($d, null);

        $password = $d['password'] ?? '';
        if (strlen($password) < 6) Http::fail(400, 'Password must be at least 6 characters');

        $this->pdo->prepare(
            "INSERT INTO users (name, email, password, role) VALUES (:n, :e, :p, :r)"
        )->execute([
            ':n' => $name,
            ':e' => $email,
            ':p' => password_hash($password, PASSWORD_DEFAULT),
            ':r' => $role,
        ]);

        Http::json(201, [
            'success' => true,
            'message' => 'User created',
            'user' => ['id' => (int) $this->pdo->lastInsertId(), 'name' => $name, 'email' => $email, 'role' => $role],
        ]);
    }

    public function update(int $id): void
    {
        $this->findOrFail($id);
        $d = Http::body();
        [$name, $email, $role] = $this->validate($d, $id);

        if ($id === $this->me['id'] && $role !== 'admin') {
            Http::fail(400, 'You cannot remove your own admin role');
        }

        $sql = "UPDATE users SET name = :n, email = :e, role = :r";
        $params = [':n' => $name, ':e' => $email, ':r' => $role, ':id' => $id];

        // password is optional on edit (admin reset)
        if (!empty($d['password'])) {
            if (strlen($d['password']) < 6) Http::fail(400, 'Password must be at least 6 characters');
            $sql .= ", password = :p, auth_token = NULL"; // force re-login
            $params[':p'] = password_hash($d['password'], PASSWORD_DEFAULT);
        }

        $this->pdo->prepare($sql . " WHERE id = :id")->execute($params);

        Http::json(200, ['success' => true, 'message' => 'User updated']);
    }

    public function destroy(int $id): void
    {
        if ($id === $this->me['id']) Http::fail(400, 'You cannot delete your own account');
        $this->findOrFail($id);

        try {
            $this->pdo->prepare("DELETE FROM users WHERE id = :id")->execute([':id' => $id]);
        } catch (PDOException $e) {
            if ($e->getCode() === '23000') {
                Http::fail(409, 'This user has courses, batches, purchases or subject assignments linked to them and cannot be deleted');
            }
            throw $e;
        }

        Http::json(200, ['success' => true, 'message' => 'User deleted']);
    }

    private function validate(array $d, ?int $ignoreId): array
    {
        $name  = trim($d['name'] ?? '');
        $email = trim($d['email'] ?? '');
        $role  = $d['role'] ?? 'student';

        if ($name === '') Http::fail(400, 'Name is required');
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) Http::fail(400, 'Valid email is required');
        if (!in_array($role, self::ROLES, true)) Http::fail(400, 'Invalid role');

        $stmt = $this->pdo->prepare("SELECT id FROM users WHERE email = :e AND id <> :id LIMIT 1");
        $stmt->execute([':e' => $email, ':id' => $ignoreId ?? 0]);
        if ($stmt->fetch()) Http::fail(409, 'Email already registered');

        return [$name, $email, $role];
    }

    private function findOrFail(int $id): void
    {
        $stmt = $this->pdo->prepare("SELECT id FROM users WHERE id = :id");
        $stmt->execute([':id' => $id]);
        if (!$stmt->fetch()) Http::fail(404, 'User not found');
    }
}
