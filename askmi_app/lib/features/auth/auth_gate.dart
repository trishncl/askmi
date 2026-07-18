import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/app_providers.dart';
import 'login_page.dart';
import 'signed_in_placeholder_page.dart';
import '../shell/owner_shell.dart';

/// PHASE 2 — root routing widget. Splash's timer sends everyone here
/// (signed in or not) after the intro animation; from this point on,
/// everything is reactive to AuthState/UserProfileProvider rather than
/// explicit Navigator pushes — no race conditions between "which route is
/// on top" and "what does auth state actually say right now."
///
/// SECURITY CHECKPOINT (test this before moving to Phase 3+):
/// create a throwaway Firebase Auth user with NO matching users/{uid} doc,
/// sign in as them, and confirm you land on _AccountNotConfiguredPage —
/// never on SignedInPlaceholderPage (or, later, any real shell).
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

    if (profileState.deactivated) {
      return const _AccountDeactivatedPage();
    }

    // PHASE 4/5 will replace this with real role-based routing:
    //   switch (profile.role) { case 'Owner': return OwnerShell(); ... }
    // For now, this confirms sign-in + role lookup both work end-to-end.
    final profile = profileState.profile!;
    switch (profile.role) {
      case 'Owner':
        return OwnerShell(profile: profile);
      // PHASE 5 adds ManagerShell and CashierPosPage here. Until then those
      // roles land on the placeholder rather than being handed the Owner's
      // shell — giving a Cashier the Owner UI would be a real privilege leak,
      // not just a cosmetic bug.
      default:
        return SignedInPlaceholderPage(profile: profile);
    }
  }
}

/// Shared layout for every "you're signed in but can't proceed" dead end.
/// Both states below are deliberately terminal — sign out is the only
/// action, so there's no path from here into any shell.
class _BlockedAccountPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _BlockedAccountPage({
    required this.icon,
    required this.title,
    required this.message,
  });

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
              Icon(icon, size: 56, color: AppColors.textGray),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppColors.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(color: AppColors.textGray),
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

/// Signed in with valid credentials, but no matching users/{uid} document.
class _AccountNotConfiguredPage extends StatelessWidget {
  const _AccountNotConfiguredPage();

  @override
  Widget build(BuildContext context) {
    return const _BlockedAccountPage(
      icon: Icons.person_off_outlined,
      title: "Your account isn't set up yet",
      message: "Ask the owner to add you as a user, or contact support if "
          "you believe this is a mistake.",
    );
  }
}

/// Profile exists but active == false. Separate message from the above on
/// purpose: "not set up" and "switched off" are different problems, and
/// telling someone the wrong one wastes their time.
class _AccountDeactivatedPage extends StatelessWidget {
  const _AccountDeactivatedPage();

  @override
  Widget build(BuildContext context) {
    return const _BlockedAccountPage(
      icon: Icons.lock_outline_rounded,
      title: "This account has been deactivated",
      message: "Contact the owner if you think your access should be "
          "restored.",
    );
  }
}