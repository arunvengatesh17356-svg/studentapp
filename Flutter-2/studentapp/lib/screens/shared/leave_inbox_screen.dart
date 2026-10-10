import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../widgets/common.dart';

/// Staff: student leave requests for the batches they handle. Approve / reject here.
class LeaveInboxScreen extends StatefulWidget {
  const LeaveInboxScreen({super.key});

  @override
  State<LeaveInboxScreen> createState() => _LeaveInboxScreenState();
}

class _LeaveInboxScreenState extends State<LeaveInboxScreen> {
  static const _filters = ['pending', 'approved', 'rejected', 'cancelled', 'all'];

  String _status = 'pending';
  List<Map<String, dynamic>> _leaves = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Api.get('/leaves/inbox', query: {'status': _status == 'all' ? '' : _status});
      if (!mounted) return;
      setState(() {
        _leaves = asList(res['leaves']);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _review(Map<String, dynamic> leave, String decision) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _NoteDialog(approve: decision == 'approved'),
    );
    if (note == null) return; // cancelled
    try {
      final res = await Api.put('/leaves/${toInt(leave['id'])}/review', body: {'status': decision, 'note': note});
      if (!mounted) return;
      showSnack(context, str(res['message'], 'Done'));
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (final f in _filters)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(capitalize(f)),
                    selected: _status == f,
                    onSelected: (_) {
                      setState(() => _status = f);
                      _load();
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: _content()),
      ],
    );
  }

  Widget _content() {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    return RefreshIndicator(
      onRefresh: _load,
      child: _leaves.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 80),
                EmptyView(icon: Icons.inbox_outlined, text: 'No leave requests here.'),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: _leaves.length,
              itemBuilder: (context, i) => _card(_leaves[i]),
            ),
    );
  }

  Widget _card(Map<String, dynamic> l) {
    final status = str(l['status']);
    final sameDay = str(l['from_date']) == str(l['to_date']);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(str(l['requester_name']),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kPrimary)),
              ),
              StatusChip(status),
            ],
          ),
          Text(str(l['requester_email']), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          const SizedBox(height: 8),
          if (str(l['batch_name']).isNotEmpty)
            Text('${str(l['batch_name'])} · ${str(l['course_name'])}', style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            sameDay
                ? formatDate(l['from_date'])
                : '${formatDate(l['from_date'])} → ${formatDate(l['to_date'])}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(str(l['reason'])),
          if (str(l['reviewed_by_name']).isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Reviewed by ${str(l['reviewed_by_name'])}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
          if (str(l['review_note']).isNotEmpty)
            Text('“${str(l['review_note'])}”', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          if (status == 'pending') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _review(l, 'rejected'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _review(l, 'approved'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _NoteDialog extends StatefulWidget {
  final bool approve;
  const _NoteDialog({required this.approve});

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.approve ? 'Approve leave' : 'Reject leave'),
      content: TextField(
        controller: _note,
        maxLines: 3,
        maxLength: 500,
        decoration: const InputDecoration(labelText: 'Note (optional)'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _note.text.trim()),
          child: Text(widget.approve ? 'Approve' : 'Reject'),
        ),
      ],
    );
  }
}
