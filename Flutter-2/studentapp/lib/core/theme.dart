import 'package:flutter/material.dart';

const Color kPrimary = Color(0xFF1E3A8A);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: kPrimary).copyWith(primary: kPrimary);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF3F4F6),
    appBarTheme: const AppBarTheme(
      backgroundColor: kPrimary,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
