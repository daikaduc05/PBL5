import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds
  static const Color background = Color(0xFF060F1D);
  static const Color backgroundSecondary = Color(0xFF0C1830);
  static const Color surface = Color(0xFF101B31);
  static const Color surfaceElevated = Color(0xFF162744);
  static const Color border = Color(0xFF274264);

  // Accents
  static const Color primary = Color(0xFF58E8FF);
  static const Color accent = Color(0xFF2A7BFF);
  static const Color accentSoft = Color(0xFF8CD8FF);

  // Typography
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA5B4CD);
  static const Color textMuted = Color(0xFF6E7D96);

  // Status Colors
  static const Color success = Color(0xFF3BF2A4);
  static const Color error = Color(0xFFFF617D);
  static const Color warning = Color(0xFFFFC857);

  // Gradients
  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF060F1D), Color(0xFF0B1730), Color(0xFF081222)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFF14233E), Color(0xFF0F1A30)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
