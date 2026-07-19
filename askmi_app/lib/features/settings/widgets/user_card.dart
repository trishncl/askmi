import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_model.dart';

/// Single user row for the User Management list.
///
/// Never offers permanent delete — only Activate/Deactivate — per the
/// project's account-management rule: user records are historical (sales,
/// inventory logs, activity) and deleting the profile would orphan that
/// trail.
class UserCard extends StatelessWidget {
  final UserModel user;
  final bool isSelf;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onResetPassword;

  const UserCard({
    super.key,
    required this.user,
    required this.isSelf,
    required this.onTap,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onResetPassword,
  });

  @override
  Widget build(BuildContext context) {
    // Owners can't deactivate themselves — if this card IS the signed-in
    // Owner, the power toggle is disabled rather than hidden, so it's clear
    // the action exists but isn't allowed here.
    final canToggle = !(isSelf && user.displayRole == 'Owner');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(user: user),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _RoleBadge(role: user.displayRole),
                          _StatusBadge(status: user.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _iconLine(Icons.mail_outline_rounded, user.username.isNotEmpty ? user.username : user.email),
                      const SizedBox(height: 3),
                      _iconLine(Icons.storefront_outlined, user.branch),
                    ],
                  ),
                ),
                Column(
                  children: [
                    IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.textGray),
                      onPressed: onEdit,
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      tooltip: canToggle
                          ? (user.active ? 'Deactivate' : 'Activate')
                          : "Owners can't deactivate their own account",
                      icon: Icon(
                        Icons.power_settings_new_rounded,
                        size: 20,
                        color: canToggle
                            ? (user.active ? AppColors.danger : AppColors.active)
                            : AppColors.border,
                      ),
                      onPressed: canToggle ? onToggleStatus : null,
                      visualDensity: VisualDensity.compact,
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'More',
                      icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textGray),
                      onSelected: (v) {
                        switch (v) {
                          case 'view':
                            onTap();
                          case 'reset':
                            onResetPassword();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'view', child: Text('View Details')),
                        PopupMenuItem(value: 'reset', child: Text('Reset Password')),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconLine(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.textGray),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.textGray),
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final UserModel user;
  const _Avatar({required this.user});

  @override
  Widget build(BuildContext context) {
    if (user.profileImageUrl.isNotEmpty) {
      return CircleAvatar(radius: 22, backgroundImage: NetworkImage(user.profileImageUrl));
    }
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.teal,
      child: Text(
        user.initials,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      'Owner' => AppColors.orange,
      'Manager' => AppColors.manager,
      _ => AppColors.textGray,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(role, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'active' => AppColors.active,
      'pending' => AppColors.pending,
      _ => AppColors.inactive,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 7, color: color),
          const SizedBox(width: 5),
          Text(
            status[0].toUpperCase() + status.substring(1),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}