import 'package:flutter/material.dart';

/// AA's Lomi brand palette — finalized from the design brief. Every color
/// used anywhere in the app should trace back to one of these; don't add
/// new decorative colors ad hoc in a feature file.
class AppColors {
  AppColors._();

  // Primary
  static const teal = Color(0xFF2FAF9A);
  static const orange = Color(0xFFF47A20);
  static const red = Color(0xFFE64A19);

  // Secondary
  static const cream = Color(0xFFFFF8F0);
  static const white = Color(0xFFFFFFFF);

  // Accent
  static const gold = Color(0xFFF4B400);

  // Gradients
  static const tealGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [teal, Color(0xFF23907E)],
  );
  static const backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [white, cream],
  );

  // Neutrals — not in the brief, but every other screen still needs these
  // Neutrals — not in the brief, but every other screen still needs these
  static const bg = Color(0xFFF7F9FB);   // app scaffold background
  static const card = Colors.white;      // surface for cards/sheets
  static const textDark = Color(0xFF11263C);
  static const textGray = Color(0xFF6C7A89);
  static const border = Color(0xFFE6EBF2);

  // Semantic — reuses brand colors so status meaning stays on-palette
  static const success = teal;
  static const danger = red;
  static const warning = gold;

  static const lightSuccess = Color(0xFFE7F7F3);
  static const lightDanger = Color(0xFFFCEAE4);
  static const lightWarning = Color(0xFFFDF3DC);
}