import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../widgets/common.dart';

/// Apply for leave + see my requests.
/// Student -> picks a batch; goes to that batch's staff and the admin.
/// Staff   -> goes to the admin.
class MyLeavesScreen extends StatefulWidget {
  const MyLeavesScreen({super.key});

  @override
  State<MyLeavesScreen> createState() => _MyLeavesScreenState();
}

class _MyLeavesScreenState extends State<MyLeavesScreen> {
  final bool _isStudent = Session.role == 'student';

  List<Map<String, dynamic>> _leaves = [];
  List<Map<String, dynamic>> _batches = [];
  bool _loading = true;
  String? _loadError;

  int? _batchId;
  DateTime _from = today();
  DateTime _to = today();
  final _reason = TextEditingController();
  bool _saving = false;
  String? _error;
  String? _ok;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await Api.get('/leaves/mine');
      var batches = _batches;
      if (_isStudent) {
        final b = await Api.get('/my-batches');
        batches = asList(b['batches']);
      }
      if (!mounted) return;
      setState(() {
        _leaves = asList(res['leaves']);
        _batches = batches;
        if (_batchId == null && batches.isNotEmpty) _batchId = toInt(batches.first['id']);
        _loading = false;
        _loadError = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.message;
      });
    }
  }

  Future<void> _pick(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: isFrom ? DateTime(2020) : _from,
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (_reason.text.trim().isEmpty) {
      setState(() {
        _error = 'Please give a reason';
        _ok = null;
      });
      return;
    }
    if (_isStudent && _batchId == null) {
      setState(() {
        _error = 'Please choose a batch';
        _ok = null;
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _ok = null;
    });
    try {
      final res = await Api.post('/leaves', body: {
        if (_isStudent) 'batch_id': _batchId,
        'from_date': ymd(_from),
        'to_date': ymd(_to),
        'reason': _reason.text.trim(),
      });
      if (!mounted) return;
      _reason.clear();
      setState(() {
        _saving = false;
        _ok = str(res['message'], 'Leave request sent');
      });
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  Future<void> _cancel(Map<String, dynamic> leave) async {
    final yes = await confirmDialog(context, 'Cancel request', 'Cancel this leave request?');
    if (!yes) return;
    try {
      await Api.delete('/leaves/${toInt(leave['id'])}');
      if (!mounted) return;
      showSnack(context, 'Leave request cancelled');
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    if (_loadError != null) {
      return ErrorView(
        message: _loadError!,
        onRetry: () {
          setState(() {
            _loading = true;
            _loadError = null;
          });
          _load();
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _form(),
          const SectionTitle('My requests'),
          if (_leaves.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('No leave requests yet', style: TextStyle(color: Colors.grey.shade600)),
            ),
          for (final l in _leaves) _leaveCard(l),
        ],
      ),
    );
  }

  Widget _form() {
    final blocked = _isStudent && _batches.isEmpty;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Apply for leave',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kPrimary)),
          const SizedBox(height: 4),
          Text(
            _isStudent
                ? 'Your request goes to the staff handling your batch and to the admin.'
                : 'Your request goes to the admin.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 14),
          if (blocked)
            Text(
              'You can apply for leave after you buy a course and join a batch '
              '(payment must be completed).',
              style: TextStyle(color: Colors.grey.shade700),
            )
          else ...[
            MessageBanner(_error),
            MessageBanner(_ok, error: false),
            if (_isStudent) ...[
              DropdownButtonFormField<int>(
                value: _batchId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Batch'),
                items: [
                  for (final b in _batches)
                    DropdownMenuItem<int>(
                      value: toInt(b['id']),
                      child: Text('${str(b['batch_name'])} — ${str(b['course_name'])}',
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _batchId = v),
              ),
              const SizedBox(height: 10),
              _sendTo(),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(child: _dateButton('From', _from, () => _pick(true))),
                const SizedBox(width: 10),
                Expanded(child: _dateButton('To', _to, () => _pick(false))),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
            const SizedBox(height: 8),
            PrimaryButton(label: 'Send request', onPressed: _submit, loading: _saving),
          ],
        ],
      ),
    );
  }

  Widget _sendTo() {
    final batch = _batches.where((b) => toInt(b['id']) == _batchId).toList();
    if (batch.isEmpty) return const SizedBox.shrink();
    final staff = asList(batch.first['staff']);
    final noStaff = staff.isEmpty;
    final c = noStaff ? Colors.amber : Colors.blue;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: c.shade50, borderRadius: BorderRadius.circular(8)),
      child: Text(
        noStaff
            ? 'No staff is assigned to this batch yet, so this request will go to the admin only.'
            : 'Will be sent to: ${staff.map((s) => '${str(s['name'])} (${str(s['subject_name'])})').join(', ')} and the admin.',
        style: TextStyle(fontSize: 13, color: c.shade900),
      ),
    );
  }

  Widget _dateButton(String label, DateTime value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_today, size: 18)),
        child: Text(formatDate(ymd(value))),
      ),
    );
  }

  Widget _leaveCard(Map<String, dynamic> l) {
    final sameDay = str(l['from_date']) == str(l['to_date']);
    final status = str(l['status']);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  sameDay
                      ? formatDate(l['from_date'])
                      : '${formatDate(l['from_date'])} → ${formatDate(l['to_date'])}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              StatusChip(status),
            ],
          ),
          if (str(l['batch_name']).isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(str(l['batch_name']), style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ],
          const SizedBox(height: 6),
          Text(str(l['reason'])),
          if (str(l['reviewed_by_name']).isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Reviewed by ${str(l['reviewed_by_name'])}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
          if (str(l['review_note']).isNotEmpty)
            Text('“${str(l['review_note'])}”', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          if (status == 'pending')
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => _cancel(l), child: const Text('Cancel request')),
            ),
        ],
      ),
    );
  }
}
