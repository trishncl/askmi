import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/app_providers.dart';
import '../dashboard/dashboard_page.dart';
import '../inventory/inventory_page.dart';
import '../menu/menu_management_page.dart';
import '../products/products_page.dart';
import '../reports/reports_page.dart';
import '../sales/sales_page.dart';
import '../shell/app_drawer.dart';
import '../shell/floating_bottom_nav.dart';
import 'manager_reports_page.dart';

/// PHASE 5 — the Manager's container. Deliberately built the SAME shape as
/// OwnerShell (AppDrawer + FloatingBottomNav driving one shared `_index`,
/// AnimatedSwitcher body) and reuses every one of the Owner's actual
/// screens — DashboardPage, SalesPage, InventoryPage, ProductsPage,
/// MenuManagementPage, ReportsPage — verbatim. Nothing about those pages
/// is Owner-specific: they all read branch scope from `BranchScope` and
/// gate writes off `profile.role`, so simply presenting them inside this
/// shell instead of OwnerShell is enough to get a fully-scoped Manager
/// experience with zero duplicated UI or business logic.
///
/// The ONE thing this shell does differently from OwnerShell: instead of
/// the free `_BranchSelector` dropdown, the AppBar shows a plain, disabled
/// pill naming the Manager's own branch. There is nothing for them to tap
/// — `BranchScope` is already locked to `profile.branch` the moment their
/// profile loads (see BranchScope.applyProfile), so this label is a
/// read-only reflection of that lock, not a second source of truth.
///
/// "Submit Report" is the one Manager-only destination that ISN'T a
/// shared Owner screen — it's the opposite flow (Manager → Owner note),
/// already built as ManagerReportsPage.
class ManagerShell extends StatefulWidget {
  final UserModel profile;
  const ManagerShell({super.key, required this.profile});

  @override
  State<ManagerShell> createState() => _ManagerShellState();
}

class _ManagerShellState extends State<ManagerShell> {
  int _index = 0;

  static const _destinations = [
    DrawerDestination('Dashboard', Icons.dashboard_rounded),
    DrawerDestination('Sales', Icons.receipt_long_rounded),
    DrawerDestination('Inventory', Icons.inventory_2_rounded),
    DrawerDestination('Products', Icons.lunch_dining_rounded),
    DrawerDestination('Menu Management', Icons.restaurant_menu_rounded),
    DrawerDestination('Reports', Icons.description_rounded),
    DrawerDestination('Submit Report', Icons.send_rounded),
  ];

  static const _bottomItems = [
    BottomNavItem('Home', Icons.home_outlined, Icons.home_rounded),
    BottomNavItem('Sales', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
    BottomNavItem('Inventory', Icons.inventory_2_outlined, Icons.inventory_2_rounded),
    BottomNavItem('Reports', Icons.description_outlined, Icons.description_rounded),
  ];

  /// Maps each bottom-nav slot to its index in [_destinations].
  static const _bottomToDestination = [0, 1, 2, 5];

  int get _bottomIndex {
    final i = _bottomToDestination.indexOf(_index);
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
        return const ManagerReportsPage();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    // BranchScope is already locked to this Manager's own branch (applied
    // the moment their profile loaded — see BranchScope.applyProfile).
    // This is read-only here: there's no selector for the Manager to tap.
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
          _LockedBranchPill(branch: branchScope.selected),
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
                widget.profile.name.isNotEmpty ? widget.profile.name[0].toUpperCase() : '?',
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
            position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey(_index), child: _pageFor(_index)),
      ),
      bottomNavigationBar: FloatingBottomNav(
        currentIndex: _bottomIndex,
        items: _bottomItems,
        onTap: (i) => setState(() => _index = _bottomToDestination[i]),
      ),
    );
  }
}

/// Read-only stand-in for OwnerShell's `_BranchSelector` — same footprint
/// and styling, but nothing is tappable. A Manager should always be able
/// to SEE which branch they're scoped to without any illusion they can
/// change it from here.
class _LockedBranchPill extends StatelessWidget {
  final String branch;
  const _LockedBranchPill({required this.branch});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.lightSuccess,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.teal),
          const SizedBox(width: 6),
          Text(
            branch,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}