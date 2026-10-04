import 'package:flutter/material.dart';

/// BlueTrack palette: ocean blue, teal, coral.
abstract final class AppColors {
  static const Color ocean = Color(0xFF0284C7);
  static const Color oceanDeep = Color(0xFF075985);
  static const Color teal = Color(0xFF14B8A6);
  static const Color coral = Color(0xFFFF6F61);
  static const Color background = Color(0xFFF6F9FC);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFDC2626);
  static const Color inactiveTab = Color(0xFF94A3B8);
}

/// Layout constants: base padding 16dp, card radius 16dp.
abstract final class AppDimens {
  static const double padding = 16;
  static const double cardRadius = 16;
  static const double gap = 12;
}
