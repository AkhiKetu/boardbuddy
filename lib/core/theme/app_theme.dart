
import 'package:flutter/material.dart';

class AppTheme {
  // Main app colors
  static const Color primary = Color(0xFF6759E8);
  static const Color background = Color(0xFFF7F8FC);
  static const Color textColor = Color(0xFF25283C);

  // Light theme for the application
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,

      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
      ),

      scaffoldBackgroundColor: background,

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: textColor,
        centerTitle: false,
        elevation: 0,
      ),
    );
  }
}
