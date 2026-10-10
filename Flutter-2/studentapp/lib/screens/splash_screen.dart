import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/navigation.dart';
import '../core/session.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await Session.load();
    if (Session.token == null) {
      goToLogin();
      return;
    }
    try {
      final res = await Api.get('/user');
      if (res['user'] is Map) {
        await Session.updateUser(Map<String, dynamic>.from(res['user'] as Map));
      }
      goToHome();
    } on ApiException catch (e) {
      if (e.statusCode == 401) return; // Api already sent the user to the login screen
      if (Session.user != null) {
        goToHome(); // offline: continue with the saved user
      } else {
        goToLogin();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/logo.png',
              height: 90,
              errorBuilder: (context, error, stack) => const Icon(Icons.school, size: 80),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
