import 'package:flutter/material.dart';

// Sand-themed color palette
class SandColors {
  // Primary sand colors
  static const Color primaryGold = Color(0xFFDAA520); // goldenrod
  static const Color sandyBeige = Color(0xFFC2B280); // sandy beige for backgrounds
  static const Color deepSand = Color(0xFF8B6914); // dark goldenrod for borders
  static const Color lightSand = Color(0xFFF5DEB3); // wheat for highlights
  static const Color warmAccent = Color(0xFFFF8C00); // dark orange for CTAs

  // Neutrals
  static const Color darkBg = Color(0xFF0f0f0f); // very dark background
  static const Color mediumBg = Color(0xFF1a1a1a); // medium dark background

  // Preview box colors (muted earth tones that don't clash with blocks)
  static const Color previewBoxDark = Color(0xFF3d3d2d); // muddy olive-brown
  static const Color previewBoxLight = Color.fromARGB(255, 58, 58, 45); // lighter muddy olive-brown
}

final ThemeData theme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: SandColors.primaryGold,
    brightness: Brightness.dark,
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: Colors.white),
    bodyLarge: TextStyle(color: Colors.white),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: SandColors.warmAccent,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
);
