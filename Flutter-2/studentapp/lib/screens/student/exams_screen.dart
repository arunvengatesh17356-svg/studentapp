import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../widgets/common.dart';
import '../../widgets/data_loader.dart';
import 'paper_exam_screen.dart';
import 'quiz_exam_screen.dart';

/// Student: every exam given to a batch I have paid for.
class StudentExamsScreen extends StatelessWidget {
  const StudentExamsScreen({super.key});

  Future<List<Map<String, dynamic>>> _load() async {
    final res = await Api.get('/my-exams');
    return asList(res['exams']);
  }

  @override
  Widget build(BuildContext context) {
    return DataLoader<List<Map<String, dynamic>>>(
      load: _load,
      builder: (context, exams, reload) {
        return RefreshIndicator(
          onRefresh: reload,
          child: exams.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 80),
                    EmptyView(icon: Icons.quiz_outlined, text: 'No exams have been assigned to you yet.'),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: exams.length,
                  itemBuilder: (context, i) => _ExamCard(exam: exams[i], onChanged: reload),
                ),
        );
      },
    );
  }
}

class _ExamCard extends StatelessWidget {
  final Map<String, dynamic> exam;
  final Future<void> Function() onChanged;
  const _ExamCard({required this.exam, required this.onChanged});

  bool get _isQuiz => str(exam['type']) == 'quiz';
  String get _status => str(exam['my_status'], 'pending');
  bool get _isOpen => exam['is_open'] == true;
  bool get _notYet => exam['not_open_yet'] == true;

  /// Marks stay hidden until the teacher publishes them, so "graded" reads as "submitted".
  String get _label => _status == 'graded' ? 'submitted' : _status;

  String? get _buttonLabel {
    if (_status == 'published') return 'View result';
    if (_isQuiz) {
      if (_status == 'submitted') return 'View';
      if (!_isOpen && _status != 'started') return null;
      return _status == 'started' ? 'Resume' : 'Start';
    }
    if (_status == 'pending' && !_isOpen) return null;
    return _status == 'pending' ? 'Open' : 'View';
  }

  Future<void> _open(BuildContext context) async {
    final id = toInt(exam['id']);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _isQuiz ? QuizExamScreen(examId: id) : PaperExamScreen(examId: id),
    ));
    await onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final btn = _buttonLabel;
    final marks = exam['marks'];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(str(exam['title']),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kPrimary)),
              ),
              const SizedBox(width: 8),
              StatusChip(str(exam['type'])),
              const SizedBox(width: 6),
              StatusChip(_label),
            ],
          ),
          const SizedBox(height: 4),
          Text('${str(exam['subject'], '—')} · by ${str(exam['created_by_name'])}',
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 10),
          if (_isQuiz)
            Text(
              '${toInt(exam['question_count'])} questions'
              '${exam['duration_minutes'] != null ? ' · ${toInt(exam['duration_minutes'])} min' : ''}',
            ),
          Text('${formatMarks(exam['total_marks'])} marks'),
          if (str(exam['end_at']).isNotEmpty)
            Text('${_isQuiz ? 'Closes' : 'Due'}: ${formatDateTime(exam['end_at'])}'),
          if (_status == 'published' && marks != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Your marks: ${formatMarks(marks)} / ${formatMarks(exam['total_marks'])}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700)),
            ),
          const SizedBox(height: 12),
          if (btn != null)
            FilledButton(onPressed: () => _open(context), child: Text(btn))
          else
            Text(_notYet ? 'Not open yet' : 'Closed', style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
