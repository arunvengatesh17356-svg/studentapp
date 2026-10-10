<?php

require_once __DIR__ . '/../core/Http.php';
require_once __DIR__ . '/../core/Upload.php';

/*
| Exams: student side.
| A student sees an exam only if it is published AND one of its batches is a batch
| the student has paid for. Quiz answers are marked here, on the server.
*/
class MyExamController
{
    private const MAX_PAGES = 15;
    private const MAX_PAGE_BYTES = 10 * 1024 * 1024;
    private const LATE_GRACE_SECONDS = 120; // quiz answers sent later than this after time-up are ignored
    private const SHOW_REVIEW = true;       // send the answer key + explanations after a quiz is submitted

    public function __construct(private PDO $pdo, private array $me) {}

    /* GET /my-exams */
    public function index(): void
    {
        $stmt = $this->pdo->prepare(
            "SELECT e.id, e.title, e.subject, e.type, e.total_marks, e.duration_minutes, e.start_at, e.end_at,
                    u.name AS created_by_name,
                    (SELECT COUNT(*) FROM exam_questions q WHERE q.exam_id = e.id) AS question_count,
                    a.status AS attempt_status, a.marks AS attempt_marks
             FROM exams e
             JOIN users u ON u.id = e.created_by
             LEFT JOIN exam_attempts a ON a.exam_id = e.id AND a.student_id = :u
             WHERE e.status = 'published' AND " . $this->assignedSql() . "
             ORDER BY e.id DESC"
        );
        $stmt->execute([':u' => $this->me['id']]);
        $rows = $stmt->fetchAll();

        foreach ($rows as &$r) {
            $r['id'] = (int) $r['id'];
            $r['total_marks'] = (float) $r['total_marks'];
            $r['question_count'] = (int) $r['question_count'];
            $r['duration_minutes'] = $r['duration_minutes'] !== null ? (int) $r['duration_minutes'] : null;
            $r['my_status'] = $r['attempt_status'] ?: 'pending';
            $r['marks'] = $r['attempt_status'] === 'published' && $r['attempt_marks'] !== null ? (float) $r['attempt_marks'] : null;
            unset($r['attempt_status'], $r['attempt_marks']);
            $r += $this->window($r);
        }
        Http::json(200, ['success' => true, 'exams' => $rows]);
    }

    /* GET /my-exams/{id} */
    public function show(int $id): void
    {
        $e = $this->assignedExam($id);
        $attempt = $this->myAttempt($id);

        $stmt = $this->pdo->prepare('SELECT COUNT(*) FROM exam_questions WHERE exam_id = :e');
        $stmt->execute([':e' => $id]);

        $exam = [
            'id' => (int) $e['id'], 'title' => $e['title'], 'subject' => $e['subject'], 'type' => $e['type'],
            'instructions' => $e['instructions'], 'total_marks' => (float) $e['total_marks'],
            'pass_marks' => $e['pass_marks'] !== null ? (float) $e['pass_marks'] : null,
            'duration_minutes' => $e['duration_minutes'] !== null ? (int) $e['duration_minutes'] : null,
            'start_at' => $e['start_at'], 'end_at' => $e['end_at'], 'created_by_name' => $e['created_by_name'],
            'question_count' => (int) $stmt->fetchColumn(),
            'question_paper_url' => $e['type'] === 'paper' ? Upload::url($e['question_paper']) : null,
        ] + $this->window($e);

        $out = null;
        if ($attempt) {
            $published = $attempt['status'] === 'published';
            $out = [
                'status' => $attempt['status'],
                'submitted_at' => $attempt['submitted_at'],
                'marks' => $published && $attempt['marks'] !== null ? (float) $attempt['marks'] : null,
                'remarks' => $published ? $attempt['remarks'] : null,
                'files' => $e['type'] === 'paper' ? $this->attemptFiles((int) $attempt['id']) : [],
                'result' => ($e['type'] === 'quiz' && $published) ? $this->quizResult($e, $attempt) : null,
            ];
        }
        Http::json(200, ['success' => true, 'exam' => $exam, 'attempt' => $out]);
    }

    /* POST /my-exams/{id}/start : creates the attempt, or resumes the one already started */
    public function start(int $id): void
    {
        $e = $this->assignedExam($id);
        if ($e['type'] !== 'quiz') Http::fail(400, 'This is a paper exam. Upload your answer sheets instead.');

        $attempt = $this->myAttempt($id);
        if ($attempt && $attempt['status'] !== 'started') Http::fail(409, 'You have already submitted this exam');

        if (!$attempt) {
            $w = $this->window($e);
            if (!$w['is_open']) Http::fail(403, $w['not_open_yet'] ? 'This exam is not open yet' : 'This exam is closed');
            $this->pdo->prepare(
                "INSERT INTO exam_attempts (exam_id, student_id, status, started_at) VALUES (:e, :s, 'started', :now)"
            )->execute([':e' => $id, ':s' => $this->me['id'], ':now' => date('Y-m-d H:i:s')]);
            $attempt = $this->myAttempt($id);
        }

        $stmt = $this->pdo->prepare('SELECT id, question_text, options, marks FROM exam_questions WHERE exam_id = :e ORDER BY sort_order, id');
        $stmt->execute([':e' => $id]);
        $questions = [];
        foreach ($stmt->fetchAll() as $q) {
            $questions[] = [
                'id' => (int) $q['id'], 'question_text' => $q['question_text'],
                'options' => json_decode($q['options'], true) ?: [], 'marks' => (float) $q['marks'],
            ];
        }
        if ((int) $e['shuffle_questions'] === 1) {
            // same order every time this student reloads (seeded by attempt id), different between students
            $seed = (int) $attempt['id'];
            usort($questions, fn($a, $b) => crc32($seed . '-' . $a['id']) <=> crc32($seed . '-' . $b['id']));
        }

        $deadline = $this->deadline($e, $attempt);
        Http::json(200, [
            'success' => true,
            'attempt_id' => (int) $attempt['id'],
            'seconds_left' => $deadline === null ? null : max(0, $deadline - time()),
            'questions' => $questions,
        ]);
    }

    /* POST /my-exams/{id}/submit  { attempt_id, answers: [{question_id, selected_option}] } */
    public function submitQuiz(int $id): void
    {
        $e = $this->assignedExam($id);
        if ($e['type'] !== 'quiz') Http::fail(400, 'This is not a quiz');

        $d = Http::body();
        $attempt = $this->myAttempt($id);
        if (!$attempt || (int) $attempt['id'] !== (int) ($d['attempt_id'] ?? 0)) Http::fail(404, 'Attempt not found');
        if ($attempt['status'] !== 'started') Http::fail(409, 'You have already submitted this exam');

        // too late? then the answers are ignored and everything counts as skipped
        $deadline = $this->deadline($e, $attempt);
        $late = $deadline !== null && time() > $deadline + self::LATE_GRACE_SECONDS;

        $stmt = $this->pdo->prepare('SELECT id, options, correct_option, marks FROM exam_questions WHERE exam_id = :e');
        $stmt->execute([':e' => $id]);
        $key = [];
        foreach ($stmt->fetchAll() as $q) {
            $key[(int) $q['id']] = [
                'count' => count(json_decode($q['options'], true) ?: []),
                'correct' => (int) $q['correct_option'], 'marks' => (float) $q['marks'],
            ];
        }

        $given = [];
        if (!$late && is_array($d['answers'] ?? null)) {
            foreach ($d['answers'] as $a) {
                $qid = (int) ($a['question_id'] ?? 0);
                $sel = $a['selected_option'] ?? null;
                if (!isset($key[$qid]) || !is_numeric($sel)) continue;
                $sel = (int) $sel;
                if ($sel < 0 || $sel >= $key[$qid]['count']) continue;
                $given[$qid] = $sel; // one answer per question
            }
        }

        $score = 0.0; $correct = 0; $wrong = 0;
        foreach ($given as $qid => $sel) {
            if ($sel === $key[$qid]['correct']) { $score += $key[$qid]['marks']; $correct++; } else { $wrong++; }
        }
        $skipped = count($key) - $correct - $wrong;

        $saved = [];
        foreach ($given as $qid => $sel) $saved[] = ['question_id' => $qid, 'selected_option' => $sel];

        $now = date('Y-m-d H:i:s');
        $this->pdo->prepare(
            "UPDATE exam_attempts SET status = 'published', submitted_at = :n1, published_at = :n2,
                    answers = :ans, marks = :m, correct_count = :c, wrong_count = :w, skipped_count = :s
             WHERE id = :id AND status = 'started'"
        )->execute([
            ':n1' => $now, ':n2' => $now, ':ans' => json_encode($saved), ':m' => round($score, 2),
            ':c' => $correct, ':w' => $wrong, ':s' => $skipped, ':id' => $attempt['id'],
        ]);

        $attempt = $this->myAttempt($id);
        Http::json(200, [
            'success' => true,
            'message' => $late ? 'Time was over, so your answers were not counted' : 'Exam submitted',
            'result' => $this->quizResult($e, $attempt),
        ]);
    }

    /* POST /my-exams/{id}/paper-submission  (multipart, "files[]") : creates or replaces my answer sheets */
    public function submitPaper(int $id): void
    {
        $e = $this->assignedExam($id);
        if ($e['type'] !== 'paper') Http::fail(400, 'This is not a paper exam');

        $attempt = $this->myAttempt($id);
        if ($attempt && in_array($attempt['status'], ['graded', 'published'], true)) {
            Http::fail(409, 'Your paper is already being evaluated and can no longer be changed');
        }
        $w = $this->window($e);
        if (!$w['is_open']) Http::fail(403, $w['not_open_yet'] ? 'This exam is not open yet' : 'The deadline has passed');

        Upload::failIfRequestTooBig();
        $files = Upload::files('files');
        if (!$files) Http::fail(400, 'Add at least one page');
        if (count($files) > self::MAX_PAGES) Http::fail(400, 'You can upload at most ' . self::MAX_PAGES . ' pages');

        $exts = [];
        foreach ($files as $i => $f) $exts[$i] = Upload::check($f, self::MAX_PAGE_BYTES); // check all before saving any

        $saved = [];
        foreach ($files as $i => $f) $saved[] = [Upload::save($f, $exts[$i], 'a'), $this->shortName((string) $f['name'])];

        $oldFiles = [];
        $now = date('Y-m-d H:i:s');
        $this->pdo->beginTransaction();
        try {
            $this->pdo->prepare(
                "INSERT INTO exam_attempts (exam_id, student_id, status, started_at, submitted_at)
                 VALUES (:e, :s, 'submitted', :n1, :n2)
                 ON DUPLICATE KEY UPDATE status = 'submitted', submitted_at = VALUES(submitted_at)"
            )->execute([':e' => $id, ':s' => $this->me['id'], ':n1' => $now, ':n2' => $now]);
            $attemptId = (int) $this->myAttempt($id)['id'];

            $stmt = $this->pdo->prepare('SELECT file_path FROM exam_attempt_files WHERE attempt_id = :a');
            $stmt->execute([':a' => $attemptId]);
            $oldFiles = $stmt->fetchAll(PDO::FETCH_COLUMN);
            $this->pdo->prepare('DELETE FROM exam_attempt_files WHERE attempt_id = :a')->execute([':a' => $attemptId]);

            $ins = $this->pdo->prepare('INSERT INTO exam_attempt_files (attempt_id, sort_order, file_path, original_name) VALUES (:a, :o, :f, :n)');
            foreach ($saved as $i => [$name, $orig]) $ins->execute([':a' => $attemptId, ':o' => $i, ':f' => $name, ':n' => $orig]);
            $this->pdo->commit();
        } catch (Throwable $ex) {
            $this->pdo->rollBack();
            foreach ($saved as [$name]) Upload::delete($name);
            throw $ex;
        }
        foreach ($oldFiles as $f) Upload::delete($f);

        Http::json(200, ['success' => true, 'message' => count($saved) . ' page(s) submitted']);
    }

    /* ---------------------------------------------------------------- */

    /** File name cut to 250 characters without breaking a multi-byte letter. */
    private function shortName(string $n): string
    {
        return preg_match('/^.{0,250}/us', $n, $m) ? $m[0] : '';
    }

    /** SQL: this student has paid for a batch the exam was given to. Needs :u bound and table alias e. */
    private function assignedSql(): string
    {
        return "EXISTS (SELECT 1 FROM exam_batches eb
                        JOIN purchases p ON p.batch_id = eb.batch_id
                        WHERE eb.exam_id = e.id AND p.user_id = :u AND p.status = 'paid')";
    }

    private function assignedExam(int $id): array
    {
        $stmt = $this->pdo->prepare(
            "SELECT e.*, u.name AS created_by_name FROM exams e
             JOIN users u ON u.id = e.created_by
             WHERE e.id = :id AND e.status = 'published' AND " . $this->assignedSql()
        );
        $stmt->execute([':id' => $id, ':u' => $this->me['id']]);
        $e = $stmt->fetch();
        if (!$e) Http::fail(404, 'Exam not found');
        return $e;
    }

    private function myAttempt(int $examId): ?array
    {
        $stmt = $this->pdo->prepare('SELECT * FROM exam_attempts WHERE exam_id = :e AND student_id = :s');
        $stmt->execute([':e' => $examId, ':s' => $this->me['id']]);
        return $stmt->fetch() ?: null;
    }

    /** is_open: inside the opening/closing time. not_open_yet: opening time is still in the future. */
    private function window(array $e): array
    {
        $now = date('Y-m-d H:i:s');
        $notYet = !empty($e['start_at']) && $now < $e['start_at'];
        $over = !empty($e['end_at']) && $now > $e['end_at'];
        return ['is_open' => !$notYet && !$over, 'not_open_yet' => $notYet];
    }

    /** Unix time when this attempt must end: earlier of (start + time limit) and the exam's closing time. */
    private function deadline(array $e, array $attempt): ?int
    {
        $ends = [];
        if (!empty($e['duration_minutes'])) $ends[] = strtotime($attempt['started_at']) + (int) $e['duration_minutes'] * 60;
        if (!empty($e['end_at'])) $ends[] = strtotime($e['end_at']);
        return $ends ? min($ends) : null;
    }

    private function attemptFiles(int $attemptId): array
    {
        $stmt = $this->pdo->prepare('SELECT file_path, original_name FROM exam_attempt_files WHERE attempt_id = :a ORDER BY sort_order, id');
        $stmt->execute([':a' => $attemptId]);
        return array_map(
            fn($f) => ['url' => Upload::url($f['file_path']), 'name' => $f['original_name']],
            $stmt->fetchAll()
        );
    }

    private function quizResult(array $e, array $attempt): array
    {
        $result = [
            'marks' => (float) $attempt['marks'], 'total_marks' => (float) $e['total_marks'],
            'correct' => (int) $attempt['correct_count'], 'wrong' => (int) $attempt['wrong_count'],
            'skipped' => (int) $attempt['skipped_count'], 'review' => [],
        ];
        if (self::SHOW_REVIEW) {
            $given = [];
            foreach (json_decode($attempt['answers'] ?: '[]', true) ?: [] as $a) $given[(int) $a['question_id']] = (int) $a['selected_option'];
            $stmt = $this->pdo->prepare('SELECT * FROM exam_questions WHERE exam_id = :e ORDER BY sort_order, id');
            $stmt->execute([':e' => $e['id']]);
            foreach ($stmt->fetchAll() as $q) {
                $result['review'][] = [
                    'question_text' => $q['question_text'],
                    'options' => json_decode($q['options'], true) ?: [],
                    'selected' => $given[(int) $q['id']] ?? null,
                    'correct_option' => (int) $q['correct_option'],
                    'explanation' => $q['explanation'],
                ];
            }
        }
        return $result;
    }
}