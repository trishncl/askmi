import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/app_providers.dart';
import 'login_page.dart';
import 'signed_in_placeholder_page.dart';

/// PHASE 2 — root routing widget. Splash's timer sends everyone here
/// (signed in or not) after the intro animation; from this point on,
/// everything is reactive to AuthState/UserProfileProvider rather than
/// explicit Navigator pushes.
///
/// SECURITY CHECKPOINT: create a throwaway Firebase Auth user with NO
/// matching users/{uid} doc, sign in as them, and confirm you land on
/// _AccountNotConfiguredPage — never on SignedInPlaceholderPage.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();

    if (!authState.isSignedIn) {
      return const LoginPage();
    }

    final profileState = context.watch<UserProfileProvider>();

    if (profileState.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (profileState.notConfigured || profileState.profile == null) {
      return const _AccountNotConfiguredPage();
    }

    // PHASE 4/5 will replace this with real role-based routing.
    return SignedInPlaceholderPage(profile: profileState.profile!);
  }
}

class _AccountNotConfiguredPage extends StatelessWidget {
  const _AccountNotConfiguredPage();

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
              const Icon(Icons.person_off_outlined, size: 56, color: AppColors.textGray),
              const SizedBox(height: 16),
              const Text(
                "Your account isn't set up yet",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                "Ask the owner to add you as a user, or contact support if you believe this is a mistake.",
                style: TextStyle(color: AppColors.textGray),
                textAlign: TextAlign.center,
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