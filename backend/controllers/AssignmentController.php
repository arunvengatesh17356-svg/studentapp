<?php

require_once __DIR__ . '/../core/Http.php';

/** Admin-only: assign a subject of a batch to a staff member. */
class AssignmentController
{
    public function __construct(private PDO $pdo, private array $me) {}

    /* GET /assignments?batch_id=&staff_id=&search= */
    public function index(): void
    {
        $where = ['b.is_deleted = 0'];
        $params = [];

        if (!empty($_GET['batch_id'])) { $where[] = 'bs.batch_id = :b'; $params[':b'] = (int) $_GET['batch_id']; }
        if (!empty($_GET['staff_id'])) { $where[] = 'bs.staff_id = :s'; $params[':s'] = (int) $_GET['staff_id']; }
        $search = trim($_GET['search'] ?? '');
        if ($search !== '') {
            $where[] = '(bs.subject_name LIKE :q1 OR u.name LIKE :q2 OR b.batch_name LIKE :q3)';
            $params[':q1'] = $params[':q2'] = $params[':q3'] = "%$search%";
        }

        $sql = "SELECT bs.id, bs.subject_name, bs.batch_id, b.batch_name, b.status AS batch_status,
                       c.course_name, bs.staff_id, u.name AS staff_name, u.email AS staff_email,
                       (SELECT COUNT(*) FROM purchases p WHERE p.batch_id = b.id AND p.status = 'paid') AS students
                FROM batch_subjects bs
                JOIN batches b ON b.id = bs.batch_id
                JOIN courses c ON c.id = b.course_id
                JOIN users u ON u.id = bs.staff_id
                WHERE " . implode(' AND ', $where) . "
                ORDER BY u.name, b.batch_name, bs.subject_name";
        $stmt = $this->pdo->prepare($sql);
        $stmt->execute($params);
        $rows = $stmt->fetchAll();
        foreach ($rows as &$r) $r['students'] = (int) $r['students'];

        Http::json(200, ['success' => true, 'assignments' => $rows]);
    }

    public function store(): void
    {
        [$batch, $subject, $staff] = $this->validate(Http::body(), null);

        $this->pdo->prepare(
            "INSERT INTO batch_subjects (batch_id, subject_name, staff_id) VALUES (:b, :s, :u)"
        )->execute([':b' => $batch, ':s' => $subject, ':u' => $staff]);

        Http::json(201, ['success' => true, 'message' => 'Subject assigned', 'id' => (int) $this->pdo->lastInsertId()]);
    }

    public function update(int $id): void
    {
        $this->findOrFail($id);
        [$batch, $subject, $staff] = $this->validate(Http::body(), $id);

        $this->pdo->prepare(
            "UPDATE batch_subjects SET batch_id = :b, subject_name = :s, staff_id = :u WHERE id = :id"
        )->execute([':b' => $batch, ':s' => $subject, ':u' => $staff, ':id' => $id]);

        Http::json(200, ['success' => true, 'message' => 'Assignment updated']);
    }

    public function destroy(int $id): void
    {
        $this->findOrFail($id);
        // attendance rows of this subject are removed automatically (ON DELETE CASCADE)
        $this->pdo->prepare("DELETE FROM batch_subjects WHERE id = :id")->execute([':id' => $id]);
        Http::json(200, ['success' => true, 'message' => 'Assignment removed']);
    }

    /** GET /staff-list : users with role staff, for the dropdown */
    public function staffList(): void
    {
        $stmt = $this->pdo->query("SELECT id, name, email FROM users WHERE role = 'staff' ORDER BY name");
        Http::json(200, ['success' => true, 'staff' => $stmt->fetchAll()]);
    }

    private function validate(array $d, ?int $ignoreId): array
    {
        $batch = (int) ($d['batch_id'] ?? 0);
        $staff = (int) ($d['staff_id'] ?? 0);
        $subject = trim($d['subject_name'] ?? '');

        if ($subject === '') Http::fail(400, 'Subject name is required');
        if (Http::len($subject) > 150) Http::fail(400, 'Subject name is too long');

        $stmt = $this->pdo->prepare("SELECT id FROM batches WHERE id = :id AND is_deleted = 0");
        $stmt->execute([':id' => $batch]);
        if (!$stmt->fetch()) Http::fail(400, 'Please choose a valid batch');

        $stmt = $this->pdo->prepare("SELECT id FROM users WHERE id = :id AND role = 'staff'");
        $stmt->execute([':id' => $staff]);
        if (!$stmt->fetch()) Http::fail(400, 'Please choose a valid staff member');

        $stmt = $this->pdo->prepare(
            "SELECT id FROM batch_subjects WHERE batch_id = :b AND subject_name = :s AND id <> :id"
        );
        $stmt->execute([':b' => $batch, ':s' => $subject, ':id' => $ignoreId ?? 0]);
        if ($stmt->fetch()) Http::fail(409, 'This subject is already assigned in this batch');

        return [$batch, $subject, $staff];
    }

    private function findOrFail(int $id): void
    {
        $stmt = $this->pdo->prepare("SELECT id FROM batch_subjects WHERE id = :id");
        $stmt->execute([':id' => $id]);
        if (!$stmt->fetch()) Http::fail(404, 'Assignment not found');
    }
}
