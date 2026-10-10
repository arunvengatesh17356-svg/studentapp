<?php

require_once __DIR__ . '/../core/Http.php';

/** Staff dashboard: my batches/subjects, the students in them, and attendance. */
class StaffController
{
    private const STATUSES = ['present', 'absent', 'late'];

    public function __construct(private PDO $pdo, private array $me) {}

    /* GET /staff/dashboard */
    public function dashboard(): void
    {
        $stmt = $this->pdo->prepare(
            "SELECT bs.id, bs.subject_name, bs.batch_id, b.batch_name, b.status AS batch_status,
                    b.start_date, b.end_date, c.course_name,
                    (SELECT COUNT(*) FROM purchases p WHERE p.batch_id = b.id AND p.status = 'paid') AS students
             FROM batch_subjects bs
             JOIN batches b ON b.id = bs.batch_id AND b.is_deleted = 0
             JOIN courses c ON c.id = b.course_id
             WHERE bs.staff_id = :u
             ORDER BY b.batch_name, bs.subject_name"
        );
        $stmt->execute([':u' => $this->me['id']]);
        $rows = $stmt->fetchAll();
        $total = 0;
        $batchIds = [];
        foreach ($rows as &$r) {
            $r['students'] = (int) $r['students'];
            if (!isset($batchIds[$r['batch_id']])) { $batchIds[$r['batch_id']] = true; $total += $r['students']; }
        }
        unset($r);

        $stmt = $this->pdo->prepare(
            "SELECT COUNT(*) FROM leave_requests lr
             WHERE lr.status = 'pending' AND lr.user_role = 'student' AND lr.batch_id IN (
                 SELECT batch_id FROM batch_subjects WHERE staff_id = :u)"
        );
        $stmt->execute([':u' => $this->me['id']]);

        Http::json(200, [
            'success' => true,
            'assignments' => $rows,
            'summary' => [
                'batches' => count($batchIds),
                'subjects' => count($rows),
                'students' => $total,
                'pending_leaves' => (int) $stmt->fetchColumn(),
            ],
        ]);
    }

    /* GET /staff/students?assignment_id=  (or batch_id=) */
    public function students(): void
    {
        $batchId = $this->resolveBatch();
        Http::json(200, ['success' => true, 'students' => $this->batchStudents($batchId)]);
    }

    /* GET /staff/attendance?assignment_id=&date=YYYY-MM-DD */
    public function attendance(): void
    {
        $a = $this->myAssignment((int) ($_GET['assignment_id'] ?? 0));
        $date = $this->date($_GET['date'] ?? date('Y-m-d'));

        $students = $this->batchStudents((int) $a['batch_id']);

        $stmt = $this->pdo->prepare(
            "SELECT student_id, status FROM attendance WHERE batch_subject_id = :a AND attendance_date = :d"
        );
        $stmt->execute([':a' => $a['id'], ':d' => $date]);
        $marked = [];
        foreach ($stmt->fetchAll() as $r) $marked[(int) $r['student_id']] = $r['status'];

        // students on approved leave that day
        $stmt = $this->pdo->prepare(
            "SELECT user_id FROM leave_requests
             WHERE user_role = 'student' AND status = 'approved' AND batch_id = :b
               AND :d BETWEEN from_date AND to_date"
        );
        $stmt->execute([':b' => $a['batch_id'], ':d' => $date]);
        $onLeave = array_flip(array_map('intval', $stmt->fetchAll(PDO::FETCH_COLUMN)));

        foreach ($students as &$s) {
            $s['status'] = $marked[$s['id']] ?? null;
            $s['on_leave'] = isset($onLeave[$s['id']]);
        }

        Http::json(200, [
            'success' => true,
            'assignment' => $a,
            'date' => $date,
            'already_marked' => count($marked) > 0,
            'students' => $students,
        ]);
    }

    /* POST /staff/attendance { assignment_id, date, records: [{student_id, status}] } */
    public function saveAttendance(): void
    {
        $d = Http::body();
        $a = $this->myAssignment((int) ($d['assignment_id'] ?? 0));
        $date = $this->date($d['date'] ?? '');
        if ($date > date('Y-m-d')) Http::fail(400, 'You cannot mark attendance for a future date');

        $records = $d['records'] ?? null;
        if (!is_array($records) || !$records) Http::fail(400, 'No attendance records sent');

        $valid = array_column($this->batchStudents((int) $a['batch_id']), 'id');
        $valid = array_flip($valid);

        $this->pdo->beginTransaction();
        try {
            $stmt = $this->pdo->prepare(
                "INSERT INTO attendance (batch_subject_id, student_id, attendance_date, status, marked_by)
                 VALUES (:a, :s, :d, :st, :m)
                 ON DUPLICATE KEY UPDATE status = VALUES(status), marked_by = VALUES(marked_by)"
            );
            $n = 0;
            foreach ($records as $r) {
                $sid = (int) ($r['student_id'] ?? 0);
                $st = $r['status'] ?? '';
                if (!isset($valid[$sid])) continue; // not a student of this batch
                if (!in_array($st, self::STATUSES, true)) continue;
                $stmt->execute([':a' => $a['id'], ':s' => $sid, ':d' => $date, ':st' => $st, ':m' => $this->me['id']]);
                $n++;
            }
            $this->pdo->commit();
        } catch (Throwable $e) {
            $this->pdo->rollBack();
            throw $e;
        }

        Http::json(200, ['success' => true, 'message' => "Attendance saved for $n student(s)"]);
    }

    /* GET /staff/attendance/summary?assignment_id= : per student totals */
    public function summary(): void
    {
        $a = $this->myAssignment((int) ($_GET['assignment_id'] ?? 0));

        $stmt = $this->pdo->prepare(
            "SELECT u.id, u.name, u.email,
                    SUM(at.status = 'present') AS present,
                    SUM(at.status = 'late')    AS late,
                    SUM(at.status = 'absent')  AS absent,
                    COUNT(at.id)               AS total
             FROM purchases p
             JOIN users u ON u.id = p.user_id
             LEFT JOIN attendance at ON at.student_id = u.id AND at.batch_subject_id = :a
             WHERE p.batch_id = :b AND p.status = 'paid'
             GROUP BY u.id, u.name, u.email
             ORDER BY u.name"
        );
        $stmt->execute([':a' => $a['id'], ':b' => $a['batch_id']]);
        $rows = $stmt->fetchAll();
        foreach ($rows as &$r) {
            foreach (['present', 'late', 'absent', 'total'] as $k) $r[$k] = (int) $r[$k];
            $r['percent'] = $r['total'] > 0 ? (int) round((($r['present'] + $r['late']) / $r['total']) * 100) : null;
        }

        Http::json(200, ['success' => true, 'assignment' => $a, 'students' => $rows]);
    }

    /* ---------------------------------------------------------------- */

    private function batchStudents(int $batchId): array
    {
        $stmt = $this->pdo->prepare(
            "SELECT DISTINCT u.id, u.name, u.email, pu.purchased_at
             FROM purchases pu JOIN users u ON u.id = pu.user_id
             WHERE pu.batch_id = :b AND pu.status = 'paid'
             ORDER BY u.name"
        );
        $stmt->execute([':b' => $batchId]);
        $rows = $stmt->fetchAll();
        foreach ($rows as &$r) $r['id'] = (int) $r['id'];
        return $rows;
    }

    /** Staff may only touch assignments that belong to them. */
    private function myAssignment(int $id): array
    {
        $stmt = $this->pdo->prepare(
            "SELECT bs.id, bs.subject_name, bs.batch_id, b.batch_name, c.course_name
             FROM batch_subjects bs
             JOIN batches b ON b.id = bs.batch_id AND b.is_deleted = 0
             JOIN courses c ON c.id = b.course_id
             WHERE bs.id = :id AND bs.staff_id = :u"
        );
        $stmt->execute([':id' => $id, ':u' => $this->me['id']]);
        $a = $stmt->fetch();
        if (!$a) Http::fail(404, 'Subject not found or not assigned to you');
        $a['id'] = (int) $a['id'];
        $a['batch_id'] = (int) $a['batch_id'];
        return $a;
    }

    private function resolveBatch(): int
    {
        if (!empty($_GET['assignment_id'])) {
            return (int) $this->myAssignment((int) $_GET['assignment_id'])['batch_id'];
        }
        $batchId = (int) ($_GET['batch_id'] ?? 0);
        $stmt = $this->pdo->prepare("SELECT 1 FROM batch_subjects WHERE batch_id = :b AND staff_id = :u LIMIT 1");
        $stmt->execute([':b' => $batchId, ':u' => $this->me['id']]);
        if (!$stmt->fetch()) Http::fail(403, 'This batch is not assigned to you');
        return $batchId;
    }

    private function date(string $v): string
    {
        $dt = DateTime::createFromFormat('Y-m-d', $v);
        if (!$dt || $dt->format('Y-m-d') !== $v) Http::fail(400, 'Date must be YYYY-MM-DD');
        return $v;
    }
}
