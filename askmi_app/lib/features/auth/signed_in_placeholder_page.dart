import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';

/// TEMPORARY. Replace with real role-based routing (Owner/Manager/Cashier
/// shells) once Phase 4/5 build those out — this only exists so Splash and
/// Login have somewhere real to send a successfully-authenticated user in
/// the meantime, instead of a dead end.
class SignedInPlaceholderPage extends StatelessWidget {
  const SignedInPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final email = context.read<AuthService>().currentUser?.email ?? 'unknown';
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.teal, size: 56),
            const SizedBox(height: 16),
            Text('Signed in as $email', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text(
              'Owner/Manager/Cashier screens come in Phase 4/5.',
              style: TextStyle(color: AppColors.textGray),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => context.read<AuthService>().signOut(),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}