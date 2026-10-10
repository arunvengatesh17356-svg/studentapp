
<?php

date_default_timezone_set('Asia/Kolkata'); // exam open/close times are compared in this timezone

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../core/Http.php';
require_once __DIR__ . '/../middleware/AuthMiddleware.php';
require_once __DIR__ . '/../controllers/AuthController.php';
require_once __DIR__ . '/../controllers/ProfileController.php';
require_once __DIR__ . '/../controllers/UserController.php';
require_once __DIR__ . '/../controllers/CourseController.php';
require_once __DIR__ . '/../controllers/BatchController.php';
require_once __DIR__ . '/../controllers/PaymentController.php';
require_once __DIR__ . '/../controllers/PurchaseController.php';
require_once __DIR__ . '/../controllers/AssignmentController.php';
require_once __DIR__ . '/../controllers/StaffController.php';
require_once __DIR__ . '/../controllers/LeaveController.php';
require_once __DIR__ . '/../controllers/StudentController.php';
require_once __DIR__ . '/../controllers/ExamController.php';
require_once __DIR__ . '/../controllers/MyExamController.php';

$method = $_SERVER['REQUEST_METHOD'];

// Everything after "/api/" so it works under any folder (XAMPP, php -S, vhost)
$uri  = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$pos  = strpos($uri, '/api/');
$path = trim($pos !== false ? substr($uri, $pos + 5) : '', '/');

$auth = new AuthMiddleware($pdo);

try {
    // ---------- Public ----------
    if ($path === 'register' && $method === 'POST') { (new AuthController($pdo))->register(); }
    if ($path === 'login'    && $method === 'POST') { (new AuthController($pdo))->login(); }
    if ($path === 'logout'   && $method === 'POST') { (new AuthController($pdo))->logout(); }
    if ($path === 'user'     && $method === 'GET')  { (new AuthController($pdo))->user(); }

    // ---------- Any logged-in user ----------
    if ($path === 'profile' || $path === 'profile/password') {
        $me = $auth->authenticate();
        $c = new ProfileController($pdo, $me);
        if ($path === 'profile' && $method === 'GET') $c->show();
        if ($path === 'profile' && $method === 'PUT') $c->update();
        if ($path === 'profile/password' && $method === 'PUT') $c->changePassword();
    }

    // ---------- Courses ----------
    if ($path === 'courses' || preg_match('#^courses/(\d+)$#', $path, $m)) {
        $id = isset($m[1]) ? (int) $m[1] : null;

        // reading: any logged-in user
        if ($method === 'GET') {
            $c = new CourseController($pdo, $auth->authenticate());
            $id ? $c->show($id) : $c->index();
        }

        // writing: admin only
        $c = new CourseController($pdo, $auth->requireRole('admin'));
        if ($method === 'POST' && !$id) $c->store();
        if ($method === 'PUT' && $id)   $c->update($id);
        if ($method === 'DELETE' && $id) $c->destroy($id);
    }

    // ---------- Admin: users ----------
    if ($path === 'users' || preg_match('#^users/(\d+)$#', $path, $m)) {
        $id = isset($m[1]) ? (int) $m[1] : null;
        $c = new UserController($pdo, $auth->requireRole('admin'));
        if ($method === 'GET' && !$id)   $c->index();
        if ($method === 'POST' && !$id)  $c->store();
        if ($method === 'PUT' && $id)    $c->update($id);
        if ($method === 'DELETE' && $id) $c->destroy($id);
    }

    // ---------- Admin: batches ----------
    if ($path === 'batches' || preg_match('#^batches/(\d+)$#', $path, $m)) {
        $id = isset($m[1]) ? (int) $m[1] : null;
        $c = new BatchController($pdo, $auth->requireRole('admin'));
        if ($method === 'GET' && !$id)   $c->index();
        if ($method === 'POST' && !$id)  $c->store();
        if ($method === 'PUT' && $id)    $c->update($id);
        if ($method === 'DELETE' && $id) $c->destroy($id);
    }

    // ---------- Student: payments & my courses ----------
    if (in_array($path, ['payments/create-order', 'payments/verify', 'my-courses'], true)) {
        $c = new PaymentController($pdo, $auth->requireRole('student'));
        if ($path === 'payments/create-order' && $method === 'POST') $c->createOrder();
        if ($path === 'payments/verify' && $method === 'POST')       $c->verify();
        if ($path === 'my-courses' && $method === 'GET')             $c->myCourses();
    }

    // ---------- Admin: purchases (who bought which course) ----------
    if ($path === 'purchases' && $method === 'GET') {
        (new PurchaseController($pdo, $auth->requireRole('admin')))->index();
    }

    // ---------- Razorpay diagnostics (admin or student) ----------
    if ($path === 'payments/diagnose' && $method === 'GET') {
        (new PaymentController($pdo, $auth->requireRole('admin', 'student')))->diagnose();
    }

    // ---------- Admin: subject/staff assignments per batch ----------
    if ($path === 'staff-list' && $method === 'GET') {
        (new AssignmentController($pdo, $auth->requireRole('admin')))->staffList();
    }
    if ($path === 'assignments' || preg_match('#^assignments/(\d+)$#', $path, $m)) {
        $id = isset($m[1]) ? (int) $m[1] : null;
        $c = new AssignmentController($pdo, $auth->requireRole('admin'));
        if ($method === 'GET' && !$id)   $c->index();
        if ($method === 'POST' && !$id)  $c->store();
        if ($method === 'PUT' && $id)    $c->update($id);
        if ($method === 'DELETE' && $id) $c->destroy($id);
    }

    // ---------- Staff dashboard ----------
    if (str_starts_with($path, 'staff/')) {
        $c = new StaffController($pdo, $auth->requireRole('staff'));
        if ($path === 'staff/dashboard' && $method === 'GET')          $c->dashboard();
        if ($path === 'staff/students' && $method === 'GET')           $c->students();
        if ($path === 'staff/attendance' && $method === 'GET')         $c->attendance();
        if ($path === 'staff/attendance' && $method === 'POST')        $c->saveAttendance();
        if ($path === 'staff/attendance/summary' && $method === 'GET') $c->summary();
    }

    // ---------- Student: attendance & batches ----------
    if ($path === 'my-attendance' || $path === 'my-batches') {
        $c = new StudentController($pdo, $auth->requireRole('student'));
        if ($path === 'my-attendance' && $method === 'GET') $c->attendance();
        if ($path === 'my-batches' && $method === 'GET')    $c->batches();
    }

    // ---------- Leave requests ----------
    if ($path === 'leaves' && $method === 'POST') {
        (new LeaveController($pdo, $auth->requireRole('student', 'staff')))->store();
    }
    if ($path === 'leaves/mine' && $method === 'GET') {
        (new LeaveController($pdo, $auth->requireRole('student', 'staff')))->mine();
    }
    if ($path === 'leaves/inbox' && $method === 'GET') {
        (new LeaveController($pdo, $auth->requireRole('admin', 'staff')))->inbox();
    }
    if (preg_match('#^leaves/(\d+)/review$#', $path, $m) && $method === 'PUT') {
        (new LeaveController($pdo, $auth->requireRole('admin', 'staff')))->review((int) $m[1]);
    }
    if (preg_match('#^leaves/(\d+)$#', $path, $m) && $method === 'DELETE') {
        (new LeaveController($pdo, $auth->requireRole('student', 'staff')))->cancel((int) $m[1]);
    }
       // ---------- Exams: admin + staff (create, assign, evaluate) ----------
    if ($path === 'exams' || str_starts_with($path, 'exams/')) {
        $c = new ExamController($pdo, $auth->requireRole('admin', 'staff'));
        if ($path === 'exams/targets' && $method === 'GET') $c->targets();
        if ($path === 'exams' && $method === 'GET')         $c->index();
        if ($path === 'exams' && $method === 'POST')        $c->store();
        if (preg_match('#^exams/(\d+)$#', $path, $m)) {
            if ($method === 'GET')    $c->show((int) $m[1]);
            if ($method === 'PUT')    $c->update((int) $m[1]);
            if ($method === 'DELETE') $c->destroy((int) $m[1]);
        }
        if (preg_match('#^exams/(\d+)/question-paper$#', $path, $m) && $method === 'POST') $c->uploadPaper((int) $m[1]);
        if (preg_match('#^exams/(\d+)/results$#', $path, $m) && $method === 'GET')         $c->results((int) $m[1]);
        if (preg_match('#^exams/(\d+)/attempts/(\d+)/grade$#', $path, $m) && $method === 'PUT') $c->grade((int) $m[1], (int) $m[2]);
        if (preg_match('#^exams/(\d+)/publish-results$#', $path, $m) && $method === 'POST') $c->publishResults((int) $m[1]);
    }

    // ---------- Exams: student (take quiz, upload answer sheets, see result) ----------
    if ($path === 'my-exams' || str_starts_with($path, 'my-exams/')) {
        $c = new MyExamController($pdo, $auth->requireRole('student'));
        if ($path === 'my-exams' && $method === 'GET') $c->index();
        if (preg_match('#^my-exams/(\d+)$#', $path, $m) && $method === 'GET')                $c->show((int) $m[1]);
        if (preg_match('#^my-exams/(\d+)/start$#', $path, $m) && $method === 'POST')         $c->start((int) $m[1]);
        if (preg_match('#^my-exams/(\d+)/submit$#', $path, $m) && $method === 'POST')        $c->submitQuiz((int) $m[1]);
        if (preg_match('#^my-exams/(\d+)/paper-submission$#', $path, $m) && $method === 'POST') $c->submitPaper((int) $m[1]);
    }

     
    Http::fail(404, 'API endpoint not found');

} catch (PDOException $e) {
    error_log($e->getMessage());
    Http::fail(500, 'Database error');
}
