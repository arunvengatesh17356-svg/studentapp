<?php

require_once __DIR__ . '/../core/Http.php';

/** Admin-only: who purchased which course. */
class PurchaseController
{
    private const STATUSES = ['paid', 'pending', 'failed'];

    public function __construct(private PDO $pdo, private array $me) {}

    /*
    | GET /purchases?course_id=&batch_id=&status=paid&search=&from=YYYY-MM-DD&to=YYYY-MM-DD
    | status defaults to "paid" (real enrolments). Use status=all to see everything.
    */
    public function index(): void
    {
        $where = [];
        $params = [];

        $status = $_GET['status'] ?? 'paid';
        if ($status !== 'all') {
            if (!in_array($status, self::STATUSES, true)) $status = 'paid';
            $where[] = 'pu.status = :status';
            $params[':status'] = $status;
        }

        if (!empty($_GET['course_id'])) {
            $where[] = 'pu.course_id = :course';
            $params[':course'] = (int) $_GET['course_id'];
        }
        if (!empty($_GET['batch_id'])) {
            $where[] = 'pu.batch_id = :batch';
            $params[':batch'] = (int) $_GET['batch_id'];
        }

        $search = trim($_GET['search'] ?? '');
        if ($search !== '') {
            $where[] = '(u.name LIKE :q1 OR u.email LIKE :q2)';
            $params[':q1'] = "%$search%";
            $params[':q2'] = "%$search%";
        }

        if (!empty($_GET['from']) && preg_match('/^\d{4}-\d{2}-\d{2}$/', $_GET['from'])) {
            $where[] = 'DATE(pu.purchased_at) >= :from';
            $params[':from'] = $_GET['from'];
        }
        if (!empty($_GET['to']) && preg_match('/^\d{4}-\d{2}-\d{2}$/', $_GET['to'])) {
            $where[] = 'DATE(pu.purchased_at) <= :to';
            $params[':to'] = $_GET['to'];
        }

        $sql = "SELECT pu.id, pu.amount, pu.status, pu.payment_id,
                       pu.purchased_at AS purchased_at,
                       u.id AS user_id, u.name AS student_name, u.email AS student_email,
                       c.id AS course_id, c.course_name,
                       b.id AS batch_id, b.batch_name
                FROM purchases pu
                JOIN users u   ON u.id = pu.user_id
                JOIN courses c ON c.id = pu.course_id
                LEFT JOIN batches b ON b.id = pu.batch_id"
             . ($where ? ' WHERE ' . implode(' AND ', $where) : '')
             . " ORDER BY pu.purchased_at DESC, pu.id DESC";

        $stmt = $this->pdo->prepare($sql);
        $stmt->execute($params);
        $rows = $stmt->fetchAll();

        $revenue = 0.0;
        $students = [];
        foreach ($rows as &$r) {
            $r['id']        = (int) $r['id'];
            $r['amount']    = (float) $r['amount'];
            $r['user_id']   = (int) $r['user_id'];
            $r['course_id'] = (int) $r['course_id'];
            if ($r['status'] === 'paid') {
                $revenue += $r['amount'];
                $students[$r['user_id']] = true;
            }
        }
        unset($r);

        Http::json(200, [
            'success'   => true,
            'purchases' => $rows,
            'summary'   => [
                'count'    => count($rows),
                'students' => count($students),
                'revenue'  => $revenue,
            ],
        ]);
    }
}
