import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_box.dart';
import '../../models/user_activity_model.dart';
import '../../models/user_model.dart';
import '../../repositories/users_repository.dart';

/// Shows the audit trail recorded by Cloud Functions for every privileged
/// account action (created, updated, role/branch changed, activated/
/// deactivated, password reset, login). If [user] is null this shows
/// activity across ALL users — useful for an Owner reviewing everything at
/// once rather than one profile at a time.
class UserActivityLogPage extends StatelessWidget {
  final UserModel? user;
  const UserActivityLogPage({super.key, this.user});

  @override
  Widget build(BuildContext context) {
    final repo = UsersRepository();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(user == null ? 'Activity Log' : '${user!.displayName} — Activity'),
      ),
      body: StreamBuilder<List<UserActivityModel>>(
        stream: repo.watchActivity(targetUid: user?.uid),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ErrorStateCard(message: snap.error.toString()),
              ),
            );
          }
          if (!snap.hasData) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: List.generate(
                6,
                (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: ShimmerBox(height: 76, borderRadius: 16),
                ),
              ),
            );
          }
          final entries = snap.data!;
          if (entries.isEmpty) {
            return const EmptyState(
              icon: Icons.history_rounded,
              title: 'No activity yet',
              message: 'Account actions will show up here as they happen.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            itemBuilder: (context, i) => _entryTile(entries[i]),
          );
        },
      ),
    );
  }

  Widget _entryTile(UserActivityModel entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: const BoxDecoration(color: AppColors.lightSuccess, shape: BoxShape.circle),
            child: Icon(_iconFor(entry.action), size: 16, color: AppColors.teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.action, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 3),
                Text(
                  '${entry.targetName} · by ${entry.administratorName}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textGray),
                ),
                if (entry.notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(entry.notes, style: const TextStyle(fontSize: 12, color: AppColors.textGray)),
                ],
                const SizedBox(height: 6),
                Text(Fmt.dateTime.format(entry.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.textGray)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String action) {
    final a = action.toLowerCase();
    if (a.contains('creat')) return Icons.person_add_alt_1_rounded;
    if (a.contains('role')) return Icons.shield_outlined;
    if (a.contains('branch')) return Icons.storefront_outlined;
    if (a.contains('deactivat')) return Icons.pause_circle_outline_rounded;
    if (a.contains('activat')) return Icons.check_circle_outline_rounded;
    if (a.contains('password')) return Icons.lock_reset_rounded;
    if (a.contains('login')) return Icons.login_rounded;
    return Icons.edit_outlined;
  }
}