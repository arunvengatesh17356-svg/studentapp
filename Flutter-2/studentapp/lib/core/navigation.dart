import 'package:flutter/material.dart';

import '../screens/home_shell.dart';
import '../screens/login_screen.dart';
import 'api_client.dart';
import 'session.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void goToLogin() {
  navigatorKey.currentState?.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (route) => false,
  );
}

void goToHome() {
  navigatorKey.currentState?.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const HomeShell()),
    (route) => false,
  );
}

Future<void> performLogout() async {
  try {
    await Api.post('/logout');
  } catch (_) {
    // even if the server call fails, log out on this device
  }
  await Session.clear();
  goToLogin();
}
