import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../widgets/common.dart';

/// Student: instructions -> timed MCQ quiz -> result with answer review.
class QuizExamScreen extends StatefulWidget {
  final int examId;
  const QuizExamScreen({super.key, required this.examId});

  @override
  State<QuizExamScreen> createState() => _QuizExamScreenState();
}

class _QuizExamScreenState extends State<QuizExamScreen> {
  Map<String, dynamic>? _exam;
  Map<String, dynamic>? _attempt;
  Map<String, dynamic>? _result; // shown after submit (or when already published)
  String? _error;
  bool _loading = true;
  bool _busy = false;

  // quiz in progress
  List<Map<String, dynamic>> _questions = [];
  final Map<int, int> _answers = {}; // question id -> chosen option index
  int _attemptId = 0;
  int _current = 0;
  int? _secondsLeft;
  Timer? _timer;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Api.get('/my-exams/${widget.examId}');
      if (!mounted) return;
      final exam = Map<String, dynamic>.from(res['exam'] as Map);
      final attempt = res['attempt'] is Map ? Map<String, dynamic>.from(res['attempt'] as Map) : null;
      setState(() {
        _exam = exam;
        _attempt = attempt;
        if (attempt != null && attempt['result'] is Map) {
          _result = Map<String, dynamic>.from(attempt['result'] as Map);
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      final res = await Api.post('/my-exams/${widget.examId}/start');
      if (!mounted) return;
      final qs = asList(res['questions']);
      setState(() {
        _questions = qs;
        _attemptId = toInt(res['attempt_id']);
        _secondsLeft = res['seconds_left'] == null ? null : toInt(res['seconds_left']);
        _answers.clear();
        _current = 0;
        _running = true;
        _busy = false;
      });
      _startTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showSnack(context, e.toString(), error: true);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (_secondsLeft == null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _secondsLeft == null) return;
      setState(() => _secondsLeft = _secondsLeft! - 1);
      if (_secondsLeft! <= 0) {
        t.cancel();
        _submit(auto: true);
      }
    });
  }

  Future<void> _confirmSubmit() async {
    final unanswered = _questions.length - _answers.length;
    final ok = await confirmDialog(
      context,
      'Submit exam',
      unanswered > 0
          ? 'You have $unanswered unanswered question(s). Submit anyway? You cannot change your answers afterwards.'
          : 'Submit your answers? You cannot change them afterwards.',
      yes: 'Submit',
    );
    if (ok) await _submit();
  }

  Future<void> _submit({bool auto = false}) async {
    if (_busy) return;
    _timer?.cancel();
    setState(() => _busy = true);
    try {
      final res = await Api.post('/my-exams/${widget.examId}/submit', body: {
        'attempt_id': _attemptId,
        'answers': [
          for (final e in _answers.entries) {'question_id': e.key, 'selected_option': e.value},
        ],
      });
      if (!mounted) return;
      setState(() {
        _running = false;
        _busy = false;
        _result = Map<String, dynamic>.from(res['result'] as Map);
      });
      showSnack(context, auto ? 'Time is up. Your answers were submitted.' : str(res['message'], 'Exam submitted'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showSnack(context, e.toString(), error: true);
      // Already submitted elsewhere (409)? refresh to show the real state.
      if (e is ApiException && e.statusCode == 409) {
        setState(() => _running = false);
        _load();
      } else if (_secondsLeft != null && _secondsLeft! > 0) {
        _startTimer();
      }
    }
  }

  Future<void> _confirmLeave() async {
    final leave = await confirmDialog(
      context,
      'Leave the exam?',
      'Your timer keeps running and your answers on this screen will be lost. '
          'You can resume from the exam list, but only answers sent with Submit are counted.',
      yes: 'Leave',
    );
    if (leave && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final title = _exam != null ? str(_exam!['title'], 'Exam') : 'Exam';
    return PopScope(
      canPop: !_running,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _running) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: _body(),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    if (_result != null) return _ResultView(exam: _exam!, attempt: _attempt, result: _result!);
    if (_running) return _quiz();
    return _intro();
  }

  /* ---------------------------- intro ---------------------------- */

  Widget _intro() {
    final e = _exam!;
    final started = _attempt != null && str(_attempt!['status']) == 'started';
    final submitted = _attempt != null && !started;
    final isOpen = e['is_open'] == true;
    final notYet = e['not_open_yet'] == true;
    final canStart = started || isOpen;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(str(e['title']),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kPrimary)),
              const SizedBox(height: 4),
              Text('${str(e['subject'], '—')} · by ${str(e['created_by_name'])}',
                  style: TextStyle(color: Colors.grey.shade600)),
              const Divider(height: 24),
              _info(Icons.help_outline, '${toInt(e['question_count'])} questions'),
              _info(Icons.stars_outlined, '${formatMarks(e['total_marks'])} marks'
                  '${e['pass_marks'] != null ? ' · pass ${formatMarks(e['pass_marks'])}' : ''}'),
              if (e['duration_minutes'] != null)
                _info(Icons.timer_outlined, '${toInt(e['duration_minutes'])} minutes'),
              if (str(e['start_at']).isNotEmpty) _info(Icons.event_available, 'Opens: ${formatDateTime(e['start_at'])}'),
              if (str(e['end_at']).isNotEmpty) _info(Icons.event_busy, 'Closes: ${formatDateTime(e['end_at'])}'),
            ],
          ),
        ),
        if (str(e['instructions']).isNotEmpty)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Instructions'),
                Text(str(e['instructions'])),
              ],
            ),
          ),
        if (submitted)
          const MessageBanner('You have submitted this exam. Your result will appear here once it is available.',
              error: false)
        else if (!canStart)
          MessageBanner(notYet ? 'This exam is not open yet.' : 'This exam is closed.')
        else ...[
          if (e['duration_minutes'] != null && !started)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'The timer starts as soon as you tap Start and cannot be paused.',
                style: TextStyle(color: Colors.orange.shade800),
              ),
            ),
          PrimaryButton(label: started ? 'Resume exam' : 'Start exam', loading: _busy, onPressed: _start),
        ],
      ],
    );
  }

  Widget _info(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ]),
      );

  /* ---------------------------- quiz ---------------------------- */

  Widget _quiz() {
    final q = _questions[_current];
    final qid = toInt(q['id']);
    final options = (q['options'] as List?)?.map((o) => o.toString()).toList() ?? <String>[];
    final left = _secondsLeft;
    final low = left != null && left <= 60;

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Text('Question ${_current + 1} of ${_questions.length}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              if (left != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: low ? Colors.red.shade50 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.timer_outlined, size: 16, color: low ? Colors.red.shade700 : kPrimary),
                    const SizedBox(width: 4),
                    Text(formatCountdown(left),
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: low ? Colors.red.shade700 : kPrimary)),
                  ]),
                ),
            ],
          ),
        ),
        LinearProgressIndicator(value: _answers.length / _questions.length, minHeight: 3),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(str(q['question_text']), style: const TextStyle(fontSize: 17, height: 1.35)),
              const SizedBox(height: 4),
              Text('${formatMarks(q['marks'])} mark(s)', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 14),
              for (var i = 0; i < options.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _OptionTile(
                    letter: String.fromCharCode(65 + i),
                    text: options[i],
                    selected: _answers[qid] == i,
                    onTap: () => setState(() => _answers[qid] = i),
                  ),
                ),
              if (_answers.containsKey(qid))
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _answers.remove(qid)),
                    child: const Text('Clear answer'),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _questions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      final answered = _answers.containsKey(toInt(_questions[i]['id']));
                      final isCur = i == _current;
                      return InkWell(
                        onTap: () => setState(() => _current = i),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: answered ? kPrimary : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isCur ? Colors.orange : Colors.grey.shade400, width: isCur ? 2 : 1),
                          ),
                          child: Text('${i + 1}',
                              style: TextStyle(color: answered ? Colors.white : Colors.black87, fontSize: 13)),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _current > 0 ? () => setState(() => _current--) : null,
                        child: const Text('Previous'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _current < _questions.length - 1
                          ? FilledButton(
                              onPressed: () => setState(() => _current++),
                              child: const Text('Next'),
                            )
                          : FilledButton(
                              onPressed: _busy ? null : _confirmSubmit,
                              style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
                              child: _busy
                                  ? const SizedBox(
                                      height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Text('Submit'),
                            ),
                    ),
                  ],
                ),
                if (_current < _questions.length - 1)
                  TextButton(onPressed: _busy ? null : _confirmSubmit, child: const Text('Submit now')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String letter;
  final String text;
  final bool selected;
  final VoidCallback onTap;
  const _OptionTile({required this.letter, required this.text, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.blue.shade50 : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? kPrimary : Colors.grey.shade300, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: selected ? kPrimary : Colors.grey.shade200,
                child: Text(letter,
                    style: TextStyle(fontSize: 13, color: selected ? Colors.white : Colors.black87)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
            ],
          ),
        ),
      ),
    );
  }
}

/* ---------------------------- result ---------------------------- */

class _ResultView extends StatelessWidget {
  final Map<String, dynamic> exam;
  final Map<String, dynamic>? attempt;
  final Map<String, dynamic> result;
  const _ResultView({required this.exam, required this.attempt, required this.result});

  @override
  Widget build(BuildContext context) {
    final marks = toDouble(result['marks']);
    final total = toDouble(result['total_marks']);
    final pass = exam['pass_marks'] == null ? null : toDouble(exam['pass_marks']);
    final passed = pass == null ? null : marks >= pass;
    final review = asList(result['review']);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          child: Column(
            children: [
              Text('${formatMarks(marks)} / ${formatMarks(total)}',
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: kPrimary)),
              if (passed != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(passed ? 'Passed' : 'Not passed',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: passed ? Colors.green.shade700 : Colors.red.shade700)),
                ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _count('Correct', result['correct'], Colors.green),
                  _count('Wrong', result['wrong'], Colors.red),
                  _count('Skipped', result['skipped'], Colors.grey),
                ],
              ),
            ],
          ),
        ),
        if (review.isNotEmpty) ...[
          const SizedBox(height: 4),
          const SectionTitle('Review'),
          for (var i = 0; i < review.length; i++) _reviewCard(i, review[i]),
        ],
      ],
    );
  }

  Widget _count(String label, dynamic v, MaterialColor c) => Column(
        children: [
          Text('${toInt(v)}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: c.shade700)),
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
        ],
      );

  Widget _reviewCard(int i, Map<String, dynamic> r) {
    final options = (r['options'] as List?)?.map((o) => o.toString()).toList() ?? <String>[];
    final selected = r['selected'] == null ? null : toInt(r['selected']);
    final correct = toInt(r['correct_option']);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${i + 1}. ${str(r['question_text'])}', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (var k = 0; k < options.length; k++)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: k == correct
                    ? Colors.green.shade50
                    : (k == selected ? Colors.red.shade50 : Colors.grey.shade50),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: k == correct
                        ? Colors.green.shade300
                        : (k == selected ? Colors.red.shade300 : Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  Expanded(child: Text('${String.fromCharCode(65 + k)}. ${options[k]}')),
                  if (k == correct) Icon(Icons.check_circle, size: 18, color: Colors.green.shade700),
                  if (k == selected && k != correct) Icon(Icons.cancel, size: 18, color: Colors.red.shade700),
                ],
              ),
            ),
          if (selected == null)
            Text('Not answered', style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
          if (str(r['explanation']).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Explanation: ${str(r['explanation'])}', style: TextStyle(color: Colors.grey.shade800)),
            ),
        ],
      ),
    );
  }
}
