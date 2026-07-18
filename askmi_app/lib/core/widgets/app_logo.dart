import 'package:flutter/material.dart';

/// Displays the AA's Lomi brand mark. Expects a transparent PNG at
/// assets/images/logo.png — transparency matters here since the same logo
/// sits on both the white splash background and the cream login gradient.
/// Falls back to a simple bowl icon if the real asset isn't there yet, so
/// the app doesn't crash before you add it.
class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      '../assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0xFFE7F7F3),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.ramen_dining_rounded, size: size * 0.5, color: const Color(0xFF2FAF9A)),
      ),
    );
  }
}