import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the login token + user on the device.
class Session {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  static String? token;
  static Map<String, dynamic>? user;

  static String get role => (user?['role'] ?? '').toString();
  static String get name => (user?['name'] ?? '').toString();
  static String get email => (user?['email'] ?? '').toString();

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString(_tokenKey);
    final raw = p.getString(_userKey);
    if (raw != null) {
      try {
        user = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (_) {
        user = null;
      }
    }
  }

  static Future<void> save(String newToken, Map<String, dynamic> newUser) async {
    token = newToken;
    user = newUser;
    final p = await SharedPreferences.getInstance();
    await p.setString(_tokenKey, newToken);
    await p.setString(_userKey, jsonEncode(newUser));
  }

  static Future<void> updateUser(Map<String, dynamic> newUser) async {
    user = newUser;
    final p = await SharedPreferences.getInstance();
    await p.setString(_userKey, jsonEncode(newUser));
  }

  static Future<void> clear() async {
    token = null;
    user = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_tokenKey);
    await p.remove(_userKey);
  }
}
