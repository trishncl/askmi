import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/app_providers.dart';
import '../shell/app_drawer.dart';
import 'cashier_pos_page.dart';
import 'sales_history_page.dart';

/// The Cashier's container — same shape as ManagerShell/OwnerShell
/// (AppDrawer driving a single `_index`, AnimatedSwitcher body, a locked
/// branch pill instead of a selector) but with only the two destinations a
/// Cashier is allowed: Point of Sale and Sales History. There is
/// deliberately no bottom nav and no route to any Owner/Manager screen —
/// Dashboard, Inventory, Products, Menu Management, and Reports are simply
/// never constructed here.
class CashierShell extends StatefulWidget {
  final UserModel profile;
  const CashierShell({super.key, required this.profile});

  @override
  State<CashierShell> createState() => _CashierShellState();
}

class _CashierShellState extends State<CashierShell> {
  int _index = 0;

  static const _destinations = [
    DrawerDestination('Point of Sale', Icons.point_of_sale_rounded),
    DrawerDestination('Sales History', Icons.receipt_long_rounded),
  ];

  Widget _pageFor(int index) {
    switch (index) {
      case 0:
        return const CashierPosPage();
      case 1:
        return const SalesHistoryPage();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
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
          _LockedBranchPill(branch: widget.profile.branch),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 8),
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
        sectionHeaders: const {0: 'MAIN'},
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
    );
  }
}

/// Same read-only branch pill as ManagerShell's — a Cashier can always see
/// which branch they're scoped to, with nothing tappable, since switching
/// branches isn't something a Cashier can do.
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
