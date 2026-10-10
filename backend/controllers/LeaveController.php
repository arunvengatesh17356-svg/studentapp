<?php

require_once __DIR__ . '/../core/Http.php';

/*
| Leave requests
|   student -> goes to the staff who handle that batch, and is also visible to admin
|   staff   -> goes to admin
*/
class LeaveController
{
    private const STATUSES = ['pending', 'approved', 'rejected', 'cancelled'];

    public function __construct(private PDO $pdo, private array $me) {}

    /* POST /leaves { batch_id (students only), from_date, to_date, reason } */
    public function store(): void
    {
        $d = Http::body();
        $from = $this->date($d['from_date'] ?? '', 'From date');
        $to   = $this->date($d['to_date'] ?? '', 'To date');
        if ($to < $from) Http::fail(400, 'To date cannot be before from date');

        $reason = trim($d['reason'] ?? '');
        if ($reason === '') Http::fail(400, 'Please give a reason');
        if (Http::len($reason) > 1000) Http::fail(400, 'Reason is too long (max 1000 characters)');

        $batchId = null;
        if ($this->me['role'] === 'student') {
            $batchId = (int) ($d['batch_id'] ?? 0);
            $stmt = $this->pdo->prepare(
                "SELECT 1 FROM purchases WHERE user_id = :u AND batch_id = :b AND status = 'paid' LIMIT 1"
            );
            $stmt->execute([':u' => $this->me['id'], ':b' => $batchId]);
            if (!$stmt->fetch()) Http::fail(400, 'Please choose one of your batches');
        }

        // no overlapping open/approved request
        $stmt = $this->pdo->prepare(
            "SELECT 1 FROM leave_requests
             WHERE user_id = :u AND status IN ('pending','approved')
               AND (batch_id <=> :b) AND from_date <= :to AND to_date >= :from LIMIT 1"
        );
        $stmt->execute([':u' => $this->me['id'], ':b' => $batchId, ':to' => $to, ':from' => $from]);
        if ($stmt->fetch()) Http::fail(409, 'You already have a leave request for these dates');

        $this->pdo->prepare(
            "INSERT INTO leave_requests (user_id, user_role, batch_id, from_date, to_date, reason)
             VALUES (:u, :r, :b, :f, :t, :re)"
        )->execute([
            ':u' => $this->me['id'], ':r' => $this->me['role'], ':b' => $batchId,
            ':f' => $from, ':t' => $to, ':re' => $reason,
        ]);

        $msg = $this->me['role'] === 'student'
            ? 'Leave request sent to your batch staff and the admin'
            : 'Leave request sent to the admin';
        Http::json(201, ['success' => true, 'message' => $msg, 'id' => (int) $this->pdo->lastInsertId()]);
    }

    /* GET /leaves/mine */
    public function mine(): void
    {
        $stmt = $this->pdo->prepare(
            "SELECT lr.id, lr.batch_id, b.batch_name, lr.from_date, lr.to_date, lr.reason, lr.status,
                    lr.review_note, lr.reviewed_at, rv.name AS reviewed_by_name, lr.created_at
             FROM leave_requests lr
             LEFT JOIN batches b ON b.id = lr.batch_id
             LEFT JOIN users rv ON rv.id = lr.reviewed_by
             WHERE lr.user_id = :u ORDER BY lr.id DESC"
        );
        $stmt->execute([':u' => $this->me['id']]);
        Http::json(200, ['success' => true, 'leaves' => $stmt->fetchAll()]);
    }

    /*
    | GET /leaves/inbox?status=&role=
    | admin: everything. staff: student leaves of batches they handle.
    */
    public function inbox(): void
    {
        $where = [];
        $params = [];

        if ($this->me['role'] === 'staff') {
            $where[] = "lr.user_role = 'student'";
            $where[] = "lr.batch_id IN (SELECT batch_id FROM batch_subjects WHERE staff_id = :me)";
            $params[':me'] = $this->me['id'];
        } elseif (in_array($_GET['role'] ?? '', ['student', 'staff'], true)) {
            $where[] = 'lr.user_role = :role';
            $params[':role'] = $_GET['role'];
        }

        if (in_array($_GET['status'] ?? '', self::STATUSES, true)) {
            $where[] = 'lr.status = :st';
            $params[':st'] = $_GET['status'];
        }

        $sql = "SELECT lr.id, lr.user_id, u.name AS requester_name, u.email AS requester_email, lr.user_role,
                       lr.batch_id, b.batch_name, c.course_name,
                       lr.from_date, lr.to_date, lr.reason, lr.status, lr.review_note, lr.reviewed_at,
                       rv.name AS reviewed_by_name, lr.created_at
                FROM leave_requests lr
                JOIN users u ON u.id = lr.user_id
                LEFT JOIN batches b ON b.id = lr.batch_id
                LEFT JOIN courses c ON c.id = b.course_id
                LEFT JOIN users rv ON rv.id = lr.reviewed_by"
             . ($where ? ' WHERE ' . implode(' AND ', $where) : '')
             . " ORDER BY (lr.status = 'pending') DESC, lr.id DESC LIMIT 500";

        $stmt = $this->pdo->prepare($sql);
        $stmt->execute($params);
        Http::json(200, ['success' => true, 'leaves' => $stmt->fetchAll()]);
    }

    /* PUT /leaves/{id}/review { status: approved|rejected, note } */
    public function review(int $id): void
    {
        $d = Http::body();
        $status = $d['status'] ?? '';
        if (!in_array($status, ['approved', 'rejected'], true)) Http::fail(400, 'Status must be approved or rejected');
        $note = trim($d['note'] ?? '');
        if (Http::len($note) > 500) Http::fail(400, 'Note is too long (max 500 characters)');

        $stmt = $this->pdo->prepare("SELECT id, user_role, batch_id, status FROM leave_requests WHERE id = :id");
        $stmt->execute([':id' => $id]);
        $lr = $stmt->fetch();
        if (!$lr) Http::fail(404, 'Leave request not found');

        if ($this->me['role'] === 'staff') {
            // staff may only decide student leaves of batches they handle
            $ok = false;
            if ($lr['user_role'] === 'student' && $lr['batch_id']) {
                $s = $this->pdo->prepare("SELECT 1 FROM batch_subjects WHERE batch_id = :b AND staff_id = :u LIMIT 1");
                $s->execute([':b' => $lr['batch_id'], ':u' => $this->me['id']]);
                $ok = (bool) $s->fetch();
            }
            if (!$ok) Http::fail(403, 'You cannot review this leave request');
        }

        if ($lr['status'] !== 'pending') Http::fail(409, 'This request has already been ' . $lr['status']);

        $this->pdo->prepare(
            "UPDATE leave_requests SET status = :s, review_note = :n, reviewed_by = :r, reviewed_at = NOW() WHERE id = :id"
        )->execute([':s' => $status, ':n' => $note !== '' ? $note : null, ':r' => $this->me['id'], ':id' => $id]);

        Http::json(200, ['success' => true, 'message' => "Leave $status"]);
    }

    /* DELETE /leaves/{id} : cancel my own pending request */
    public function cancel(int $id): void
    {
        $stmt = $this->pdo->prepare(
            "UPDATE leave_requests SET status = 'cancelled' WHERE id = :id AND user_id = :u AND status = 'pending'"
        );
        $stmt->execute([':id' => $id, ':u' => $this->me['id']]);
        if ($stmt->rowCount() === 0) Http::fail(404, 'Only your own pending requests can be cancelled');
        Http::json(200, ['success' => true, 'message' => 'Leave request cancelled']);
    }

    private function date(string $v, string $label): string
    {
        $dt = DateTime::createFromFormat('Y-m-d', $v);
        if (!$dt || $dt->format('Y-m-d') !== $v) Http::fail(400, "$label must be a valid date");
        return $v;
    }
}
