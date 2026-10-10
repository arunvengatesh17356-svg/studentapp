import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../widgets/common.dart';
import '../../widgets/data_loader.dart';

class MyCoursesScreen extends StatelessWidget {
  const MyCoursesScreen({super.key});

  Future<List<Map<String, dynamic>>> _load() async {
    final res = await Api.get('/my-courses');
    return asList(res['courses']);
  }

  @override
  Widget build(BuildContext context) {
    return DataLoader<List<Map<String, dynamic>>>(
      load: _load,
      builder: (context, courses, reload) {
        return RefreshIndicator(
          onRefresh: reload,
          child: courses.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 80),
                    EmptyView(
                      icon: Icons.school_outlined,
                      text: "You haven't purchased any course yet.\nBrowse the Courses tab to get started.",
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: courses.length,
                  itemBuilder: (context, i) {
                    final c = courses[i];
                    final hasBatch = str(c['batch_name']).isNotEmpty;
                    return AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          NetImage(url: c['image_url']?.toString(), height: 120),
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(str(c['course_name']),
                                    style: const TextStyle(
                                        fontSize: 17, fontWeight: FontWeight.bold, color: kPrimary)),
                                const SizedBox(height: 6),
                                if (hasBatch) ...[
                                  Text('Batch: ${str(c['batch_name'])}',
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text('${formatDate(c['start_date'])} → ${formatDate(c['end_date'])}',
                                      style: TextStyle(color: Colors.grey.shade600)),
                                ] else
                                  Text('No batch selected', style: TextStyle(color: Colors.grey.shade600)),
                                const SizedBox(height: 6),
                                Text(
                                  'Paid ${formatPrice(c['amount'])} on ${formatDate(c['purchased_at'])}',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
