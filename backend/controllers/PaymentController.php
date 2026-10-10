<?php

require_once __DIR__ . '/../core/Http.php';

class PaymentController
{
    private array $rzp;

    public function __construct(private PDO $pdo, private array $me)
    {
        $this->rzp = require __DIR__ . '/../config/razorpay.php';
    }

    /*
    | POST /payments/create-order  { course_id, batch_id }
    | Price always comes from the database, never from the client.
    */
    public function createOrder(): void
    {
        $this->assertConfigured();

        $d = Http::body();
        $courseId = (int) ($d['course_id'] ?? 0);
        $batchId  = !empty($d['batch_id']) ? (int) $d['batch_id'] : null;
        $uid = $this->me['id'];

        $stmt = $this->pdo->prepare(
            "SELECT id, course_name, price FROM courses
             WHERE id = :id AND is_deleted = 0 AND status = 'published'"
        );
        $stmt->execute([':id' => $courseId]);
        $course = $stmt->fetch();
        if (!$course) Http::fail(404, 'Course not found');

        // Already bought?
        $stmt = $this->pdo->prepare(
            "SELECT 1 FROM purchases WHERE user_id = :u AND course_id = :c AND status = 'paid' LIMIT 1"
        );
        $stmt->execute([':u' => $uid, ':c' => $courseId]);
        if ($stmt->fetch()) Http::fail(409, 'You have already purchased this course');

        // Batch rules
        $stmt = $this->pdo->prepare(
            "SELECT COUNT(*) FROM batches WHERE course_id = :c AND is_deleted = 0 AND status = 'Active'"
        );
        $stmt->execute([':c' => $courseId]);
        $hasBatches = (int) $stmt->fetchColumn() > 0;

        if ($hasBatches && !$batchId) Http::fail(400, 'Please select a batch');
        if ($batchId) $this->assertBatchHasSeat($batchId, $courseId);

        $amount = (float) $course['price'];

        // Reuse an open pending purchase, otherwise create one
        $stmt = $this->pdo->prepare(
            "SELECT id FROM purchases WHERE user_id = :u AND course_id = :c AND status = 'pending' LIMIT 1"
        );
        $stmt->execute([':u' => $uid, ':c' => $courseId]);
        $purchaseId = $stmt->fetchColumn();

        if ($purchaseId) {
            $this->pdo->prepare("UPDATE purchases SET batch_id = :b, amount = :a WHERE id = :id")
                ->execute([':b' => $batchId, ':a' => $amount, ':id' => $purchaseId]);
        } else {
            $this->pdo->prepare(
                "INSERT INTO purchases (user_id, course_id, batch_id, amount, status)
                 VALUES (:u, :c, :b, :a, 'pending')"
            )->execute([':u' => $uid, ':c' => $courseId, ':b' => $batchId, ':a' => $amount]);
            $purchaseId = $this->pdo->lastInsertId();
        }
        $purchaseId = (int) $purchaseId;

        // Free course: enrol immediately (Razorpay minimum is Rs 1)
        if ($amount <= 0) {
            $this->markPaid($purchaseId, null);
            Http::json(200, ['success' => true, 'free' => true, 'message' => 'Enrolled successfully']);
        }

        $order = $this->razorpayRequest('POST', '/orders', [
            'amount'   => (int) round($amount * 100), // paise
            'currency' => $this->rzp['currency'],
            'receipt'  => 'purchase_' . $purchaseId,
            'notes'    => ['purchase_id' => $purchaseId, 'user_id' => $uid, 'course_id' => $courseId],
        ]);

        $this->pdo->prepare(
            "INSERT INTO payments (purchase_id, razorpay_order_id, amount, currency, status)
             VALUES (:p, :o, :a, :cur, 'created')"
        )->execute([':p' => $purchaseId, ':o' => $order['id'], ':a' => $amount, ':cur' => $this->rzp['currency']]);

        Http::json(200, [
            'success' => true,
            'free' => false,
            'key_id' => $this->rzp['key_id'],
            'order_id' => $order['id'],
            'amount' => $order['amount'],
            'currency' => $order['currency'],
            'course_name' => $course['course_name'],
            'user' => ['name' => $this->me['name'], 'email' => $this->me['email']],
        ]);
    }

    /*
    | POST /payments/verify { razorpay_order_id, razorpay_payment_id, razorpay_signature }
    */
    public function verify(): void
    {
        $d = Http::body();
        $orderId   = $d['razorpay_order_id'] ?? '';
        $paymentId = $d['razorpay_payment_id'] ?? '';
        $signature = $d['razorpay_signature'] ?? '';

        if ($orderId === '' || $paymentId === '' || $signature === '') {
            Http::fail(400, 'Missing payment details');
        }

        // The order must belong to the logged-in user
        $stmt = $this->pdo->prepare(
            "SELECT pay.id AS payment_row, pay.status AS pay_status, pu.id AS purchase_id, pu.user_id
             FROM payments pay JOIN purchases pu ON pu.id = pay.purchase_id
             WHERE pay.razorpay_order_id = :o LIMIT 1"
        );
        $stmt->execute([':o' => $orderId]);
        $row = $stmt->fetch();

        if (!$row || (int) $row['user_id'] !== $this->me['id']) Http::fail(404, 'Order not found');
        if ($row['pay_status'] === 'paid') Http::json(200, ['success' => true, 'message' => 'Payment already verified']);

        $expected = hash_hmac('sha256', $orderId . '|' . $paymentId, $this->rzp['key_secret']);

        if (!hash_equals($expected, $signature)) {
            $this->pdo->prepare("UPDATE payments SET status = 'failed' WHERE id = :id")
                ->execute([':id' => $row['payment_row']]);
            $this->pdo->prepare("UPDATE purchases SET status = 'failed' WHERE id = :id")
                ->execute([':id' => $row['purchase_id']]);
            Http::fail(400, 'Payment verification failed');
        }

        $this->pdo->prepare(
            "UPDATE payments SET razorpay_payment_id = :pid, razorpay_signature = :sig, status = 'paid' WHERE id = :id"
        )->execute([':pid' => $paymentId, ':sig' => $signature, ':id' => $row['payment_row']]);

        $this->markPaid((int) $row['purchase_id'], $paymentId);

        Http::json(200, ['success' => true, 'message' => 'Payment successful. Course added to My Courses.']);
    }

    /* GET /my-courses */
    public function myCourses(): void
    {
        $stmt = $this->pdo->prepare(
            "SELECT pu.id AS purchase_id, pu.amount, pu.purchased_at,
                    c.id AS course_id, c.course_name, c.description, c.duration, c.image_url,
                    b.id AS batch_id, b.batch_name, b.start_date, b.end_date
             FROM purchases pu
             JOIN courses c ON c.id = pu.course_id
             LEFT JOIN batches b ON b.id = pu.batch_id
             WHERE pu.user_id = :u AND pu.status = 'paid'
             ORDER BY pu.purchased_at DESC, pu.id DESC"
        );
        $stmt->execute([':u' => $this->me['id']]);

        Http::json(200, ['success' => true, 'courses' => $stmt->fetchAll()]);
    }

    /* ---------------------------------------------------------------- */

    private function markPaid(int $purchaseId, ?string $paymentId): void
    {
        $this->pdo->prepare(
            "UPDATE purchases SET status = 'paid', payment_id = :pid, purchased_at = NOW() WHERE id = :id"
        )->execute([':pid' => $paymentId, ':id' => $purchaseId]);
    }

    private function assertBatchHasSeat(int $batchId, int $courseId): void
    {
        $stmt = $this->pdo->prepare(
            "SELECT capacity, (SELECT COUNT(*) FROM purchases WHERE batch_id = :b AND status = 'paid') AS enrolled
             FROM batches
             WHERE id = :b2 AND course_id = :c AND is_deleted = 0 AND status = 'Active'"
        );
        $stmt->execute([':b' => $batchId, ':b2' => $batchId, ':c' => $courseId]);
        $batch = $stmt->fetch();

        if (!$batch) Http::fail(400, 'Selected batch is not available for this course');
        if ((int) $batch['enrolled'] >= (int) $batch['capacity']) Http::fail(409, 'This batch is full');
    }

    /** Stops early with a clear message when keys/curl are not set up. */
    private function assertConfigured(): void
    {
        $id = $this->rzp['key_id'];
        $secret = $this->rzp['key_secret'];

        if ($id === '' || $secret === '' || str_contains($id, 'PASTE_') || str_contains($secret, 'PASTE_')
            || str_contains($id, 'XXXX') || $secret === 'YOUR_RAZORPAY_SECRET') {
            Http::fail(500, 'Razorpay keys are not set. Edit backend/config/razorpay.php');
        }
        if (!preg_match('/^rzp_(test|live)_[A-Za-z0-9]+$/', $id)) {
            Http::fail(500, 'Razorpay Key Id looks wrong. It must look like rzp_test_xxxxxxxxxxxx (no spaces or quotes).');
        }
        if (!function_exists('curl_init')) {
            Http::fail(500, 'PHP curl extension is disabled. In php.ini remove the ; before extension=curl, then restart Apache.');
        }
    }

    /*
    | GET /payments/diagnose (admin or student) - tells you why Razorpay is not working.
    */
    public function diagnose(): void
    {
        $checks = [];
        $checks['curl_extension'] = function_exists('curl_init');
        $id = $this->rzp['key_id'];
        $checks['key_id_set'] = !(str_contains($id, 'PASTE_') || str_contains($id, 'XXXX') || $id === '');
        $checks['key_secret_set'] = !(str_contains($this->rzp['key_secret'], 'PASTE_') || $this->rzp['key_secret'] === '' || $this->rzp['key_secret'] === 'YOUR_RAZORPAY_SECRET');
        $checks['key_mode'] = str_starts_with($id, 'rzp_live_') ? 'live' : (str_starts_with($id, 'rzp_test_') ? 'test' : 'unknown');

        $checks['razorpay_reachable'] = null;
        $checks['razorpay_message'] = '';
        if ($checks['curl_extension'] && $checks['key_id_set'] && $checks['key_secret_set']) {
            $ch = curl_init('https://api.razorpay.com/v1/orders?count=1');
            curl_setopt_array($ch, $this->curlOptions() + [CURLOPT_HTTPGET => true]);
            $res = curl_exec($ch);
            $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            $err = curl_error($ch);
            curl_close($ch);

            if ($res === false) {
                $checks['razorpay_reachable'] = false;
                $checks['razorpay_message'] = 'Could not connect: ' . $err;
            } else {
                $data = json_decode($res, true);
                $checks['razorpay_reachable'] = true;
                $checks['razorpay_http'] = $code;
                $checks['razorpay_message'] = $code === 200
                    ? 'Keys are valid. Razorpay accepted the request.'
                    : ($data['error']['description'] ?? 'Razorpay rejected the request');
            }
        }

        Http::json(200, ['success' => true, 'checks' => $checks]);
    }

    private function curlOptions(): array
    {
        $verify = !empty($this->rzp['verify_ssl']);
        return [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_USERPWD => $this->rzp['key_id'] . ':' . $this->rzp['key_secret'],
            CURLOPT_SSL_VERIFYPEER => $verify,
            CURLOPT_SSL_VERIFYHOST => $verify ? 2 : 0,
            CURLOPT_CONNECTTIMEOUT => 10,
            CURLOPT_TIMEOUT => 25,
        ];
    }

    private function razorpayRequest(string $method, string $path, array $payload): array
    {
        $ch = curl_init('https://api.razorpay.com/v1' . $path);
        curl_setopt_array($ch, $this->curlOptions() + [
            CURLOPT_HTTPHEADER => ['Content-Type: application/json'],
            CURLOPT_CUSTOMREQUEST => $method,
            CURLOPT_POSTFIELDS => json_encode($payload),
        ]);
        $res = curl_exec($ch);
        $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $err = curl_error($ch);
        curl_close($ch);

        if ($res === false) Http::fail(502, 'Could not reach Razorpay: ' . $err);

        $data = json_decode($res, true);
        if ($code >= 400 || !isset($data['id'])) {
            error_log('Razorpay error: ' . $res);
            $msg = $data['error']['description'] ?? 'unknown error';
            if ($code === 401) $msg = 'Authentication failed - Key Id / Key Secret are wrong or from a different mode (test vs live)';
            Http::fail(502, 'Razorpay error: ' . $msg);
        }
        return $data;
    }
}
