<?php

class AuthController
{
    private PDO $pdo;

    public function __construct(PDO $pdo)
    {
        $this->pdo = $pdo;
    }

    /*
    |--------------------------------------------------------------------------
    | REGISTER
    |--------------------------------------------------------------------------
    */
    public function register(): void
    {
        $data = json_decode(file_get_contents("php://input"), true);

        if (!is_array($data)) {
            $this->sendResponse(400, [
                'success' => false,
                'message' => 'Invalid JSON data'
            ]);
        }

        $name = trim($data['name'] ?? '');
        $email = trim($data['email'] ?? '');
        $password = $data['password'] ?? '';

        // Validate name
        if ($name === '') {
            $this->sendResponse(400, [
                'success' => false,
                'message' => 'Name is required'
            ]);
        }

        // Validate email
        if ($email === '' || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
            $this->sendResponse(400, [
                'success' => false,
                'message' => 'Valid email is required'
            ]);
        }

        // Validate password
        if ($password === '' || strlen($password) < 6) {
            $this->sendResponse(400, [
                'success' => false,
                'message' => 'Password must be at least 6 characters'
            ]);
        }

        // Check existing email
        $stmt = $this->pdo->prepare(
            "SELECT id FROM users
             WHERE email = :email
             LIMIT 1"
        );

        $stmt->execute([
            ':email' => $email
        ]);

        if ($stmt->fetch()) {
            $this->sendResponse(409, [
                'success' => false,
                'message' => 'Email already registered'
            ]);
        }

        // Hash password
        $hashedPassword = password_hash(
            $password,
            PASSWORD_DEFAULT
        );

        // Insert user
        $stmt = $this->pdo->prepare(
            "INSERT INTO users
                (name, email, password, role)
             VALUES
                (:name, :email, :password, 'student')"
        );

        $stmt->execute([
            ':name' => $name,
            ':email' => $email,
            ':password' => $hashedPassword
        ]);

        $userId = (int) $this->pdo->lastInsertId();

        $this->sendResponse(201, [
            'success' => true,
            'message' => 'Registration successful',
            'user' => [
                'id' => $userId,
                'name' => $name,
                'email' => $email,
                'role' => 'student'
            ]
        ]);
    }


    /*
    |--------------------------------------------------------------------------
    | LOGIN
    |--------------------------------------------------------------------------
    */
    public function login(): void
    {
        $data = json_decode(file_get_contents("php://input"), true);

        if (!is_array($data)) {
            $this->sendResponse(400, [
                'success' => false,
                'message' => 'Invalid JSON data'
            ]);
        }

        $email = trim($data['email'] ?? '');
        $password = $data['password'] ?? '';

        // Validate email
        if ($email === '' || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
            $this->sendResponse(400, [
                'success' => false,
                'message' => 'Valid email is required'
            ]);
        }

        // Validate password
        if ($password === '') {
            $this->sendResponse(400, [
                'success' => false,
                'message' => 'Password is required'
            ]);
        }

        // Find user
        $stmt = $this->pdo->prepare(
            "SELECT id, name, email, password, role
             FROM users
             WHERE email = :email
             LIMIT 1"
        );

        $stmt->execute([
            ':email' => $email
        ]);

        $user = $stmt->fetch();

        // User not found
        if (!$user) {
            $this->sendResponse(401, [
                'success' => false,
                'message' => 'Invalid email or password'
            ]);
        }

        // Verify password
        if (!password_verify($password, $user['password'])) {
            $this->sendResponse(401, [
                'success' => false,
                'message' => 'Invalid email or password'
            ]);
        }

        // Generate authentication token
        $token = bin2hex(random_bytes(32));

        // Save token
        $stmt = $this->pdo->prepare(
            "UPDATE users
             SET auth_token = :token
             WHERE id = :id"
        );

        $stmt->execute([
            ':token' => $token,
            ':id' => $user['id']
        ]);

        // Return login response
        $this->sendResponse(200, [
            'success' => true,
            'message' => 'Login successful',

            'token' => $token,

            'user' => [
                'id' => (int) $user['id'],
                'name' => $user['name'],
                'email' => $user['email'],
                'role' => $user['role']
            ]
        ]);
    }


    /*
    |--------------------------------------------------------------------------
    | LOGOUT
    |--------------------------------------------------------------------------
    */
    public function logout(): void
    {
        $token = $this->getBearerToken();

        if ($token === null) {
            $this->sendResponse(401, [
                'success' => false,
                'message' => 'Authorization token is required'
            ]);
        }

        // Remove token
        $stmt = $this->pdo->prepare(
            "UPDATE users
             SET auth_token = NULL
             WHERE auth_token = :token"
        );

        $stmt->execute([
            ':token' => $token
        ]);

        if ($stmt->rowCount() === 0) {
            $this->sendResponse(401, [
                'success' => false,
                'message' => 'Invalid token'
            ]);
        }

        $this->sendResponse(200, [
            'success' => true,
            'message' => 'Logout successful'
        ]);
    }


    /*
    |--------------------------------------------------------------------------
    | GET USER
    |--------------------------------------------------------------------------
    */
    public function user(): void
    {
        $token = $this->getBearerToken();

        if ($token === null) {
            $this->sendResponse(401, [
                'success' => false,
                'message' => 'Authorization token is required'
            ]);
        }

        $stmt = $this->pdo->prepare(
            "SELECT id, name, email, role
             FROM users
             WHERE auth_token = :token
             LIMIT 1"
        );

        $stmt->execute([
            ':token' => $token
        ]);

        $user = $stmt->fetch();

        if (!$user) {
            $this->sendResponse(401, [
                'success' => false,
                'message' => 'Invalid or expired token'
            ]);
        }

        $this->sendResponse(200, [
            'success' => true,
            'message' => 'User retrieved successfully',
            'user' => [
                'id' => (int) $user['id'],
                'name' => $user['name'],
                'email' => $user['email'],
                'role' => $user['role']
            ]
        ]);
    }


    /*
    |--------------------------------------------------------------------------
    | GET BEARER TOKEN
    |--------------------------------------------------------------------------
    */
    private function getBearerToken(): ?string
    {
        $headers = getallheaders();

        $authorization = $headers['Authorization']
            ?? $headers['authorization']
            ?? '';

        if (empty($authorization)) {
            return null;
        }

        if (!preg_match(
            '/Bearer\s+(.+)/i',
            $authorization,
            $matches
        )) {
            return null;
        }

        return trim($matches[1]);
    }


    /*
    |--------------------------------------------------------------------------
    | JSON RESPONSE
    |--------------------------------------------------------------------------
    */
    private function sendResponse(
        int $statusCode,
        array $data
    ): void {

        http_response_code($statusCode);

        header('Content-Type: application/json');

        echo json_encode($data);

        exit;
    }
}