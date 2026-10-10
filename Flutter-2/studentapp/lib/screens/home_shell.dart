import 'package:flutter/material.dart';

import '../config.dart';
import '../core/navigation.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../widgets/common.dart';
import 'profile_screen.dart';
import 'shared/leave_inbox_screen.dart';
import 'shared/my_leaves_screen.dart';
import 'staff/staff_attendance_screen.dart';
import 'staff/staff_exams_screen.dart';
import 'staff/staff_dashboard_screen.dart';
import 'student/attendance_screen.dart';
import 'student/courses_screen.dart';
import 'student/exams_screen.dart';
import 'student/my_courses_screen.dart';

class _TabDef {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget Function() build;
  const _TabDef(this.label, this.icon, this.selectedIcon, this.build);
}

/// Bottom-navigation shell. The tabs depend on the logged-in role.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  late final List<_TabDef> _tabs;

  @override
  void initState() {
    super.initState();
    final role = Session.role;
    if (role == 'student') {
      _tabs = [
        _TabDef('Courses', Icons.menu_book_outlined, Icons.menu_book,
            () => CoursesScreen(onPurchased: () => setState(() => _index = 1))),
        _TabDef('My Courses', Icons.school_outlined, Icons.school, () => const MyCoursesScreen()),
        _TabDef('Exams', Icons.quiz_outlined, Icons.quiz, () => const StudentExamsScreen()),
        _TabDef('Attendance', Icons.fact_check_outlined, Icons.fact_check,
            () => const StudentAttendanceScreen()),
        _TabDef('Leave', Icons.event_busy_outlined, Icons.event_busy, () => const MyLeavesScreen()),
        _TabDef('Profile', Icons.person_outline, Icons.person, () => const ProfileScreen()),
      ];
    } else if (role == 'staff') {
      _tabs = [
        _TabDef('Dashboard', Icons.dashboard_outlined, Icons.dashboard, () => const StaffDashboardScreen()),
        _TabDef('Attendance', Icons.fact_check_outlined, Icons.fact_check,
            () => const StaffAttendanceScreen()),
        _TabDef('Exams', Icons.quiz_outlined, Icons.quiz, () => const StaffExamsScreen()),
        _TabDef('Requests', Icons.inbox_outlined, Icons.inbox, () => const LeaveInboxScreen()),
        _TabDef('My Leave', Icons.event_busy_outlined, Icons.event_busy, () => const MyLeavesScreen()),
        _TabDef('Profile', Icons.person_outline, Icons.person, () => const ProfileScreen()),
      ];
    } else {
      _tabs = [];
    }
  }

  Future<void> _logout() async {
    final ok = await confirmDialog(context, 'Log out', 'Do you want to log out?', yes: 'Log out');
    if (ok) await performLogout();
  }

  @override
  Widget build(BuildContext context) {
    if (_tabs.isEmpty) return _UnsupportedRole(onLogout: _logout);

    return Scaffold(
      appBar: AppBar(
        // the hamburger (burger) icon is added automatically because the Scaffold has a drawer
        title: Text(_tabs[_index].label),
        actions: [
          IconButton(tooltip: 'Log out', icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      drawer: _buildDrawer(),
      body: KeyedSubtree(key: ValueKey(_index), child: _tabs[_index].build()),
    );
  }

  Widget _buildDrawer() {
    final initial = Session.name.isEmpty ? '?' : Session.name[0].toUpperCase();
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: kPrimary),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(initial,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: kPrimary)),
            ),
            accountName: Text(Session.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: Text('${Session.email}  ·  ${capitalize(Session.role)}'),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  ListTile(
                    leading: Icon(i == _index ? _tabs[i].selectedIcon : _tabs[i].icon,
                        color: i == _index ? kPrimary : null),
                    title: Text(_tabs[i].label,
                        style: TextStyle(
                            fontWeight: i == _index ? FontWeight.bold : FontWeight.normal,
                            color: i == _index ? kPrimary : null)),
                    selected: i == _index,
                    selectedTileColor: Colors.blue.shade50,
                    onTap: () {
                      Navigator.pop(context); // close the drawer
                      setState(() => _index = i);
                    },
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Log out'),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The mobile app covers students and staff. Admin work stays on the web panel.
class _UnsupportedRole extends StatelessWidget {
  final VoidCallback onLogout;
  const _UnsupportedRole({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppConfig.appName)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.admin_panel_settings_outlined, size: 64, color: Colors.grey.shade500),
              const SizedBox(height: 16),
              Text(
                'Signed in as ${Session.name} (${Session.role.isEmpty ? 'unknown' : Session.role}).\n\n'
                'This app is for students and staff. Please use the web panel for admin tasks.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(onPressed: onLogout, icon: const Icon(Icons.logout), label: const Text('Log out')),
            ],
          ),
        ),
      ),
    );
  }
}
