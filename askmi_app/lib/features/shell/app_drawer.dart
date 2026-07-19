import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_logo.dart';
import '../../models/user_model.dart';

class DrawerDestination {
  final String label;
  final IconData icon;
  const DrawerDestination(this.label, this.icon);
}

/// Navigation drawer with the branded header (logo, avatar, name, role
/// badge) and grouped destinations, matching the desktop sidebar's
/// MAIN / INSIGHTS / OPERATIONS / ADMINISTRATION structure.
class AppDrawer extends StatelessWidget {
  final UserModel profile;
  final int selectedIndex;
  final List<DrawerDestination> destinations;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;

  /// Index at which each section header appears, keyed by index.
  static const sectionHeaders = <int, String>{
    0: 'MAIN',
    1: 'OPERATIONS',
    5: 'INSIGHTS',
    6: 'ADMINISTRATION',
  };

  const AppDrawer({
    super.key,
    required this.profile,
    required this.selectedIndex,
    required this.destinations,
    required this.onSelected,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
              child: Row(
                children: [
                  const AppLogo(size: 42),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AskMi',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        "AA's Lomi",
                        style: TextStyle(color: AppColors.textGray, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.lightSuccess,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.teal,
                    child: Text(
                      profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome back,',
                          style: TextStyle(color: AppColors.textGray, fontSize: 11),
                        ),
                        Text(
                          profile.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.teal,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            profile.role.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: destinations.length,
                itemBuilder: (context, index) {
                  final selected = index == selectedIndex;
                  final header = sectionHeaders[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (header != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
                          child: Text(
                            header,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                              color: AppColors.textGray,
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: ListTile(
                          dense: true,
                          selected: selected,
                          selectedTileColor: AppColors.teal,
                          selectedColor: Colors.white,
                          iconColor: selected ? Colors.white : AppColors.textGray,
                          textColor: selected ? Colors.white : AppColors.textDark,
                          shape:
                              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          leading: Icon(destinations[index].icon, size: 22),
                          title: Text(
                            destinations[index].label,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          onTap: () => onSelected(index),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.red),
              title: const Text(
                'Logout',
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.red),
              ),
              onTap: onLogout,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}