import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_box.dart';
import '../../models/user_model.dart';
import '../../providers/app_providers.dart';
import '../../repositories/users_repository.dart';
import '../../services/user_admin_service.dart';
import 'user_activity_log_page.dart';
import 'user_details_page.dart';
import 'user_form_page.dart';
import 'user_query.dart';
import 'widgets/user_card.dart';
import 'widgets/user_filter_bar.dart';
import 'widgets/user_summary_card.dart';

/// PHASE 4 — Owner build (8th/last: Settings — highest privilege, build
/// last). The Owner's User Management screen: summary counts, search/
/// filter/sort, and per-user Edit/Activate-Deactivate/Reset Password.
///
/// Scoped by the AppBar's BranchScope selector (owner_shell.dart) — same
/// mechanism every other Owner page uses, so "Changing the branch
/// refreshes the user list and summary cards" happens for free here too.
///
/// Every privileged write (create, update, status change, password reset)
/// goes through UserAdminService -> Cloud Functions. This page and its
/// children never touch Firebase Auth admin operations directly.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _repo = UsersRepository();
  final _adminService = UserAdminService();
  final _searchCtrl = TextEditingController();

  UserQuery _query = const UserQuery();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openForm({UserModel? existing}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => UserFormPage(existing: existing)),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(existing == null ? 'User created.' : 'User updated.')),
      );
    }
  }

  void _openDetails(UserModel user) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UserDetailsPage(user: user)),
    );
  }

  Future<void> _toggleStatus(UserModel user, bool isSelf) async {
    if (isSelf && user.displayRole == 'Owner') {
      _snack("Owners can't deactivate their own account.");
      return;
    }
    final activating = !user.active;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(activating ? 'Activate account?' : 'Deactivate account?'),
        content: Text(
          activating
              ? '${user.displayName} will be able to sign in again.'
              : '${user.displayName} will be signed out and unable to sign in until reactivated.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(activating ? 'Activate' : 'Deactivate'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _adminService.setStatus(user, activating ? 'active' : 'inactive');
      _snack(activating ? 'Account activated.' : 'Account deactivated.');
    } on UserAdminException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _resetPassword(UserModel user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send password reset?'),
        content: Text("A reset link will be emailed to ${user.email}."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Send')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _adminService.sendPasswordReset(user);
      _snack('Password reset email sent.');
    } on UserAdminException catch (e) {
      _snack(e.message);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final branch = context.watch<BranchScope>().filterOrNull;
    final currentUid = context.watch<UserProfileProvider>().profile?.uid;

    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add User'),
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: _repo.watchUsers(branch: branch),
        builder: (context, snap) {
          final loading = !snap.hasData && !snap.hasError;
          final all = snap.data ?? const <UserModel>[];
          final filtered = _query.apply(all);

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _header(all.length),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: UserSummaryCard(users: all),
                ),
              ),
              SliverToBoxAdapter(child: _infoBanner()),
              SliverToBoxAdapter(child: _searchField()),
              SliverToBoxAdapter(
                child: UserFilterBar(
                  query: _query,
                  onChanged: (q) => setState(() => _query = q),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              if (snap.hasError)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ErrorStateCard(
                      message: snap.error.toString().contains('permission-denied')
                          ? "You don't have access to user data. Check your Firestore rules."
                          : 'Check your connection and try again.',
                      onRetry: () => setState(() {}),
                    ),
                  ),
                )
              else if (loading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: List.generate(
                        4,
                        (_) => const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: ShimmerBox(height: 110, borderRadius: 18),
                        ),
                      ),
                    ),
                  ),
                )
              else if (filtered.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.people_alt_rounded,
                    title: all.isEmpty ? 'No users found' : 'Nothing matches those filters',
                    message: all.isEmpty
                        ? 'Add your first team member to get started.'
                        : 'Try clearing the search or filters above.',
                    actionLabel: all.isEmpty ? 'Add User' : null,
                    onAction: all.isEmpty ? () => _openForm() : null,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final user = filtered[i];
                      final isSelf = user.uid == currentUid;
                      return UserCard(
                        user: user,
                        isSelf: isSelf,
                        onTap: () => _openDetails(user),
                        onEdit: () => _openForm(existing: user),
                        onToggleStatus: () => _toggleStatus(user, isSelf),
                        onResetPassword: () => _resetPassword(user),
                      );
                    },
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          );
        },
      ),
    );
  }

  Widget _header(int total) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'User Management',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.textDark),
              ),
              const SizedBox(height: 4),
              Text(
                '$total ${total == 1 ? 'user' : 'users'}',
                style: const TextStyle(fontSize: 13, color: AppColors.textGray),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Activity Log',
          icon: const Icon(Icons.history_rounded, color: AppColors.textGray),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const UserActivityLogPage()),
          ),
        ),
      ],
    );
  }

  Widget _infoBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.lightSuccess,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.teal.withValues(alpha: 0.25)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 18, color: AppColors.teal),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'This manages user profiles in Firestore. To create actual login '
                'accounts, use Firebase Admin SDK or a Cloud Function — never place '
                'Admin credentials in the client app. Invite users via the platform\'s '
                'invite system for authentication.',
                style: TextStyle(fontSize: 12, color: AppColors.textDark, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = _query.copyWith(search: v)),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search users...',
          hintStyle: const TextStyle(fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: _query.search.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _query = _query.copyWith(search: ''));
                  },
                ),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.border),
          ),
        ),
      ),
    );
  }
}