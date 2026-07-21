import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/branch_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/app_providers.dart';
import '../dashboard/dashboard_page.dart';
import '../inventory/inventory_page.dart';
import '../menu/menu_management_page.dart';
import '../products/products_page.dart';
import '../reports/reports_page.dart';
import '../sales/sales_page.dart';
import 'app_drawer.dart';
import 'coming_soon_page.dart';
import 'floating_bottom_nav.dart';
import '../settings/settings_page.dart';

/// PHASE 4 — the Owner's container: AppBar (branch selector,
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
    DrawerDestination('Reports', Icons.description_rounded),
    DrawerDestination('User Management', Icons.people_alt_rounded),
  ];

  static const _bottomItems = [
    BottomNavItem('Home', Icons.home_outlined, Icons.home_rounded),
    BottomNavItem('Menu', Icons.restaurant_menu_outlined, Icons.restaurant_menu_rounded),
    BottomNavItem('Reports', Icons.description_outlined, Icons.description_rounded),
    BottomNavItem('Users', Icons.people_alt_outlined, Icons.people_alt_rounded),
  ];

  /// Maps each bottom-nav slot to its index in [_destinations].
  static const _bottomToDestination = [0, 4, 5, 6];

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
      case 1:
        return const SalesPage();
      case 2:
        return const InventoryPage();
      case 3:
        return const ProductsPage();
      case 4:
        return const MenuManagementPage();
      case 5:
        return const ReportsPage();
      case 6:
        return const SettingsPage();
      default:
        return ComingSoonPage(title: _destinations[index].label);
    }
  }

  /// Dashboard's floating action button was removed per request — no FAB
  /// on any tab now. Every other module still supplies its own
  /// single-purpose FAB (e.g. Sales has "New Sale"); this just means the
  /// Dashboard tab no longer stacks a speed-dial on top of that.
  Widget? _buildFab() => null;

  /// Menu items span every branch's POS catalog in one view — there's no
  /// per-branch picker for this page, it's always "All Branches" (see
  /// `isMenuManagementTab` in build() below, which hides the selector
  /// entirely while this tab is active). Switching INTO the tab resets
  /// BranchScope back to "All Branches" so it doesn't silently carry over
  /// whatever a different tab had picked earlier.
  void _selectIndex(int i) {
    setState(() => _index = i);
    if (i == 4) {
      context.read<BranchScope>().select(kAllBranches);
    }
  }

  @override
  Widget build(BuildContext context) {
    final branchScope = context.watch<BranchScope>();
    final isMenuManagementTab = _index == 4;

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
          // Owners always keep the free branch selector, EXCEPT on Menu
          // Management, which always shows every branch's items and has
          // no selector to offer. Also hides defensively if a non-Owner
          // profile somehow ends up in OwnerShell (it shouldn't — AuthGate
          // routes by role).
          if (!branchScope.isLocked && !isMenuManagementTab)
            _BranchSelector(
              value: branchScope.selected,
              items: kBranchNamesWithAll,
              onChanged: branchScope.select,
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
          _selectIndex(i);
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
      floatingActionButton: _buildFab(),
      bottomNavigationBar: FloatingBottomNav(
        currentIndex: _bottomIndex,
        items: _bottomItems,
        onTap: (i) => _selectIndex(_bottomToDestination[i]),
      ),
    );
  }

  // ignore: unused_element
  void _notYet(BuildContext context, String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"$action" is built in a later sprint.')),
    );
  }
}

class _BranchSelector extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _BranchSelector({required this.value, required this.items, required this.onChanged});

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
            for (final b in items)
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