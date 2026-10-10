<?php

require_once __DIR__ . '/../core/Http.php';

class CourseController
{
    private const STATUSES = ['draft', 'published', 'inactive'];

    public function __construct(private PDO $pdo, private array $me) {}

    private function isAdmin(): bool
    {
        return $this->me['role'] === 'admin';
    }

    /** Admin sees everything; everyone else only published courses. */
    public function index(): void
    {
        $sql = "SELECT c.id, c.course_name, c.description, c.price, c.duration, c.image_url, c.status,
                       (SELECT COUNT(*) FROM batches b WHERE b.course_id = c.id AND b.is_deleted = 0 AND b.status = 'Active') AS active_batches,
                       (SELECT COUNT(*) FROM purchases p WHERE p.course_id = c.id AND p.user_id = :uid AND p.status = 'paid') AS purchased
                FROM courses c WHERE c.is_deleted = 0";
        if (!$this->isAdmin()) $sql .= " AND c.status = 'published'";
        $sql .= " ORDER BY c.id DESC";

        $stmt = $this->pdo->prepare($sql);
        $stmt->execute([':uid' => $this->me['id']]);
        $rows = $stmt->fetchAll();
        foreach ($rows as &$r) {
            $r['purchased'] = (int) $r['purchased'] > 0;
            $r['active_batches'] = (int) $r['active_batches'];
        }

        Http::json(200, ['success' => true, 'courses' => $rows]);
    }

    public function show(int $id): void
    {
        $stmt = $this->pdo->prepare("SELECT * FROM courses WHERE id = :id AND is_deleted = 0");
        $stmt->execute([':id' => $id]);
        $course = $stmt->fetch();

        if (!$course || (!$this->isAdmin() && $course['status'] !== 'published')) {
            Http::fail(404, 'Course not found');
        }

        // Active batches with seats left
        $stmt = $this->pdo->prepare(
            "SELECT b.id, b.batch_name, b.start_date, b.end_date, b.capacity,
                    (SELECT COUNT(*) FROM purchases p WHERE p.batch_id = b.id AND p.status = 'paid') AS enrolled
             FROM batches b
             WHERE b.course_id = :id AND b.is_deleted = 0 AND b.status = 'Active'
             ORDER BY b.start_date"
        );
        $stmt->execute([':id' => $id]);
        $batches = $stmt->fetchAll();
        foreach ($batches as &$b) {
            $b['capacity'] = (int) $b['capacity'];
            $b['enrolled'] = (int) $b['enrolled'];
            $b['seats_left'] = max(0, $b['capacity'] - $b['enrolled']);
        }

        $stmt = $this->pdo->prepare(
            "SELECT COUNT(*) FROM purchases WHERE user_id = :u AND course_id = :c AND status = 'paid'"
        );
        $stmt->execute([':u' => $this->me['id'], ':c' => $id]);

        Http::json(200, [
            'success' => true,
            'course' => $course,
            'batches' => $batches,
            'purchased' => (int) $stmt->fetchColumn() > 0,
        ]);
    }

    public function store(): void
    {
        [$name, $desc, $price, $duration, $image, $status] = $this->validate(Http::body());

        $this->pdo->prepare(
            "INSERT INTO courses (course_name, description, price, duration, image_url, status, created_by)
             VALUES (:n, :d, :p, :du, :i, :s, :u)"
        )->execute([':n' => $name, ':d' => $desc, ':p' => $price, ':du' => $duration,
                    ':i' => $image, ':s' => $status, ':u' => $this->me['id']]);

        Http::json(201, ['success' => true, 'message' => 'Course created', 'id' => (int) $this->pdo->lastInsertId()]);
    }

    public function update(int $id): void
    {
        $this->exists($id);
        [$name, $desc, $price, $duration, $image, $status] = $this->validate(Http::body());

        $this->pdo->prepare(
            "UPDATE courses SET course_name=:n, description=:d, price=:p, duration=:du, image_url=:i, status=:s
             WHERE id=:id"
        )->execute([':n' => $name, ':d' => $desc, ':p' => $price, ':du' => $duration,
                    ':i' => $image, ':s' => $status, ':id' => $id]);

        Http::json(200, ['success' => true, 'message' => 'Course updated']);
    }

    public function destroy(int $id): void
    {
        $this->exists($id);
        // soft delete keeps purchase history intact
        $this->pdo->prepare("UPDATE courses SET is_deleted = 1 WHERE id = :id")->execute([':id' => $id]);
        $this->pdo->prepare("UPDATE batches SET is_deleted = 1 WHERE course_id = :id")->execute([':id' => $id]);
        Http::json(200, ['success' => true, 'message' => 'Course deleted']);
    }

    private function validate(array $d): array
    {
        $name = trim($d['course_name'] ?? '');
        if ($name === '') Http::fail(400, 'Course name is required');

        $price = $d['price'] ?? 0;
        if (!is_numeric($price) || $price < 0) Http::fail(400, 'Price must be a number, 0 or more');

        $status = $d['status'] ?? 'draft';
        if (!in_array($status, self::STATUSES, true)) Http::fail(400, 'Invalid status');

        return [
            $name,
            trim($d['description'] ?? '') ?: null,
            round((float) $price, 2),
            trim($d['duration'] ?? '') ?: null,
            trim($d['image_url'] ?? '') ?: null,
            $status,
        ];
    }

    private function exists(int $id): void
    {
        $stmt = $this->pdo->prepare("SELECT id FROM courses WHERE id = :id AND is_deleted = 0");
        $stmt->execute([':id' => $id]);
        if (!$stmt->fetch()) Http::fail(404, 'Course not found');
    }
}
