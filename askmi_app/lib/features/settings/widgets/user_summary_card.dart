import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/animated_count.dart';
import '../../../models/user_model.dart';

class _StatDef {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final Color tint;

  const _StatDef({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.tint,
  });
}

/// Summary strip above the search/filter bar. Reflects the FULL scope
/// (whatever the AppBar branch selector currently shows), not the search/
/// role/status-filtered list underneath — so "14 users" always answers
/// "how many people work here", not "how many match my search".
class UserSummaryCard extends StatelessWidget {
  final List<UserModel> users;

  const UserSummaryCard({super.key, required this.users});

  @override
  Widget build(BuildContext context) {
    final total = users.length;
    final active = users.where((u) => u.status == 'active').length;
    final managers = users.where((u) => u.displayRole == 'Manager').length;
    final cashiers = users.where((u) => u.displayRole == 'Cashier').length;
    final inactive = users.where((u) => u.status == 'inactive').length;

    final stats = [
      _StatDef(
        label: 'Total Users',
        value: total,
        icon: Icons.groups_rounded,
        color: AppColors.teal,
        tint: AppColors.lightSuccess,
      ),
      _StatDef(
        label: 'Active',
        value: active,
        icon: Icons.check_circle_rounded,
        color: AppColors.active,
        tint: AppColors.lightActive,
      ),
      _StatDef(
        label: 'Managers',
        value: managers,
        icon: Icons.badge_rounded,
        color: AppColors.manager,
        tint: AppColors.lightManager,
      ),
      _StatDef(
        label: 'Cashiers',
        value: cashiers,
        icon: Icons.person_rounded,
        color: AppColors.orange,
        tint: AppColors.lightWarning,
      ),
      _StatDef(
        label: 'Inactive',
        value: inactive,
        icon: Icons.pause_circle_rounded,
        color: AppColors.inactive,
        tint: AppColors.lightInactive,
      ),
    ];

    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: stats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) => _tile(stats[i], i),
      ),
    );
  }

  Widget _tile(_StatDef d, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + index * 60),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 14), child: child),
      ),
      child: Container(
        width: 128,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: d.tint, shape: BoxShape.circle),
              child: Icon(d.icon, size: 16, color: d.color),
            ),
            const SizedBox(height: 8),
            AnimatedCount(
              value: d.value.toDouble(),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                height: 1.1,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              d.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.2,
                color: AppColors.textGray,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}