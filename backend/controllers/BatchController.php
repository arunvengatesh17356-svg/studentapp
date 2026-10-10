<?php

require_once __DIR__ . '/../core/Http.php';

/** Admin-only batch management. */
class BatchController
{
    private const STATUSES = ['Active', 'Inactive', 'Completed'];

    public function __construct(private PDO $pdo, private array $me) {}

    public function index(): void
    {
        $where = ['b.is_deleted = 0'];
        $params = [];

        if (!empty($_GET['course_id'])) {
            $where[] = 'b.course_id = :c';
            $params[':c'] = (int) $_GET['course_id'];
        }
        if (in_array($_GET['status'] ?? '', self::STATUSES, true)) {
            $where[] = 'b.status = :s';
            $params[':s'] = $_GET['status'];
        }
        $search = trim($_GET['search'] ?? '');
        if ($search !== '') {
            $where[] = 'b.batch_name LIKE :q';
            $params[':q'] = "%$search%";
        }

        $sql = "SELECT b.id, b.batch_name, b.course_id, c.course_name, b.start_date, b.end_date,
                       b.capacity, b.status, b.created_at,
                       (SELECT COUNT(*) FROM purchases p WHERE p.batch_id = b.id AND p.status = 'paid') AS enrolled,
                       (SELECT GROUP_CONCAT(CONCAT(bs.subject_name, ' - ', u.name) ORDER BY bs.subject_name SEPARATOR '||')
                          FROM batch_subjects bs JOIN users u ON u.id = bs.staff_id WHERE bs.batch_id = b.id) AS subjects
                FROM batches b JOIN courses c ON c.id = b.course_id
                WHERE " . implode(' AND ', $where) . " ORDER BY b.id DESC";

        $stmt = $this->pdo->prepare($sql);
        $stmt->execute($params);
        $rows = $stmt->fetchAll();
        foreach ($rows as &$r) {
            $r['capacity'] = (int) $r['capacity'];
            $r['enrolled'] = (int) $r['enrolled'];
            $r['subjects'] = $r['subjects'] ? explode('||', $r['subjects']) : [];
        }

        Http::json(200, ['success' => true, 'batches' => $rows]);
    }

    public function store(): void
    {
        [$name, $course, $start, $end, $cap, $status] = $this->validate(Http::body());

        $this->pdo->prepare(
            "INSERT INTO batches (batch_name, course_id, start_date, end_date, capacity, status, created_by)
             VALUES (:n, :c, :s, :e, :cap, :st, :u)"
        )->execute([':n' => $name, ':c' => $course, ':s' => $start, ':e' => $end,
                    ':cap' => $cap, ':st' => $status, ':u' => $this->me['id']]);

        Http::json(201, ['success' => true, 'message' => 'Batch created', 'id' => (int) $this->pdo->lastInsertId()]);
    }

    public function update(int $id): void
    {
        $stmt = $this->pdo->prepare("SELECT id FROM batches WHERE id = :id AND is_deleted = 0");
        $stmt->execute([':id' => $id]);
        if (!$stmt->fetch()) Http::fail(404, 'Batch not found');

        [$name, $course, $start, $end, $cap, $status] = $this->validate(Http::body());

        $this->pdo->prepare(
            "UPDATE batches SET batch_name=:n, course_id=:c, start_date=:s, end_date=:e, capacity=:cap, status=:st
             WHERE id=:id"
        )->execute([':n' => $name, ':c' => $course, ':s' => $start, ':e' => $end,
                    ':cap' => $cap, ':st' => $status, ':id' => $id]);

        Http::json(200, ['success' => true, 'message' => 'Batch updated']);
    }

    public function destroy(int $id): void
    {
        $stmt = $this->pdo->prepare("UPDATE batches SET is_deleted = 1 WHERE id = :id AND is_deleted = 0");
        $stmt->execute([':id' => $id]);
        if ($stmt->rowCount() === 0) Http::fail(404, 'Batch not found');
        Http::json(200, ['success' => true, 'message' => 'Batch deleted']);
    }

    private function validate(array $d): array
    {
        $name = trim($d['batch_name'] ?? '');
        if ($name === '') Http::fail(400, 'Batch name is required');

        $course = (int) ($d['course_id'] ?? 0);
        $stmt = $this->pdo->prepare("SELECT id FROM courses WHERE id = :id AND is_deleted = 0");
        $stmt->execute([':id' => $course]);
        if (!$stmt->fetch()) Http::fail(400, 'Please choose a valid course');

        $start = $this->date($d['start_date'] ?? null, 'Start date');
        $end   = $this->date($d['end_date'] ?? null, 'End date');
        if ($start && $end && $end < $start) Http::fail(400, 'End date cannot be before start date');

        $cap = (int) ($d['capacity'] ?? 30);
        if ($cap < 1) Http::fail(400, 'Capacity must be at least 1');

        $status = $d['status'] ?? 'Active';
        if (!in_array($status, self::STATUSES, true)) Http::fail(400, 'Invalid status');

        return [$name, $course, $start, $end, $cap, $status];
    }

    private function date($v, string $label): ?string
    {
        if ($v === null || $v === '') return null;
        $dt = DateTime::createFromFormat('Y-m-d', $v);
        if (!$dt || $dt->format('Y-m-d') !== $v) Http::fail(400, "$label must be YYYY-MM-DD");
        return $v;
    }
}
