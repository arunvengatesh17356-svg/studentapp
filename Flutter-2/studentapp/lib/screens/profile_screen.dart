import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/navigation.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../widgets/common.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _current = TextEditingController();
  final _newPass = TextEditingController();

  bool _loading = true;
  String? _loadError;
  String _role = Session.role;

  bool _savingProfile = false;
  String? _profileOk;
  String? _profileErr;

  bool _savingPass = false;
  String? _passOk;
  String? _passErr;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _current.dispose();
    _newPass.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await Api.get('/profile');
      if (!mounted) return;
      final u = Map<String, dynamic>.from(res['user'] as Map);
      setState(() {
        _name.text = str(u['name']);
        _email.text = str(u['email']);
        _role = str(u['role'], Session.role);
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

  Future<void> _saveProfile() async {
    setState(() {
      _savingProfile = true;
      _profileOk = null;
      _profileErr = null;
    });
    try {
      final res = await Api.put('/profile', body: {'name': _name.text.trim(), 'email': _email.text.trim()});
      final u = Map<String, dynamic>.from(res['user'] as Map);
      await Session.updateUser({
        'id': toInt(u['id']),
        'name': u['name'],
        'email': u['email'],
        'role': u['role'],
      });
      if (!mounted) return;
      setState(() {
        _savingProfile = false;
        _profileOk = 'Profile updated';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _savingProfile = false;
        _profileErr = e.message;
      });
    }
  }

  Future<void> _changePassword() async {
    if (_newPass.text.length < 6) {
      setState(() {
        _passErr = 'New password must be at least 6 characters';
        _passOk = null;
      });
      return;
    }
    setState(() {
      _savingPass = true;
      _passOk = null;
      _passErr = null;
    });
    try {
      final res = await Api.put('/profile/password',
          body: {'current_password': _current.text, 'new_password': _newPass.text});
      if (!mounted) return;
      _current.clear();
      _newPass.clear();
      setState(() {
        _savingPass = false;
        _passOk = str(res['message'], 'Password updated');
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _savingPass = false;
        _passErr = e.message;
      });
    }
  }

  Future<void> _logout() async {
    final ok = await confirmDialog(context, 'Log out', 'Do you want to log out?', yes: 'Log out');
    if (ok) await performLogout();
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: kPrimary,
                child: Text(
                  _name.text.trim().isEmpty ? '?' : _name.text.trim()[0].toUpperCase(),
                  style: const TextStyle(fontSize: 30, color: Colors.white),
                ),
              ),
              const SizedBox(height: 8),
              StatusChip(_role),
              const SizedBox(height: 16),
            ],
          ),
        ),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Profile',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kPrimary)),
              const SizedBox(height: 12),
              MessageBanner(_profileErr),
              MessageBanner(_profileOk, error: false),
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 14),
              PrimaryButton(label: 'Save changes', onPressed: _saveProfile, loading: _savingProfile),
            ],
          ),
        ),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Change password',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kPrimary)),
              const SizedBox(height: 12),
              MessageBanner(_passErr),
              MessageBanner(_passOk, error: false),
              TextField(
                controller: _current,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current password'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newPass,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password (min 6 characters)'),
              ),
              const SizedBox(height: 14),
              PrimaryButton(label: 'Update password', onPressed: _changePassword, loading: _savingPass),
            ],
          ),
        ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout),
          label: const Text('Log out'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red.shade700,
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    );
  }
}
