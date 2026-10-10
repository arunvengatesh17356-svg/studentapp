import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../widgets/common.dart';
import '../../widgets/data_loader.dart';

class StudentAttendanceScreen extends StatelessWidget {
  const StudentAttendanceScreen({super.key});

  Future<List<Map<String, dynamic>>> _load() async {
    final res = await Api.get('/my-attendance');
    return asList(res['batches']);
  }

  @override
  Widget build(BuildContext context) {
    return DataLoader<List<Map<String, dynamic>>>(
      load: _load,
      builder: (context, batches, reload) {
        return RefreshIndicator(
          onRefresh: reload,
          child: batches.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 80),
                    EmptyView(
                      icon: Icons.fact_check_outlined,
                      text: 'Attendance appears here once you join a batch.',
                    ),
                  ],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [for (final b in batches) ..._batchSection(context, b)],
                ),
        );
      },
    );
  }

  List<Widget> _batchSection(BuildContext context, Map<String, dynamic> b) {
    final subjects = asList(b['subjects']);
    final records = asList(b['records']);

    return [
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Text.rich(
          TextSpan(
            text: str(b['batch_name']),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kPrimary),
            children: [
              TextSpan(
                text: '  ·  ${str(b['course_name'])}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.normal, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
      if (subjects.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('No subjects assigned yet', style: TextStyle(color: Colors.grey.shade600)),
        ),
      for (final s in subjects) _subjectCard(s),
      if (records.isNotEmpty)
        AppCard(
          padding: EdgeInsets.zero,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: const Text('Recent days', style: TextStyle(fontWeight: FontWeight.w600)),
              children: [
                for (final r in records)
                  ListTile(
                    dense: true,
                    title: Text(str(r['subject_name'])),
                    subtitle: Text(formatDate(r['attendance_date'])),
                    trailing: StatusChip(str(r['status'])),
                  ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 12),
    ];
  }

  Widget _subjectCard(Map<String, dynamic> s) {
    final percent = s['percent'] == null ? null : toInt(s['percent']);
    final color = percent == null
        ? Colors.grey
        : percent >= 75
            ? Colors.green
            : percent >= 50
                ? Colors.orange
                : Colors.red;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(str(s['subject_name']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(str(s['staff_name']), style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
              ),
              Text(percent == null ? '—' : '$percent%',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color.shade700)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent == null ? 0 : percent / 100,
              minHeight: 8,
              color: color.shade600,
              backgroundColor: Colors.grey.shade200,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _count('Present', s['present'], Colors.green),
              _count('Late', s['late'], Colors.orange),
              _count('Absent', s['absent'], Colors.red),
              _count('Total', s['total'], Colors.blueGrey),
            ],
          ),
        ],
      ),
    );
  }

  Widget _count(String label, dynamic value, MaterialColor c) {
    return Column(
      children: [
        Text('${toInt(value)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: c.shade700)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}
