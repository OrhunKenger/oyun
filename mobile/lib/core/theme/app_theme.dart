import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF1A1A2E);
  static const Color secondary = Color(0xFF16213E);
  static const Color accent = Color(0xFFE94560);
  static const Color gold = Color(0xFFFFD700);
  static const Color wood = Color(0xFF8B4513);
  static const Color stone = Color(0xFF708090);
  static const Color iron = Color(0xFF708090);
  static const Color pixelBorder = Color(0xFF0F3460);

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: primary,
        primaryColor: accent,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          secondary: Color(0xFF0F3460),
          surface: secondary,
        ),
        fontFamily: 'monospace',
      );
}
