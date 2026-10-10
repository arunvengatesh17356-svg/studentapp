import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../widgets/common.dart';
import '../../widgets/data_loader.dart';
import 'exam_form_screen.dart';
import 'exam_results_screen.dart';

/// Staff: exams I created or that were given to a batch I teach.
class StaffExamsScreen extends StatefulWidget {
  const StaffExamsScreen({super.key});

  @override
  State<StaffExamsScreen> createState() => _StaffExamsScreenState();
}

class _StaffExamsScreenState extends State<StaffExamsScreen> {
  int _reloadKey = 0;

  Future<List<Map<String, dynamic>>> _load() async {
    final res = await Api.get('/exams');
    return asList(res['exams']);
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(() => _reloadKey++);
  }

  Future<void> _delete(Map<String, dynamic> x) async {
    final ok = await confirmDialog(
      context,
      'Delete exam',
      'Delete "${str(x['title'])}"? All student submissions for it will be deleted too.',
      yes: 'Delete',
    );
    if (!ok) return;
    try {
      await Api.delete('/exams/${x['id']}');
      if (!mounted) return;
      showSnack(context, 'Exam deleted');
      setState(() => _reloadKey++);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = toInt(Session.user?['id']);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _push(const ExamFormScreen()),
        icon: const Icon(Icons.add),
        label: const Text('New exam'),
      ),
      body: DataLoader<List<Map<String, dynamic>>>(
        key: ValueKey(_reloadKey),
        load: _load,
        builder: (context, exams, reload) {
          return RefreshIndicator(
            onRefresh: reload,
            child: exams.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 80),
                      EmptyView(
                          icon: Icons.quiz_outlined,
                          text: 'No exams yet.\nTap "New exam" to create an online quiz or a paper exam.'),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                    itemCount: exams.length,
                    itemBuilder: (context, i) {
                      final x = exams[i];
                      final mine = toInt(x['created_by']) == myId;
                      final isPaper = str(x['type']) == 'paper';
                      return AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(str(x['title']),
                                      style: const TextStyle(
                                          fontSize: 17, fontWeight: FontWeight.bold, color: kPrimary)),
                                ),
                                const SizedBox(width: 8),
                                StatusChip(str(x['type'])),
                                const SizedBox(width: 6),
                                StatusChip(str(x['status'])),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(str(x['subject'], '—'), style: TextStyle(color: Colors.grey.shade600)),
                            const SizedBox(height: 8),
                            Text('Batches: ${str(x['batch_names'], '—')}'),
                            Text('${formatMarks(x['total_marks'])} marks · '
                                '${toInt(x['submitted_count'])} / ${toInt(x['assigned_count'])} submitted'),
                            if (str(x['start_at']).isNotEmpty || str(x['end_at']).isNotEmpty)
                              Text('${formatDateTime(x['start_at'])} → ${formatDateTime(x['end_at'])}',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: () => _push(ExamResultsScreen(examId: toInt(x['id']))),
                                  icon: Icon(isPaper ? Icons.rate_review_outlined : Icons.bar_chart),
                                  label: Text(isPaper ? 'Evaluate' : 'Results'),
                                ),
                                if (mine) ...[
                                  OutlinedButton.icon(
                                    onPressed: () => _push(ExamFormScreen(examId: toInt(x['id']))),
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('Edit'),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _delete(x),
                                    style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('Delete'),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}
