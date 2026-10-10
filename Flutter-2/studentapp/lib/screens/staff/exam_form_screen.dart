import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../widgets/common.dart';

class _Question {
  final TextEditingController text = TextEditingController();
  final TextEditingController marks = TextEditingController(text: '1');
  final TextEditingController explanation = TextEditingController();
  final List<TextEditingController> options = [TextEditingController(), TextEditingController()];
  int correct = 0;

  _Question();

  _Question.from(Map<String, dynamic> q) {
    text.text = str(q['question_text']);
    marks.text = formatMarks(q['marks']);
    explanation.text = str(q['explanation']);
    options.clear();
    for (final o in (q['options'] as List? ?? const [])) {
      options.add(TextEditingController(text: o.toString()));
    }
    while (options.length < 2) {
      options.add(TextEditingController());
    }
    correct = toInt(q['correct_option']);
  }

  void dispose() {
    text.dispose();
    marks.dispose();
    explanation.dispose();
    for (final o in options) {
      o.dispose();
    }
  }
}

/// Staff: create or edit a quiz (MCQ) or a paper exam.
class ExamFormScreen extends StatefulWidget {
  final int? examId;
  const ExamFormScreen({super.key, this.examId});

  @override
  State<ExamFormScreen> createState() => _ExamFormScreenState();
}

class _ExamFormScreenState extends State<ExamFormScreen> {
  int? _id;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String? _error;

  List<Map<String, dynamic>> _batches = [];
  final Set<int> _batchIds = {};

  final _title = TextEditingController();
  final _subject = TextEditingController();
  final _instructions = TextEditingController();
  final _duration = TextEditingController();
  final _totalMarks = TextEditingController();
  final _passMarks = TextEditingController();

  String _type = 'quiz';
  String _status = 'published';
  bool _shuffle = false;
  DateTime? _start;
  DateTime? _end;
  final List<_Question> _questions = [_Question()];

  String _existingPaperUrl = '';
  UploadFile? _paperFile;

  bool get _editing => _id != null;

  @override
  void initState() {
    super.initState();
    _id = widget.examId;
    _load();
  }

  @override
  void dispose() {
    for (final c in [_title, _subject, _instructions, _duration, _totalMarks, _passMarks]) {
      c.dispose();
    }
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final targets = await Api.get('/exams/targets');
      _batches = asList(targets['batches']);

      if (widget.examId != null) {
        final res = await Api.get('/exams/${widget.examId}');
        final e = Map<String, dynamic>.from(res['exam'] as Map);
        _type = str(e['type'], 'quiz');
        _title.text = str(e['title']);
        _subject.text = str(e['subject']);
        _instructions.text = str(e['instructions']);
        _duration.text = e['duration_minutes'] == null ? '' : '${toInt(e['duration_minutes'])}';
        _totalMarks.text = formatMarks(e['total_marks']);
        _passMarks.text = e['pass_marks'] == null ? '' : formatMarks(e['pass_marks']);
        _status = str(e['status'], 'published');
        _shuffle = toInt(e['shuffle_questions']) == 1;
        _start = parseSqlDateTime(e['start_at']);
        _end = parseSqlDateTime(e['end_at']);
        _existingPaperUrl = str(e['question_paper_url']);
        _batchIds
          ..clear()
          ..addAll(((e['batch_ids'] as List?) ?? const []).map(toInt));
        if (_type == 'quiz') {
          final qs = asList(res['questions']);
          if (qs.isNotEmpty) {
            for (final q in _questions) {
              q.dispose();
            }
            _questions
              ..clear()
              ..addAll(qs.map(_Question.from));
          }
        }
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  /* ---------------------------- helpers ---------------------------- */

  Future<void> _pickDateTime(bool isStart) async {
    final current = (isStart ? _start : _end) ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(current));
    if (time == null) return;
    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() => isStart ? _start = dt : _end = dt);
  }

  Future<void> _pickPaper() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) return;
      final f = res.files.first;
      if (f.bytes == null) return;
      if (f.bytes!.length > 15 * 1024 * 1024) {
        if (mounted) showSnack(context, 'The question paper must be smaller than 15 MB', error: true);
        return;
      }
      setState(() => _paperFile = UploadFile(f.name, f.bytes!));
    } catch (e) {
      if (mounted) showSnack(context, 'Could not pick the file: $e', error: true);
    }
  }

  double get _quizTotal =>
      _questions.fold(0.0, (sum, q) => sum + (double.tryParse(q.marks.text.trim()) ?? 0));

  /* ---------------------------- save ---------------------------- */

  Map<String, dynamic>? _buildBody() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      _fail('Enter a title');
      return null;
    }
    if (_batchIds.isEmpty) {
      _fail('Select at least one batch');
      return null;
    }
    if (_start != null && _end != null && _end!.isBefore(_start!)) {
      _fail('Closing time must be after the opening time');
      return null;
    }

    final body = <String, dynamic>{
      'title': title,
      'subject': _subject.text.trim(),
      'type': _type,
      'instructions': _instructions.text.trim(),
      'pass_marks': _passMarks.text.trim(),
      'start_at': _start == null ? '' : sqlDateTime(_start!),
      'end_at': _end == null ? '' : sqlDateTime(_end!),
      'status': _status,
      'batch_ids': _batchIds.toList(),
    };

    if (_type == 'quiz') {
      body['duration_minutes'] = _duration.text.trim();
      body['shuffle_questions'] = _shuffle ? 1 : 0;
      final list = <Map<String, dynamic>>[];
      for (var i = 0; i < _questions.length; i++) {
        final q = _questions[i];
        final n = i + 1;
        if (q.text.text.trim().isEmpty) {
          _fail('Question $n: enter the question');
          return null;
        }
        if (q.options.any((o) => o.text.trim().isEmpty)) {
          _fail('Question $n: fill every option');
          return null;
        }
        final marks = double.tryParse(q.marks.text.trim());
        if (marks == null || marks <= 0) {
          _fail('Question $n: marks must be more than 0');
          return null;
        }
        list.add({
          'question_text': q.text.text.trim(),
          'options': q.options.map((o) => o.text.trim()).toList(),
          'correct_option': q.correct,
          'marks': marks,
          'explanation': q.explanation.text.trim(),
        });
      }
      body['questions'] = list;
    } else {
      final total = double.tryParse(_totalMarks.text.trim());
      if (total == null || total <= 0) {
        _fail('Total marks must be more than 0');
        return null;
      }
      body['total_marks'] = total;
    }
    return body;
  }

  void _fail(String m) {
    setState(() => _error = m);
  }

  Future<void> _save() async {
    setState(() => _error = null);
    final body = _buildBody();
    if (body == null) return;

    setState(() => _saving = true);
    try {
      if (_editing) {
        await Api.put('/exams/$_id', body: body);
      } else {
        final res = await Api.post('/exams', body: body);
        _id = toInt(res['id']); // from here on, a retry updates this exam instead of creating a copy
      }

      if (_type == 'paper' && _paperFile != null) {
        try {
          await Api.upload('/exams/$_id/question-paper', fileField: 'question_paper', files: [_paperFile!]);
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _saving = false;
            _error = 'The exam was saved, but the question paper could not be uploaded: $e\nTap Save to try again.';
          });
          return;
        }
      }

      if (!mounted) return;
      showSnack(context, 'Exam saved');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  /* ---------------------------- UI ---------------------------- */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.examId == null ? 'New exam' : 'Edit exam')),
      body: _loading
          ? const LoadingView()
          : _loadError != null
              ? ErrorView(message: _loadError!, onRetry: _load)
              : _form(),
    );
  }

  Widget _form() {
    final isQuiz = _type == 'quiz';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        MessageBanner(_error),
        if (!_editing)
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'quiz', icon: Icon(Icons.quiz_outlined), label: Text('Online quiz')),
              ButtonSegment(value: 'paper', icon: Icon(Icons.description_outlined), label: Text('Paper exam')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          )
        else
          Text(isQuiz ? 'Online quiz (type cannot be changed)' : 'Paper exam (type cannot be changed)',
              style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 14),
        TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title *')),
        const SizedBox(height: 12),
        TextField(controller: _subject, decoration: const InputDecoration(labelText: 'Subject')),
        const SizedBox(height: 12),
        TextField(
          controller: _instructions,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Instructions', alignLabelWithHint: true),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (isQuiz) ...[
              Expanded(
                child: TextField(
                  controller: _duration,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Time limit (min)'),
                ),
              ),
            ] else
              Expanded(
                child: TextField(
                  controller: _totalMarks,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Total marks *'),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _passMarks,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Pass marks'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _dateTile('Opens at', _start, () => _pickDateTime(true), () => setState(() => _start = null)),
        const SizedBox(height: 8),
        _dateTile(isQuiz ? 'Closes at' : 'Due at', _end, () => _pickDateTime(false), () => setState(() => _end = null)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _status,
          decoration: const InputDecoration(labelText: 'Status'),
          items: const [
            DropdownMenuItem(value: 'published', child: Text('Published (students can see it)')),
            DropdownMenuItem(value: 'draft', child: Text('Draft (hidden from students)')),
          ],
          onChanged: (v) => setState(() => _status = v ?? 'published'),
        ),
        if (isQuiz)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _shuffle,
            onChanged: (v) => setState(() => _shuffle = v),
            title: const Text('Shuffle questions for each student'),
          ),
        const SizedBox(height: 8),
        const SectionTitle('Batches *'),
        if (_batches.isEmpty)
          Text('You have no batches to give an exam to.', style: TextStyle(color: Colors.grey.shade600)),
        for (final b in _batches)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            value: _batchIds.contains(toInt(b['id'])),
            onChanged: (v) => setState(() {
              final id = toInt(b['id']);
              v == true ? _batchIds.add(id) : _batchIds.remove(id);
            }),
            title: Text(str(b['batch_name'])),
            subtitle: Text(str(b['course_name'])),
          ),
        const SizedBox(height: 8),
        if (isQuiz) ..._quizEditor() else _paperEditor(),
        const SizedBox(height: 16),
        PrimaryButton(label: _editing ? 'Save changes' : 'Create exam', loading: _saving, onPressed: _save),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _dateTile(String label, DateTime? value, VoidCallback onTap, VoidCallback onClear) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: value == null
              ? const Icon(Icons.calendar_month_outlined)
              : IconButton(icon: const Icon(Icons.clear), onPressed: onClear),
        ),
        child: Text(value == null ? 'Not set' : formatDateTime(sqlDateTime(value))),
      ),
    );
  }

  Widget _paperEditor() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Question paper'),
          if (_existingPaperUrl.isNotEmpty && _paperFile == null)
            TextButton.icon(
              onPressed: () => openUrl(context, _existingPaperUrl),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('View current question paper'),
            ),
          if (_paperFile != null)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.attach_file),
              title: Text(_paperFile!.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _paperFile = null)),
            ),
          OutlinedButton.icon(
            onPressed: _saving ? null : _pickPaper,
            icon: const Icon(Icons.upload_file),
            label: Text(_existingPaperUrl.isEmpty && _paperFile == null ? 'Choose file (PDF or image)' : 'Replace file'),
          ),
        ],
      ),
    );
  }

  List<Widget> _quizEditor() {
    return [
      Row(
        children: [
          const Expanded(child: SectionTitle('Questions')),
          Text('Total: ${formatMarks(_quizTotal)} marks', style: TextStyle(color: Colors.grey.shade700)),
        ],
      ),
      for (var i = 0; i < _questions.length; i++) _questionCard(i),
      OutlinedButton.icon(
        onPressed: () => setState(() => _questions.add(_Question())),
        icon: const Icon(Icons.add),
        label: const Text('Add question'),
      ),
    ];
  }

  Widget _questionCard(int i) {
    final q = _questions[i];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Question ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimary)),
              const Spacer(),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: q.marks,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Marks', isDense: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (_questions.length > 1)
                IconButton(
                  tooltip: 'Remove question',
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade600),
                  onPressed: () => setState(() => _questions.removeAt(i).dispose()),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: q.text,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Question', alignLabelWithHint: true),
          ),
          const SizedBox(height: 8),
          Text('Options (tap the circle for the correct answer)',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          for (var k = 0; k < q.options.length; k++)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => q.correct = k),
                    icon: Icon(
                      q.correct == k ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: q.correct == k ? Colors.green.shade700 : Colors.grey,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: q.options[k],
                      decoration: InputDecoration(labelText: 'Option ${String.fromCharCode(65 + k)}', isDense: true),
                    ),
                  ),
                  if (q.options.length > 2)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() {
                        q.options.removeAt(k).dispose();
                        if (q.correct == k) {
                          q.correct = 0;
                        } else if (q.correct > k) {
                          q.correct--;
                        }
                      }),
                    ),
                ],
              ),
            ),
          if (q.options.length < 6)
            TextButton.icon(
              onPressed: () => setState(() => q.options.add(TextEditingController())),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add option'),
            ),
          const SizedBox(height: 4),
          TextField(
            controller: q.explanation,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Explanation (shown after the exam)', alignLabelWithHint: true),
          ),
        ],
      ),
    );
  }
}
