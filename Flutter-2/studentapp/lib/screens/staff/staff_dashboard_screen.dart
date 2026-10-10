import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../widgets/common.dart';
import '../../widgets/data_loader.dart';
import 'staff_attendance_screen.dart';

class StaffDashboardScreen extends StatelessWidget {
  const StaffDashboardScreen({super.key});

  Future<Map<String, dynamic>> _load() => Api.get('/staff/dashboard');

  @override
  Widget build(BuildContext context) {
    return DataLoader<Map<String, dynamic>>(
      load: _load,
      builder: (context, data, reload) {
        final summary = data['summary'] is Map ? Map<String, dynamic>.from(data['summary'] as Map) : <String, dynamic>{};
        final assignments = asList(data['assignments']);

        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Text('Welcome, ${Session.name}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kPrimary)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _stat('Batches', summary['batches'], Icons.groups_outlined)),
                  const SizedBox(width: 10),
                  Expanded(child: _stat('Subjects', summary['subjects'], Icons.menu_book_outlined)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _stat('Students', summary['students'], Icons.school_outlined)),
                  const SizedBox(width: 10),
                  Expanded(child: _stat('Pending leaves', summary['pending_leaves'], Icons.event_busy_outlined)),
                ],
              ),
              const SizedBox(height: 18),
              const SectionTitle('My subjects'),
              if (assignments.isEmpty)
                Text('No subjects are assigned to you yet.', style: TextStyle(color: Colors.grey.shade600)),
              for (final a in assignments) _assignmentCard(context, a),
            ],
          ),
        );
      },
    );
  }

  Widget _stat(String label, dynamic value, IconData icon) {
    return AppCard(
      margin: EdgeInsets.zero,
      child: Row(
        children: [
          Icon(icon, color: kPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${toInt(value)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _assignmentCard(BuildContext context, Map<String, dynamic> a) {
    return AppCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Mark attendance')),
              body: StaffAttendanceScreen(initialAssignmentId: toInt(a['id'])),
            ),
          ),
        );
      },
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(str(a['subject_name']),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kPrimary)),
                const SizedBox(height: 2),
                Text('${str(a['batch_name'])} · ${str(a['course_name'])}', style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 2),
                Text('${formatDate(a['start_date'])} → ${formatDate(a['end_date'])}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    StatusChip(str(a['batch_status'])),
                    const SizedBox(width: 10),
                    Text('${toInt(a['students'])} students', style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
