import 'package:flutter/material.dart';

/// Brand palette from the AA's Lomi logo: teal (bowl) = primary/chrome,
/// orange (steam) = accent, reserved ONLY for primary call-to-action
/// buttons. Already finalized — nothing here should change without a
/// deliberate design decision, unlike the feature files in lib/features/.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF1E9E8E);
  static const primaryDark = Color(0xFF15776A);
  static const primaryLight = Color(0xFF6FC9BB);
  static const primarySoft = Color(0xFFE6F7F4);

  static const accent = Color(0xFFF2762E);
  static const accentDark = Color(0xFFD65A1A);
  static const accentSoft = Color(0xFFFDEEE3);

  static const bg = Color(0xFFF4F7FB);
  static const card = Colors.white;
  static const textDark = Color(0xFF11263C);
  static const textGray = Color(0xFF6C7A89);
  static const border = Color(0xFFE6EBF2);

  // Semantic ONLY — real status meaning (stock alerts, errors, success).
  static const success = Color(0xFF22C55E);
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);

  static const lightSuccess = Color(0xFFEAFBF0);
  static const lightDanger = Color(0xFFFFECEC);
  static const lightWarning = Color(0xFFFFF5E6);
}
