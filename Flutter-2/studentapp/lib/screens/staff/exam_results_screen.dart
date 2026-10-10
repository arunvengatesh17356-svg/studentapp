import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../widgets/common.dart';
import '../../widgets/data_loader.dart';

/// Staff: results of one exam. Quizzes are marked automatically; paper answer sheets are marked here.
class ExamResultsScreen extends StatefulWidget {
  final int examId;
  const ExamResultsScreen({super.key, required this.examId});

  @override
  State<ExamResultsScreen> createState() => _ExamResultsScreenState();
}

class _ExamResultsScreenState extends State<ExamResultsScreen> {
  int _reloadKey = 0;

  Future<Map<String, dynamic>> _load() => Api.get('/exams/${widget.examId}/results');

  void _refresh() => setState(() => _reloadKey++);

  Future<void> _publishAll(int count) async {
    final ok = await confirmDialog(context, 'Publish results', 'Send results to $count student(s)?', yes: 'Publish');
    if (!ok) return;
    try {
      final res = await Api.post('/exams/${widget.examId}/publish-results');
      if (!mounted) return;
      showSnack(context, str(res['message'], 'Results published'));
      _refresh();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _grade(Map<String, dynamic> exam, Map<String, dynamic> row) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _GradeSheet(examId: widget.examId, exam: exam, row: row),
    );
    if (saved == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exam results')),
      body: DataLoader<Map<String, dynamic>>(
        key: ValueKey(_reloadKey),
        load: _load,
        builder: (context, data, reload) {
          final exam = Map<String, dynamic>.from(data['exam'] as Map);
          final rows = asList(data['rows']);
          final isPaper = str(exam['type']) == 'paper';
          final total = toDouble(exam['total_marks']);
          final passMarks = exam['pass_marks'] == null ? null : toDouble(exam['pass_marks']);
          final done = rows.where((r) => str(r['status']) != 'pending').length;
          final scored = rows.where((r) => r['marks'] != null).map((r) => toDouble(r['marks'])).toList();
          final avg = scored.isEmpty ? '—' : (scored.reduce((a, b) => a + b) / scored.length).toStringAsFixed(1);
          final top = scored.isEmpty ? '—' : formatMarks(scored.reduce((a, b) => a > b ? a : b));
          final toMark = rows.where((r) => str(r['status']) == 'submitted').length;
          final toPublish = rows.where((r) => str(r['status']) == 'graded').length;

          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Text(str(exam['title']),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kPrimary)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _stat('Assigned', '${rows.length}')),
                  const SizedBox(width: 10),
                  Expanded(child: _stat(isPaper ? 'Received' : 'Attempted', '$done')),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _stat('Average', avg)),
                  const SizedBox(width: 10),
                  Expanded(child: _stat('Highest', top)),
                ]),
                const SizedBox(height: 14),
                if (isPaper && toMark > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('$toMark answer sheet(s) waiting to be marked',
                        style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w600)),
                  ),
                if (isPaper && toPublish > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FilledButton.icon(
                      onPressed: () => _publishAll(toPublish),
                      icon: const Icon(Icons.send_outlined),
                      label: Text('Publish $toPublish marked result(s)'),
                    ),
                  ),
                if (rows.isEmpty)
                  const EmptyView(icon: Icons.groups_outlined, text: 'No students in the selected batches yet.')
                else
                  for (final r in rows) _studentCard(exam, r, isPaper, total, passMarks),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _stat(String label, String value) => AppCard(
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kPrimary)),
            Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );

  Widget _studentCard(Map<String, dynamic> exam, Map<String, dynamic> r, bool isPaper, double total, double? pass) {
    final status = str(r['status'], 'pending');
    final hasMarks = r['marks'] != null;
    final marks = toDouble(r['marks']);
    final canGrade = isPaper && status != 'pending' && status != 'started';
    return AppCard(
      onTap: canGrade ? () => _grade(exam, r) : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(str(r['student_name']), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                Text(str(r['batch_name']), style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                if (str(r['submitted_at']).isNotEmpty)
                  Text('Submitted ${formatDateTime(r['submitted_at'])}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusChip(status),
              if (hasMarks) ...[
                const SizedBox(height: 4),
                Text('${formatMarks(marks)} / ${formatMarks(total)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                if (pass != null)
                  Text(marks >= pass ? 'Pass' : 'Fail',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: marks >= pass ? Colors.green.shade700 : Colors.red.shade700)),
              ],
              if (canGrade)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(status == 'submitted' ? 'Tap to mark' : 'Tap to edit',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade700)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet: view the student's sheets, enter marks + remarks, save or send to the student.
class _GradeSheet extends StatefulWidget {
  final int examId;
  final Map<String, dynamic> exam;
  final Map<String, dynamic> row;
  const _GradeSheet({required this.examId, required this.exam, required this.row});

  @override
  State<_GradeSheet> createState() => _GradeSheetState();
}

class _GradeSheetState extends State<_GradeSheet> {
  late final TextEditingController _marks;
  late final TextEditingController _remarks;
  bool _publish = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final m = widget.row['marks'];
    _marks = TextEditingController(text: m == null ? '' : formatMarks(m));
    _remarks = TextEditingController(text: str(widget.row['remarks']));
  }

  @override
  void dispose() {
    _marks.dispose();
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final total = toDouble(widget.exam['total_marks']);
    final m = double.tryParse(_marks.text.trim());
    if (m == null || m < 0 || m > total) {
      setState(() => _error = 'Marks must be between 0 and ${formatMarks(total)}');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final res = await Api.put(
        '/exams/${widget.examId}/attempts/${widget.row['attempt_id']}/grade',
        body: {'marks': m, 'remarks': _remarks.text.trim(), 'publish': _publish ? 1 : 0},
      );
      if (!mounted) return;
      showSnack(context, str(res['message'], 'Saved'));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final files = asList(widget.row['files']);
    final total = toDouble(widget.exam['total_marks']);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(str(widget.row['student_name']),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kPrimary)),
            const SizedBox(height: 10),
            const SectionTitle('Answer sheets'),
            if (files.isEmpty) Text('No files', style: TextStyle(color: Colors.grey.shade600)),
            for (final f in files)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(str(f['name']).toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf : Icons.image_outlined),
                title: Text(str(f['name'], 'Answer sheet'), maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => openUrl(context, str(f['url'])),
              ),
            const SizedBox(height: 10),
            MessageBanner(_error),
            TextField(
              controller: _marks,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Marks (out of ${formatMarks(total)})'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _remarks,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(labelText: 'Remarks (optional)'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _publish,
              onChanged: (v) => setState(() => _publish = v),
              title: const Text('Send result to the student now'),
              subtitle: const Text('If off, marks are saved but stay hidden from the student.'),
            ),
            const SizedBox(height: 8),
            PrimaryButton(label: 'Save', loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
