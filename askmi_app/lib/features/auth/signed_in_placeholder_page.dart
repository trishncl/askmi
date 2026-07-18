import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/app_providers.dart';

class SignedInPlaceholderPage extends StatelessWidget {
  final UserModel profile;

  const SignedInPlaceholderPage({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.teal, size: 56),
              const SizedBox(height: 16),
              Text('Signed in as ${profile.name}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 4),
              Text(profile.email, style: const TextStyle(color: AppColors.textGray)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.lightSuccess,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Role: ${profile.role}  \u2022  Branch: ${profile.branch}',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Owner/Manager/Cashier screens come in Phase 4/5.',
                style: TextStyle(color: AppColors.textGray),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => context.read<AuthState>().service.signOut(),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}