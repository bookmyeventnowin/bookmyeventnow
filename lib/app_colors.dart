import 'package:flutter/material.dart';

/// Shared brand palette, reused across pages for a consistent
/// Urban-Company-style look: purple accents on a warm off-white
/// background with clean white cards.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF5A35F6);
  static const Color primaryDark = Color(0xFF3C22C9);
  static const Color primarySoft = Color(0xFFF1EAFF);
  static const Color background = Color(0xFFFAFAF8);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);

  /// Shared style for AppBars that use a solid black background, so every
  /// dark header in the app (login, home welcome bar, vendor detail
  /// headers) reads identically.
  static const Color headerBackground = Colors.black;
  static const TextStyle headerTitleStyle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w700,
    fontSize: 18,
  );
  static const IconThemeData headerIconTheme = IconThemeData(
    color: Colors.white,
  );
}
