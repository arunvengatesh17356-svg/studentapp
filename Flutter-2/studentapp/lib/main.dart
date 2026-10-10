import 'package:flutter/material.dart';

import 'config.dart';
import 'core/api_client.dart';
import 'core/navigation.dart';
import 'core/theme.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // If the server says the token is no longer valid, go back to login.
  Api.onUnauthorized = goToLogin;
  runApp(const StudentApp());
}

class StudentApp extends StatelessWidget {
  const StudentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: buildTheme(),
      home: const SplashScreen(),
    );
  }
}
