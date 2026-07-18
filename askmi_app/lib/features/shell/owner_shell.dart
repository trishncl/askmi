import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/branch_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/app_providers.dart';
import '../dashboard/dashboard_page.dart';
import 'app_drawer.dart';
import 'coming_soon_page.dart';
import 'floating_bottom_nav.dart';
import 'speed_dial_fab.dart';

/// PHASE 4 — the Owner's container: AppBar (branch selector, notifications,
/// avatar), navigation drawer, floating bottom nav, and speed-dial FAB.
///
/// Drawer and bottom nav drive the SAME index, so the two stay in sync
/// rather than tracking separate state. The bottom bar surfaces four
/// high-traffic destinations; the drawer holds all of them.
class OwnerShell extends StatefulWidget {
  final UserModel profile;
  const OwnerShell({super.key, required this.profile});

  @override
  State<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends State<OwnerShell> {
  int _index = 0;

  static const _destinations = [
    DrawerDestination('Dashboard', Icons.dashboard_rounded),
    DrawerDestination('Sales', Icons.receipt_long_rounded),
    DrawerDestination('Inventory', Icons.inventory_2_rounded),
    DrawerDestination('Products', Icons.lunch_dining_rounded),
    DrawerDestination('Menu Management', Icons.restaurant_menu_rounded),
    DrawerDestination('Branches', Icons.store_rounded),
    DrawerDestination('Reports', Icons.description_rounded),
    DrawerDestination('User Management', Icons.people_alt_rounded),
    DrawerDestination('Settings', Icons.settings_rounded),
  ];

  static const _bottomItems = [
    BottomNavItem('Home', Icons.home_outlined, Icons.home_rounded),
    BottomNavItem('Branches', Icons.store_outlined, Icons.store_rounded),
    BottomNavItem('Reports', Icons.description_outlined, Icons.description_rounded),
    BottomNavItem('Users', Icons.people_alt_outlined, Icons.people_alt_rounded),
  ];

  /// Maps each bottom-nav slot to its index in [_destinations].
  static const _bottomToDestination = [0, 5, 6, 7];

  int get _bottomIndex {
    final i = _bottomToDestination.indexOf(_index);
    // Drawer-only destinations keep the last bottom tab highlighted rather
    // than clearing it — losing all highlight reads as a rendering bug.
    return i == -1 ? 0 : i;
  }

  Widget _pageFor(int index) {
    switch (index) {
      case 0:
        return const DashboardPage();
      default:
        return ComingSoonPage(title: _destinations[index].label);
    }
  }

  @override
  Widget build(BuildContext context) {
    final branchScope = context.watch<BranchScope>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 2,
        title: Text(
          _destinations[_index].label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
        ),
        actions: [
          _BranchSelector(
            value: branchScope.selected,
            onChanged: branchScope.select,
          ),
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notifications arrive in a later sprint.')),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 2),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.teal,
              child: Text(
                widget.profile.name.isNotEmpty
                    ? widget.profile.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: AppDrawer(
        profile: widget.profile,
        selectedIndex: _index,
        destinations: _destinations,
        onSelected: (i) {
          setState(() => _index = i);
          Navigator.pop(context);
        },
        onLogout: () => context.read<AuthState>().service.signOut(),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.02), end: Offset.zero)
                .animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey(_index), child: _pageFor(_index)),
      ),
      floatingActionButton: SpeedDialFab(
        actions: [
          SpeedDialAction(
            label: 'Add Sale',
            icon: Icons.point_of_sale_rounded,
            onTap: () => _notYet(context, 'Add Sale'),
          ),
          SpeedDialAction(
            label: 'Add Inventory',
            icon: Icons.inventory_rounded,
            onTap: () => _notYet(context, 'Add Inventory'),
          ),
          SpeedDialAction(
            label: 'Generate Report',
            icon: Icons.description_rounded,
            onTap: () => _notYet(context, 'Generate Report'),
          ),
          SpeedDialAction(
            label: 'Add User',
            icon: Icons.person_add_alt_1_rounded,
            onTap: () => _notYet(context, 'Add User'),
          ),
        ],
      ),
      bottomNavigationBar: FloatingBottomNav(
        currentIndex: _bottomIndex,
        items: _bottomItems,
        onTap: (i) => setState(() => _index = _bottomToDestination[i]),
      ),
    );
  }

  void _notYet(BuildContext context, String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"$action" is built in a later sprint.')),
    );
  }
}

class _BranchSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _BranchSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          borderRadius: BorderRadius.circular(14),
          icon: const Icon(Icons.expand_more_rounded, size: 18),
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
          items: [
            for (final b in kBranchNamesWithAll)
              DropdownMenuItem(
                value: b,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.storefront_rounded, size: 14, color: AppColors.teal),
                    const SizedBox(width: 6),
                    Text(b),
                  ],
                ),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}