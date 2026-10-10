import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../widgets/common.dart';
import '../../widgets/data_loader.dart';
import 'course_detail_screen.dart';

class CoursesScreen extends StatefulWidget {
  /// Called after a successful purchase so the shell can jump to "My Courses".
  final VoidCallback onPurchased;
  const CoursesScreen({super.key, required this.onPurchased});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  String _query = '';

  Future<List<Map<String, dynamic>>> _load() async {
    final res = await Api.get('/courses');
    return asList(res['courses']);
  }

  Future<void> _open(Map<String, dynamic> course) async {
    final bought = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CourseDetailScreen(courseId: toInt(course['id']))),
    );
    if (bought == true) widget.onPurchased();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search courses',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: DataLoader<List<Map<String, dynamic>>>(
            load: _load,
            builder: (context, courses, reload) {
              final list = courses
                  .where((c) => str(c['course_name']).toLowerCase().contains(_query))
                  .toList();
              return RefreshIndicator(
                onRefresh: reload,
                child: list.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 80),
                          EmptyView(icon: Icons.menu_book_outlined, text: 'No courses available right now.'),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        itemBuilder: (context, i) => _CourseCard(course: list[i], onTap: () => _open(list[i])),
                      ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CourseCard extends StatelessWidget {
  final Map<String, dynamic> course;
  final VoidCallback onTap;
  const _CourseCard({required this.course, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final purchased = course['purchased'] == true;
    final batches = toInt(course['active_batches']);
    final duration = str(course['duration']);

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NetImage(url: course['image_url']?.toString()),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        str(course['course_name']),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kPrimary),
                      ),
                    ),
                    Text(formatPrice(course['price']),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  ],
                ),
                if (str(course['description']).isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    str(course['description']),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (duration.isNotEmpty)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(duration, style: TextStyle(color: Colors.grey.shade700)),
                      ]),
                    Text('$batches active batch${batches == 1 ? '' : 'es'}',
                        style: TextStyle(color: Colors.grey.shade700)),
                    if (purchased) const StatusChip('purchased'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
