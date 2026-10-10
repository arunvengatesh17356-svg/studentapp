import 'package:flutter/foundation.dart';

class AppConfig {
  static const String appName = 'TAF IAS Academy';

  static const String _fromEnv = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_fromEnv.isNotEmpty) return _fromEnv; // --dart-define=API_BASE_URL=...
    if (kIsWeb) return 'http://localhost/App/backend/public/api'; // Chrome
    return 'http://10.0.2.2/App/backend/public/api'; // Android emulator
  }
}