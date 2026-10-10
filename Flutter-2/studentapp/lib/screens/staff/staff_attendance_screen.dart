import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../widgets/common.dart';

/// Staff: mark attendance for one subject on one date, or see per-student totals.
class StaffAttendanceScreen extends StatefulWidget {
  final int? initialAssignmentId;
  const StaffAttendanceScreen({super.key, this.initialAssignmentId});

  @override
  State<StaffAttendanceScreen> createState() => _StaffAttendanceScreenState();
}

class _StaffAttendanceScreenState extends State<StaffAttendanceScreen> {
  List<Map<String, dynamic>> _assignments = [];
  int? _assignmentId;
  DateTime _date = today();
  bool _summaryMode = false;

  bool _booting = true;
  String? _bootError;

  bool _loading = false;
  bool _saving = false;
  String? _error;
  String? _ok;

  List<Map<String, dynamic>> _students = [];
  final Map<int, String> _marks = {};
  List<Map<String, dynamic>> _summary = [];

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      final res = await Api.get('/staff/dashboard');
      if (!mounted) return;
      final list = asList(res['assignments']);
      setState(() {
        _assignments = list;
        _booting = false;
        _bootError = null;
        if (list.isNotEmpty) {
          final wanted = widget.initialAssignmentId;
          final found = wanted != null && list.any((a) => toInt(a['id']) == wanted);
          _assignmentId = found ? wanted : toInt(list.first['id']);
        }
      });
      if (_assignmentId != null) await _refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _booting = false;
        _bootError = e.message;
      });
    }
  }

  Future<void> _refresh() => _summaryMode ? _loadSummary() : _loadDay();

  Future<void> _loadDay() async {
    final id = _assignmentId;
    if (id == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _ok = null;
    });
    try {
      final res = await Api.get('/staff/attendance', query: {'assignment_id': id, 'date': ymd(_date)});
      if (!mounted) return;
      final students = asList(res['students']);
      final marks = <int, String>{};
      for (final s in students) {
        final st = s['status'];
        if (st is String && st.isNotEmpty) marks[toInt(s['id'])] = st;
      }
      setState(() {
        _students = students;
        _marks
          ..clear()
          ..addAll(marks);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _students = [];
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _loadSummary() async {
    final id = _assignmentId;
    if (id == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _ok = null;
    });
    try {
      final res = await Api.get('/staff/attendance/summary', query: {'assignment_id': id});
      if (!mounted) return;
      setState(() {
        _summary = asList(res['students']);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _summary = [];
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: today(), // the server does not allow future dates
    );
    if (picked == null) return;
    setState(() => _date = picked);
    _loadDay();
  }

  Future<void> _save() async {
    final id = _assignmentId;
    if (id == null) return;
    if (_marks.isEmpty) {
      setState(() {
        _error = 'Mark at least one student first';
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
      final res = await Api.post('/staff/attendance', body: {
        'assignment_id': id,
        'date': ymd(_date),
        'records': _marks.entries.map((e) => {'student_id': e.key, 'status': e.value}).toList(),
      });
      if (!mounted) return;
      setState(() {
        _saving = false;
        _ok = str(res['message'], 'Attendance saved');
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  void _markAllPresent() {
    setState(() {
      for (final s in _students) {
        _marks[toInt(s['id'])] = 'present';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_booting) return const LoadingView();
    if (_bootError != null) {
      return ErrorView(
        message: _bootError!,
        onRetry: () {
          setState(() {
            _booting = true;
            _bootError = null;
          });
          _boot();
        },
      );
    }
    if (_assignments.isEmpty) {
      return const EmptyView(icon: Icons.fact_check_outlined, text: 'No subjects are assigned to you yet.');
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            children: [
              DropdownButtonFormField<int>(
                value: _assignmentId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Subject / Batch'),
                items: [
                  for (final a in _assignments)
                    DropdownMenuItem<int>(
                      value: toInt(a['id']),
                      child: Text('${str(a['subject_name'])} — ${str(a['batch_name'])}',
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _assignmentId = v);
                  _refresh();
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: const <ButtonSegment<bool>>[
                        ButtonSegment<bool>(value: false, label: Text('Mark')),
                        ButtonSegment<bool>(value: true, label: Text('Summary')),
                      ],
                      selected: {_summaryMode},
                      onSelectionChanged: (s) {
                        setState(() => _summaryMode = s.first);
                        _refresh();
                      },
                    ),
                  ),
                  if (!_summaryMode) ...[
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(formatDate(ymd(_date))),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        Expanded(child: _loading ? const LoadingView() : (_summaryMode ? _summaryList() : _markList())),
        if (!_summaryMode && !_loading && _students.isNotEmpty)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: SafeArea(
              top: false,
              child: PrimaryButton(label: 'Save attendance (${_marks.length})', onPressed: _save, loading: _saving),
            ),
          ),
      ],
    );
  }

  Widget _markList() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        MessageBanner(_error),
        MessageBanner(_ok, error: false),
        if (_students.isEmpty && _error == null)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: EmptyView(icon: Icons.groups_outlined, text: 'No students have joined this batch yet.'),
          ),
        if (_students.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _markAllPresent,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Mark all present'),
            ),
          ),
        for (final s in _students) _studentTile(s),
      ],
    );
  }

  Widget _studentTile(Map<String, dynamic> s) {
    final id = toInt(s['id']);
    final mark = _marks[id];
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(str(s['name']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              if (s['on_leave'] == true) const StatusChip('on leave'),
            ],
          ),
          Text(str(s['email']), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              emptySelectionAllowed: true,
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(value: 'present', label: Text('Present')),
                ButtonSegment<String>(value: 'late', label: Text('Late')),
                ButtonSegment<String>(value: 'absent', label: Text('Absent')),
              ],
              selected: mark == null ? <String>{} : <String>{mark},
              onSelectionChanged: (sel) {
                setState(() {
                  if (sel.isEmpty) {
                    _marks.remove(id);
                  } else {
                    _marks[id] = sel.first;
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryList() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        MessageBanner(_error),
        if (_summary.isEmpty && _error == null)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: EmptyView(icon: Icons.groups_outlined, text: 'No students have joined this batch yet.'),
          ),
        for (final s in _summary) _summaryTile(s),
      ],
    );
  }

  Widget _summaryTile(Map<String, dynamic> s) {
    final percent = s['percent'] == null ? null : toInt(s['percent']);
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(str(s['name']), style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'Present ${toInt(s['present'])} · Late ${toInt(s['late'])} · Absent ${toInt(s['absent'])} · Total ${toInt(s['total'])}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            percent == null ? '—' : '$percent%',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: percent == null
                  ? Colors.grey
                  : percent >= 75
                      ? Colors.green.shade700
                      : percent >= 50
                          ? Colors.orange.shade800
                          : Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
