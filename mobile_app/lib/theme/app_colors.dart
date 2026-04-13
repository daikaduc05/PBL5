import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds
  static const Color background = Color(0xFF0B0F19);
  static const Color surface = Color(0xFF151B2B);

  // Accents
  static const Color primary = Color(0xFF00F0FF); // Cyan soft glow
  static const Color accent = Color(0xFFB829FF); // Electric pink/purple

  // Typography
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA0AABF);

  // Status Colors
  static const Color success = Color(0xFF00E676);
  static const Color error = Color(0xFFFF3D00);
  static const Color warning = Color(0xFFFFEA00);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
