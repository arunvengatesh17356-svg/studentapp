<?php

require_once __DIR__ . '/../core/Http.php';
require_once __DIR__ . '/../core/Upload.php';

/*
| Exams: creator side (admin + staff).
|   admin -> every exam
|   staff -> only the exams they created, and only for their own batches
| Quiz  = MCQ questions saved here, marked automatically (see MyExamController)
| Paper = a question paper file; students upload answer sheets; the teacher marks them here
*/
class ExamController
{
    private const MAX_PAPER_BYTES = 15 * 1024 * 1024;

    public function __construct(private PDO $pdo, private array $me) {}

    private function isAdmin(): bool
    {
        return $this->me['role'] === 'admin';
    }

    /* ---------------------------------------------------------------- */
    /* GET /exams/targets : batches this user may give an exam to        */
    /* ---------------------------------------------------------------- */
    public function targets(): void
    {
        Http::json(200, ['success' => true, 'batches' => $this->targetRows()]);
    }

    /* GET /exams */
    public function index(): void
    {
        $sql = "SELECT e.id, e.title, e.subject, e.type, e.status, e.total_marks, e.start_at, e.end_at,
                       e.created_by, u.name AS created_by_name,
                       (SELECT GROUP_CONCAT(b.batch_name ORDER BY b.batch_name SEPARATOR ', ')
                          FROM exam_batches eb JOIN batches b ON b.id = eb.batch_id
                         WHERE eb.exam_id = e.id) AS batch_names,
                       (SELECT COUNT(DISTINCT p.user_id)
                          FROM exam_batches eb JOIN purchases p ON p.batch_id = eb.batch_id AND p.status = 'paid'
                         WHERE eb.exam_id = e.id) AS assigned_count,
                       (SELECT COUNT(*) FROM exam_attempts a
                         WHERE a.exam_id = e.id AND a.status <> 'started') AS submitted_count
                FROM exams e JOIN users u ON u.id = e.created_by";
        $params = [];
        if (!$this->isAdmin()) {
            // staff: exams they created + exams given to a batch they teach
            $sql .= ' WHERE (e.created_by = :me OR EXISTS (
                          SELECT 1 FROM exam_batches eb2
                          JOIN batch_subjects bs ON bs.batch_id = eb2.batch_id AND bs.staff_id = :me2
                         WHERE eb2.exam_id = e.id))';
            $params[':me'] = $this->me['id'];
            $params[':me2'] = $this->me['id'];
        }
        $stmt = $this->pdo->prepare($sql . ' ORDER BY e.id DESC');
        $stmt->execute($params);
        $rows = $stmt->fetchAll();
        foreach ($rows as &$r) {
            $r['id'] = (int) $r['id'];
            $r['total_marks'] = (float) $r['total_marks'];
            $r['assigned_count'] = (int) $r['assigned_count'];
            $r['submitted_count'] = (int) $r['submitted_count'];
        }
        Http::json(200, ['success' => true, 'exams' => $rows]);
    }

    /* GET /exams/{id} */
    public function show(int $id): void
    {
        $e = $this->ownedExam($id);

        $stmt = $this->pdo->prepare('SELECT batch_id FROM exam_batches WHERE exam_id = :e');
        $stmt->execute([':e' => $id]);
        $e['batch_ids'] = array_map('intval', $stmt->fetchAll(PDO::FETCH_COLUMN));

        $questions = [];
        if ($e['type'] === 'quiz') {
            foreach ($this->questionRows($id) as $q) {
                $questions[] = [
                    'id' => (int) $q['id'],
                    'question_text' => $q['question_text'],
                    'options' => json_decode($q['options'], true) ?: [],
                    'correct_option' => (int) $q['correct_option'],
                    'marks' => (float) $q['marks'],
                    'explanation' => $q['explanation'] ?? '',
                ];
            }
        }

        $e['question_paper_url'] = Upload::url($e['question_paper']);
        unset($e['question_paper']);
        $e['total_marks'] = (float) $e['total_marks'];
        $e['pass_marks'] = $e['pass_marks'] !== null ? (float) $e['pass_marks'] : null;
        $e['duration_minutes'] = $e['duration_minutes'] !== null ? (int) $e['duration_minutes'] : null;
        $e['shuffle_questions'] = (int) $e['shuffle_questions'];

        Http::json(200, ['success' => true, 'exam' => $e, 'questions' => $questions]);
    }

    /* POST /exams */
    public function store(): void
    {
        $v = $this->validate(Http::body(), null);

        $this->pdo->beginTransaction();
        try {
            $stmt = $this->pdo->prepare(
                "INSERT INTO exams (title, subject, type, instructions, duration_minutes, total_marks, pass_marks,
                                    start_at, end_at, shuffle_questions, status, created_by)
                 VALUES (:t, :s, :ty, :i, :d, :tm, :pm, :st, :en, :sh, :stat, :u)"
            );
            $stmt->execute([
                ':t' => $v['title'], ':s' => $v['subject'], ':ty' => $v['type'], ':i' => $v['instructions'],
                ':d' => $v['duration'], ':tm' => $v['total'], ':pm' => $v['pass'],
                ':st' => $v['start'], ':en' => $v['end'], ':sh' => $v['shuffle'], ':stat' => $v['status'],
                ':u' => $this->me['id'],
            ]);
            $id = (int) $this->pdo->lastInsertId();
            $this->saveBatches($id, $v['batch_ids']);
            if ($v['type'] === 'quiz') $this->saveQuestions($id, $v['questions']);
            $this->pdo->commit();
        } catch (Throwable $e) {
            $this->pdo->rollBack();
            throw $e;
        }

        Http::json(201, ['success' => true, 'id' => $id, 'message' => 'Exam created']);
    }

    /* PUT /exams/{id} */
    public function update(int $id): void
    {
        $e = $this->ownedExam($id);
        $v = $this->validate(Http::body(), $e['type']); // type can never change

        $replaceQuestions = false;
        if ($e['type'] === 'quiz') {
            $stmt = $this->pdo->prepare('SELECT COUNT(*) FROM exam_attempts WHERE exam_id = :e');
            $stmt->execute([':e' => $id]);
            $hasAttempts = (int) $stmt->fetchColumn() > 0;
            if ($hasAttempts && $this->questionsChanged($id, $v['questions'])) {
                Http::fail(409, 'Students have already attempted this quiz, so its questions can no longer be changed. Create a new exam instead.');
            }
            $replaceQuestions = !$hasAttempts;
        }

        $this->pdo->beginTransaction();
        try {
            $stmt = $this->pdo->prepare(
                "UPDATE exams SET title=:t, subject=:s, instructions=:i, duration_minutes=:d, total_marks=:tm,
                        pass_marks=:pm, start_at=:st, end_at=:en, shuffle_questions=:sh, status=:stat, updated_at=:now
                 WHERE id=:id"
            );
            $stmt->execute([
                ':t' => $v['title'], ':s' => $v['subject'], ':i' => $v['instructions'], ':d' => $v['duration'],
                ':tm' => $v['total'], ':pm' => $v['pass'], ':st' => $v['start'], ':en' => $v['end'],
                ':sh' => $v['shuffle'], ':stat' => $v['status'], ':now' => date('Y-m-d H:i:s'), ':id' => $id,
            ]);
            $this->saveBatches($id, $v['batch_ids']);
            if ($replaceQuestions) $this->saveQuestions($id, $v['questions']);
            $this->pdo->commit();
        } catch (Throwable $ex) {
            $this->pdo->rollBack();
            throw $ex;
        }

        Http::json(200, ['success' => true, 'message' => 'Exam updated']);
    }

    /* DELETE /exams/{id} : also removes the attempts and the uploaded files */
    public function destroy(int $id): void
    {
        $e = $this->ownedExam($id);

        $stmt = $this->pdo->prepare(
            "SELECT f.file_path FROM exam_attempt_files f
             JOIN exam_attempts a ON a.id = f.attempt_id WHERE a.exam_id = :e"
        );
        $stmt->execute([':e' => $id]);
        $files = $stmt->fetchAll(PDO::FETCH_COLUMN);
        if ($e['question_paper']) $files[] = $e['question_paper'];

        $this->pdo->prepare('DELETE FROM exams WHERE id = :id')->execute([':id' => $id]); // children cascade
        foreach ($files as $f) Upload::delete($f);

        Http::json(200, ['success' => true, 'message' => 'Exam deleted']);
    }

    /* POST /exams/{id}/question-paper  (multipart, field "question_paper") */
    public function uploadPaper(int $id): void
    {
        $e = $this->ownedExam($id);
        if ($e['type'] !== 'paper') Http::fail(400, 'Only paper exams have a question paper');

        Upload::failIfRequestTooBig();
        $files = Upload::files('question_paper');
        if (count($files) !== 1) Http::fail(400, 'Choose one question paper file');

        $ext = Upload::check($files[0], self::MAX_PAPER_BYTES);
        $name = Upload::save($files[0], $ext, 'q');

        $this->pdo->prepare('UPDATE exams SET question_paper = :f, updated_at = :now WHERE id = :id')
            ->execute([':f' => $name, ':now' => date('Y-m-d H:i:s'), ':id' => $id]);
        Upload::delete($e['question_paper']); // old one

        Http::json(200, ['success' => true, 'message' => 'Question paper uploaded', 'question_paper_url' => Upload::url($name)]);
    }

    /* GET /exams/{id}/results : one row per assigned student, even if not submitted yet */
    public function results(int $id): void
    {
        $e = $this->ownedExam($id, true);

        $stmt = $this->pdo->prepare(
            "SELECT u.id AS student_id, u.name AS student_name, MIN(b.batch_name) AS batch_name
             FROM exam_batches eb
             JOIN purchases p ON p.batch_id = eb.batch_id AND p.status = 'paid'
             JOIN batches b ON b.id = p.batch_id
             JOIN users u ON u.id = p.user_id
             WHERE eb.exam_id = :e
             GROUP BY u.id, u.name
             ORDER BY u.name"
        );
        $stmt->execute([':e' => $id]);
        $students = $stmt->fetchAll();

        $stmt = $this->pdo->prepare('SELECT * FROM exam_attempts WHERE exam_id = :e');
        $stmt->execute([':e' => $id]);
        $attempts = [];
        foreach ($stmt->fetchAll() as $a) $attempts[(int) $a['student_id']] = $a;

        $files = [];
        if ($attempts) {
            $ids = array_values(array_map(fn($a) => (int) $a['id'], $attempts));
            $in = implode(',', array_fill(0, count($ids), '?'));
            $fs = $this->pdo->prepare(
                "SELECT attempt_id, file_path, original_name FROM exam_attempt_files
                 WHERE attempt_id IN ($in) ORDER BY attempt_id, sort_order, id"
            );
            $fs->execute($ids);
            foreach ($fs->fetchAll() as $f) {
                $files[(int) $f['attempt_id']][] = ['url' => Upload::url($f['file_path']), 'name' => $f['original_name']];
            }
        }

        $rows = [];
        foreach ($students as $s) {
            $a = $attempts[(int) $s['student_id']] ?? null;
            $rows[] = [
                'attempt_id' => $a ? (int) $a['id'] : null,
                'student_id' => (int) $s['student_id'],
                'student_name' => $s['student_name'],
                'batch_name' => $s['batch_name'],
                'status' => $a ? $a['status'] : 'pending',
                'marks' => $a && $a['marks'] !== null ? (float) $a['marks'] : null,
                'remarks' => $a['remarks'] ?? null,
                'submitted_at' => $a['submitted_at'] ?? null,
                'files' => $a ? ($files[(int) $a['id']] ?? []) : [],
            ];
        }

        Http::json(200, [
            'success' => true,
            'exam' => [
                'id' => (int) $e['id'], 'title' => $e['title'], 'type' => $e['type'],
                'total_marks' => (float) $e['total_marks'],
                'pass_marks' => $e['pass_marks'] !== null ? (float) $e['pass_marks'] : null,
            ],
            'rows' => $rows,
        ]);
    }

    /* PUT /exams/{id}/attempts/{attemptId}/grade  { marks, remarks, publish } */
    public function grade(int $id, int $attemptId): void
    {
        $e = $this->ownedExam($id, true);
        if ($e['type'] !== 'paper') Http::fail(400, 'Quiz results are marked automatically');

        $stmt = $this->pdo->prepare('SELECT * FROM exam_attempts WHERE id = :a AND exam_id = :e');
        $stmt->execute([':a' => $attemptId, ':e' => $id]);
        $a = $stmt->fetch();
        if (!$a) Http::fail(404, 'Submission not found');
        if ($a['status'] === 'started') Http::fail(400, 'This student has not submitted the answer sheets yet');

        $d = Http::body();
        if (!isset($d['marks']) || !is_numeric($d['marks'])) Http::fail(400, 'Enter the marks');
        $marks = round((float) $d['marks'], 2);
        if ($marks < 0 || $marks > (float) $e['total_marks']) Http::fail(400, 'Marks must be between 0 and ' . (float) $e['total_marks']);
        $remarks = trim((string) ($d['remarks'] ?? ''));
        if (Http::len($remarks) > 1000) Http::fail(400, 'Remarks are too long (max 1000 characters)');

        $publish = !empty($d['publish']);
        $now = date('Y-m-d H:i:s');
        $this->pdo->prepare(
            "UPDATE exam_attempts SET marks = :m, remarks = :r, graded_by = :g, graded_at = :now,
                    status = :st, published_at = :pub WHERE id = :id"
        )->execute([
            ':m' => $marks, ':r' => $remarks === '' ? null : $remarks, ':g' => $this->me['id'], ':now' => $now,
            ':st' => $publish ? 'published' : 'graded', ':pub' => $publish ? $now : null, ':id' => $attemptId,
        ]);

        Http::json(200, ['success' => true, 'message' => $publish ? 'Result sent to the student' : 'Marks saved']);
    }

    /* POST /exams/{id}/publish-results : every marked (graded) paper becomes visible to its student */
    public function publishResults(int $id): void
    {
        $this->ownedExam($id, true);
        $stmt = $this->pdo->prepare(
            "UPDATE exam_attempts SET status = 'published', published_at = :now
             WHERE exam_id = :e AND status = 'graded'"
        );
        $stmt->execute([':now' => date('Y-m-d H:i:s'), ':e' => $id]);
        Http::json(200, ['success' => true, 'message' => $stmt->rowCount() . ' result(s) published']);
    }

    /* ---------------------------------------------------------------- */

    /**
     * Admin sees all exams. Staff can always manage exams they created; with $forReview = true
     * (results / marking) they can also open exams given to a batch they teach.
     */
    private function ownedExam(int $id, bool $forReview = false): array
    {
        $stmt = $this->pdo->prepare('SELECT * FROM exams WHERE id = :id');
        $stmt->execute([':id' => $id]);
        $e = $stmt->fetch();
        $allowed = $e && ($this->isAdmin() || (int) $e['created_by'] === $this->me['id']
            || ($forReview && $this->teachesExamBatch($id)));
        if (!$allowed) Http::fail(404, 'Exam not found');
        return $e;
    }

    private function teachesExamBatch(int $examId): bool
    {
        $stmt = $this->pdo->prepare(
            "SELECT 1 FROM exam_batches eb
             JOIN batch_subjects bs ON bs.batch_id = eb.batch_id AND bs.staff_id = :u
             WHERE eb.exam_id = :e LIMIT 1"
        );
        $stmt->execute([':u' => $this->me['id'], ':e' => $examId]);
        return (bool) $stmt->fetchColumn();
    }

    /** Batches this user may assign: admin = all, staff = batches they teach. */
    private function targetRows(): array
    {
        if ($this->isAdmin()) {
            $stmt = $this->pdo->query(
                "SELECT b.id, b.batch_name, c.course_name FROM batches b
                 JOIN courses c ON c.id = b.course_id
                 WHERE b.is_deleted = 0 ORDER BY b.batch_name"
            );
        } else {
            $stmt = $this->pdo->prepare(
                "SELECT DISTINCT b.id, b.batch_name, c.course_name FROM batches b
                 JOIN courses c ON c.id = b.course_id
                 JOIN batch_subjects bs ON bs.batch_id = b.id AND bs.staff_id = :u
                 WHERE b.is_deleted = 0 ORDER BY b.batch_name"
            );
            $stmt->execute([':u' => $this->me['id']]);
        }
        $rows = $stmt->fetchAll();
        foreach ($rows as &$r) $r['id'] = (int) $r['id'];
        return $rows;
    }

    private function questionRows(int $examId): array
    {
        $stmt = $this->pdo->prepare('SELECT * FROM exam_questions WHERE exam_id = :e ORDER BY sort_order, id');
        $stmt->execute([':e' => $examId]);
        return $stmt->fetchAll();
    }

    private function saveBatches(int $examId, array $batchIds): void
    {
        $this->pdo->prepare('DELETE FROM exam_batches WHERE exam_id = :e')->execute([':e' => $examId]);
        $ins = $this->pdo->prepare('INSERT INTO exam_batches (exam_id, batch_id) VALUES (:e, :b)');
        foreach ($batchIds as $b) $ins->execute([':e' => $examId, ':b' => $b]);
    }

    private function saveQuestions(int $examId, array $questions): void
    {
        $this->pdo->prepare('DELETE FROM exam_questions WHERE exam_id = :e')->execute([':e' => $examId]);
        $ins = $this->pdo->prepare(
            "INSERT INTO exam_questions (exam_id, sort_order, question_text, options, correct_option, marks, explanation)
             VALUES (:e, :o, :q, :op, :c, :m, :x)"
        );
        foreach ($questions as $i => $q) {
            $ins->execute([
                ':e' => $examId, ':o' => $i, ':q' => $q['question_text'],
                ':op' => json_encode($q['options'], JSON_UNESCAPED_UNICODE),
                ':c' => $q['correct_option'], ':m' => $q['marks'], ':x' => $q['explanation'],
            ]);
        }
    }

    /** True if the submitted questions differ from the saved ones (text, options, answer or marks). */
    private function questionsChanged(int $examId, array $new): bool
    {
        $old = [];
        foreach ($this->questionRows($examId) as $q) {
            $old[] = [$q['question_text'], json_decode($q['options'], true), (int) $q['correct_option'], (float) $q['marks']];
        }
        $cmp = [];
        foreach ($new as $q) $cmp[] = [$q['question_text'], $q['options'], $q['correct_option'], (float) $q['marks']];
        return json_encode($old) !== json_encode($cmp);
    }

    /** Validates the request body. $fixedType is the saved type when editing. */
    private function validate(array $d, ?string $fixedType): array
    {
        $title = trim((string) ($d['title'] ?? ''));
        if ($title === '' || Http::len($title) > 255) Http::fail(400, 'Title is required (max 255 characters)');

        $subject = trim((string) ($d['subject'] ?? ''));
        if (Http::len($subject) > 255) Http::fail(400, 'Subject is too long');

        $type = $fixedType ?? (string) ($d['type'] ?? '');
        if (!in_array($type, ['quiz', 'paper'], true)) Http::fail(400, 'Exam type must be quiz or paper');

        $status = (string) ($d['status'] ?? 'published');
        if (!in_array($status, ['draft', 'published'], true)) Http::fail(400, 'Invalid status');

        $instructions = trim((string) ($d['instructions'] ?? ''));
        if (Http::len($instructions) > 5000) Http::fail(400, 'Instructions are too long');

        $duration = null;
        if ($type === 'quiz' && isset($d['duration_minutes']) && $d['duration_minutes'] !== '') {
            $duration = (int) $d['duration_minutes'];
            if ($duration < 1 || $duration > 600) Http::fail(400, 'Time limit must be between 1 and 600 minutes');
        }

        $pass = null;
        if (isset($d['pass_marks']) && $d['pass_marks'] !== '') {
            if (!is_numeric($d['pass_marks']) || (float) $d['pass_marks'] < 0) Http::fail(400, 'Pass marks must be a number');
            $pass = (float) $d['pass_marks'];
        }

        $start = $this->dateTime($d['start_at'] ?? null, 'Opening time');
        $end = $this->dateTime($d['end_at'] ?? null, 'Closing time');
        if ($start && $end && $end < $start) Http::fail(400, 'Closing time must be after the opening time');

        // batches
        $raw = is_array($d['batch_ids'] ?? null) ? $d['batch_ids'] : [];
        $batchIds = array_values(array_unique(array_filter(array_map('intval', $raw))));
        if (!$batchIds) Http::fail(400, 'Select at least one batch');
        $allowed = array_flip(array_column($this->targetRows(), 'id'));
        foreach ($batchIds as $b) {
            if (!isset($allowed[$b])) Http::fail(403, 'You cannot give an exam to one of the selected batches');
        }

        // marks + questions
        $questions = [];
        if ($type === 'quiz') {
            $list = $d['questions'] ?? null;
            if (!is_array($list) || !$list) Http::fail(400, 'Add at least one question');
            $total = 0.0;
            foreach (array_values($list) as $i => $q) {
                $n = $i + 1;
                $text = trim((string) ($q['question_text'] ?? ''));
                if ($text === '') Http::fail(400, "Question $n: enter the question");
                $opts = $q['options'] ?? null;
                if (!is_array($opts) || count($opts) < 2 || count($opts) > 6) Http::fail(400, "Question $n: give 2 to 6 options");
                $opts = array_map(fn($o) => trim((string) $o), array_values($opts));
                if (in_array('', $opts, true)) Http::fail(400, "Question $n: fill every option");
                $correct = $q['correct_option'] ?? null;
                if (!is_numeric($correct) || (int) $correct < 0 || (int) $correct >= count($opts)) {
                    Http::fail(400, "Question $n: choose the correct option");
                }
                $marks = $q['marks'] ?? 1;
                if (!is_numeric($marks) || (float) $marks <= 0 || (float) $marks > 1000) Http::fail(400, "Question $n: marks must be more than 0");
                $total += (float) $marks;
                $questions[] = [
                    'question_text' => $text, 'options' => $opts, 'correct_option' => (int) $correct,
                    'marks' => round((float) $marks, 2), 'explanation' => trim((string) ($q['explanation'] ?? '')) ?: null,
                ];
            }
        } else {
            $total = (float) ($d['total_marks'] ?? 0);
            if ($total <= 0 || $total > 10000) Http::fail(400, 'Total marks must be more than 0');
        }
        if ($pass !== null && $pass > $total) Http::fail(400, 'Pass marks cannot be more than the total marks');

        return [
            'title' => $title, 'subject' => $subject === '' ? null : $subject, 'type' => $type, 'status' => $status,
            'instructions' => $instructions === '' ? null : $instructions, 'duration' => $duration,
            'pass' => $pass, 'total' => round($total, 2), 'start' => $start, 'end' => $end,
            'shuffle' => !empty($d['shuffle_questions']) ? 1 : 0, 'batch_ids' => $batchIds, 'questions' => $questions,
        ];
    }

    private function dateTime($v, string $label): ?string
    {
        if ($v === null || $v === '') return null;
        $dt = DateTime::createFromFormat('Y-m-d H:i:s', (string) $v);
        if (!$dt || $dt->format('Y-m-d H:i:s') !== $v) Http::fail(400, "$label must look like YYYY-MM-DD HH:MM:SS");
        return $v;
    }
}