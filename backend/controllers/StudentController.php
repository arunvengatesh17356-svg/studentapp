<?php

require_once __DIR__ . '/../core/Http.php';

/** Student view of their own attendance. */
class StudentController
{
    public function __construct(private PDO $pdo, private array $me) {}

    /* GET /my-attendance : per batch -> per subject summary + recent records */
    public function attendance(): void
    {
        $uid = $this->me['id'];

        $stmt = $this->pdo->prepare(
            "SELECT DISTINCT b.id, b.batch_name, c.course_name
             FROM purchases pu
             JOIN batches b ON b.id = pu.batch_id AND b.is_deleted = 0
             JOIN courses c ON c.id = b.course_id
             WHERE pu.user_id = :u AND pu.status = 'paid' ORDER BY b.batch_name"
        );
        $stmt->execute([':u' => $uid]);
        $batches = $stmt->fetchAll();

        $subjStmt = $this->pdo->prepare(
            "SELECT bs.id, bs.subject_name, u.name AS staff_name,
                    SUM(at.status = 'present') AS present,
                    SUM(at.status = 'late')    AS late,
                    SUM(at.status = 'absent')  AS absent,
                    COUNT(at.id)               AS total
             FROM batch_subjects bs
             JOIN users u ON u.id = bs.staff_id
             LEFT JOIN attendance at ON at.batch_subject_id = bs.id AND at.student_id = :u
             WHERE bs.batch_id = :b
             GROUP BY bs.id, bs.subject_name, u.name
             ORDER BY bs.subject_name"
        );
        $recStmt = $this->pdo->prepare(
            "SELECT at.attendance_date, at.status, bs.subject_name
             FROM attendance at JOIN batch_subjects bs ON bs.id = at.batch_subject_id
             WHERE at.student_id = :u AND bs.batch_id = :b
             ORDER BY at.attendance_date DESC, bs.subject_name LIMIT 60"
        );

        foreach ($batches as &$b) {
            $subjStmt->execute([':u' => $uid, ':b' => $b['id']]);
            $subs = $subjStmt->fetchAll();
            foreach ($subs as &$s) {
                foreach (['present', 'late', 'absent', 'total'] as $k) $s[$k] = (int) $s[$k];
                $s['percent'] = $s['total'] > 0 ? (int) round((($s['present'] + $s['late']) / $s['total']) * 100) : null;
            }
            unset($s);
            $b['subjects'] = $subs;

            $recStmt->execute([':u' => $uid, ':b' => $b['id']]);
            $b['records'] = $recStmt->fetchAll();
        }

        Http::json(200, ['success' => true, 'batches' => $batches]);
    }

    /* GET /my-batches : for the leave-request dropdown */
    public function batches(): void
    {
        $stmt = $this->pdo->prepare(
            "SELECT DISTINCT b.id, b.batch_name, c.course_name
             FROM purchases pu
             JOIN batches b ON b.id = pu.batch_id AND b.is_deleted = 0
             JOIN courses c ON c.id = b.course_id
             WHERE pu.user_id = :u AND pu.status = 'paid' ORDER BY b.batch_name"
        );
        $stmt->execute([':u' => $this->me['id']]);
        $batches = $stmt->fetchAll();

        // who will receive a leave request for each batch
        $st = $this->pdo->prepare(
            "SELECT DISTINCT u.name, bs.subject_name FROM batch_subjects bs
             JOIN users u ON u.id = bs.staff_id WHERE bs.batch_id = :b ORDER BY u.name"
        );
        foreach ($batches as &$b) {
            $st->execute([':b' => $b['id']]);
            $b['staff'] = $st->fetchAll();
        }

        Http::json(200, ['success' => true, 'batches' => $batches]);
    }
}
