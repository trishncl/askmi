import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/menu_category_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_box.dart';
import '../../models/menu_category_model.dart';
import '../../models/menu_item_model.dart';
import '../../models/user_model.dart';
import '../../providers/app_providers.dart';
import '../../repositories/menu_categories_repository.dart';
import '../../repositories/menu_repository.dart';
import '../../repositories/sales_repository.dart';
import '../dashboard/widgets/kpi_card.dart';
import 'category_management_page.dart';
import 'menu_details_page.dart';
import 'menu_filters.dart';
import 'menu_form_page.dart';
import 'menu_reorder_page.dart';
import 'widgets/menu_filter_bar.dart';
import 'widgets/menu_item_card.dart';

/// PHASE 4 — Owner build (5th: Menu Management). Configures what shows in
/// the cashier POS: catalog entries, categories, branch availability,
/// display order — NOT the POS itself (Phase 5).
///
/// Lives inside OwnerShell, so the AppBar (drawer, "Menu Management" title,
/// branch selector) is already supplied by the shell.
/// Search lives in the body instead of the AppBar — same placement as
/// Sales/Inventory/Products — rather than adding a page-specific AppBar
/// action slot the shell doesn't otherwise have, to keep the AppBar
/// identical in shape across every module.
///
/// PERMISSIONS: Cashier has no access at all (blocked screen below).
/// Owner: full access including Delete and Category Management.
/// Manager: add/edit/hide/duplicate/reorder, own branch only, no delete,
/// no category management. Enforced here in the UI for the same reason as
/// ProductsPage — see that file's note on Phase 6 Firestore hardening.
class MenuManagementPage extends StatefulWidget {
  const MenuManagementPage({super.key});

  @override
  State<MenuManagementPage> createState() => _MenuManagementPageState();
}

class _MenuManagementPageState extends State<MenuManagementPage> {
  final _menuRepo = MenuRepository();
  final _categoriesRepo = MenuCategoriesRepository();
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  MenuQuery _query = const MenuQuery();
  int _refreshToken = 0;
  Timer? _debounce;

  static const _pageSize = 40;
  int _limit = _pageSize;

  Map<String, int>? _soldCountByName; // lazily computed for "Best Selling"
  bool _loadingBestSelling = false;

  @override
  void initState() {
    super.initState();
    _categoriesRepo.seedDefaultsIfEmpty(kDefaultCategorySeed);
    _scrollCtrl.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollCtrl.removeListener(_maybeLoadMore);
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBestSelling() async {
    if (_soldCountByName != null || _loadingBestSelling) return;
    setState(() => _loadingBestSelling = true);
    try {
      final sales = await SalesRepository().fetchAll();
      final counts = <String, int>{};
      for (final s in sales) {
        counts[s.product] = (counts[s.product] ?? 0) + s.quantity;
      }
      if (mounted) setState(() => _soldCountByName = counts);
    } catch (_) {
      if (mounted) setState(() => _soldCountByName = {});
    } finally {
      if (mounted) setState(() => _loadingBestSelling = false);
    }
  }

  bool _loadingMore = false;
  bool _reachedEnd = false;

  void _maybeLoadMore() {
    if (!_scrollCtrl.hasClients || _loadingMore || _reachedEnd) return;
    final nearBottom =
        _scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 300;
    if (nearBottom) setState(() => _limit += _pageSize);
  }

  void _onSearchChanged(String value) {
    setState(() {}); // updates the clear (×) button right away
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = _query.copyWith(search: value));
    });
  }

  void _onSortChanged(MenuQuery q) {
    setState(() => _query = q);
    if (q.sort == MenuSort.bestSelling) _loadBestSelling();
  }

  String? _effectiveBranch(UserModel profile, String? branchScopeFilter) {
    if (profile.role == 'Owner') return branchScopeFilter;
    return profile.branch;
  }

  bool _canWrite(UserModel profile) => profile.role == 'Owner' || profile.role == 'Manager';
  bool _canDelete(UserModel profile) => profile.role == 'Owner';
  bool _canManageCategories(UserModel profile) => profile.role == 'Owner';

  Future<void> _openForm({
    MenuItemModel? existing,
    required List<MenuCategoryModel> categories,
    required int itemCount,
  }) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MenuFormPage(
          existing: existing,
          categories: categories,
          nextDisplayOrder: itemCount,
        ),
      ),
    );
    if (saved == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(existing == null ? 'Menu item added.' : 'Menu item updated.')),
        );
      }
    }
  }

  void _openDetails(MenuItemModel item, bool canWrite, bool canDelete) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MenuDetailsPage(
          item: item,
          canEdit: canWrite,
          canDelete: canDelete,
          onEdit: canWrite
              ? () {
                  Navigator.pop(context);
                  _openForm(existing: item, categories: const [], itemCount: item.displayOrder);
                }
              : null,
          onHideToggle: canWrite ? () => _hideToggle(item) : null,
          onDuplicate: canWrite ? () => _duplicate(item) : null,
          onDelete: canDelete ? () => _delete(item) : null,
        ),
      ),
    );
  }

  Future<void> _hideToggle(MenuItemModel item) async {
    final hiding = item.active;
    try {
      await _menuRepo.setActive(item.id, !item.active);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(hiding ? 'Menu item hidden.' : 'Menu item unhidden.')),
        );
      }
    } catch (e) {
      _snackError(e);
    }
  }

  Future<void> _duplicate(MenuItemModel item) async {
    try {
      await _menuRepo.duplicate(item);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Duplicated as a hidden copy — review before unhiding.')),
        );
      }
    } catch (e) {
      _snackError(e);
    }
  }

  Future<void> _delete(MenuItemModel item) async {
    final hasSales = await SalesRepository().hasAnySalesFor(item.name);
    if (!mounted) return;

    if (hasSales) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text("Can't delete — sales history exists"),
          content: Text(
            '${item.name} has recorded sales, so deleting it would break that history. '
            'Hide it instead to remove it from the POS while keeping past sales intact.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _hideToggle(item);
              },
              child: const Text('Hide Instead'),
            ),
          ],
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete menu item?'),
        content: Text('${item.name} will be permanently removed. This can\'t be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _menuRepo.delete(item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Menu item deleted.')),
        );
      }
    } catch (e) {
      _snackError(e);
    }
  }

  void _snackError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.toString().contains('permission-denied')
            ? "You don't have permission to do that."
            : 'Something went wrong: $e'),
      ),
    );
  }

  Future<void> _openReorder(List<MenuItemModel> categoryItems) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MenuReorderPage(category: _query.category, items: categoryItems),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Order saved.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserProfileProvider>().profile;
    final branchScope = context.watch<BranchScope>().filterOrNull;

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (profile.role == 'Cashier') {
      return const _NoAccessView();
    }

    final branch = _effectiveBranch(profile, branchScope);
    final canWrite = _canWrite(profile);
    final canDelete = _canDelete(profile);
    final canManageCategories = _canManageCategories(profile);

    return Container(
      color: AppColors.bg,
      child: StreamBuilder<List<MenuCategoryModel>>(
        stream: _categoriesRepo.watchAllOrdered(),
        builder: (context, categorySnap) {
          final categories = categorySnap.data ?? const <MenuCategoryModel>[];

          return StreamBuilder<List<MenuItemModel>>(
            // _limit is intentionally NOT part of this key. Keying on it
            // used to force Flutter to tear down and recreate this whole
            // StreamBuilder (and re-subscribe to Firestore from scratch)
            // every time the page grew — which happened on nearly every
            // scroll frame near the bottom, causing severe jank.
            key: ValueKey('menu_${branch}_$_refreshToken'),
            stream: _menuRepo.watchAllForBranch(
              branch: branch,
              orderByField: 'displayOrder',
              limit: _limit,
            ),
            builder: (context, snap) {
              final loading = snap.connectionState == ConnectionState.waiting;
              final error = snap.error;
              final all = snap.data ?? const <MenuItemModel>[];
              final filtered = _query.apply(
                all,
                soldCountByName: _soldCountByName ?? const {},
              );
              final reachedEnd = all.length < _limit;
              final totalCount = all.length;

              // The widened-limit query has delivered data for this frame —
              // clear the in-flight flag (and latch reachedEnd) so the next
              // scroll near the bottom is allowed to request another page.
              if (!loading && (_loadingMore || _reachedEnd != reachedEnd)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _loadingMore = false;
                      _reachedEnd = reachedEnd;
                    });
                  }
                });
              }
              final availableCount = all.where((m) => m.status == MenuItemStatus.available).length;
              final hiddenCount = all.where((m) => m.status == MenuItemStatus.hidden).length;

              return Scaffold(
                backgroundColor: Colors.transparent,
                floatingActionButton: canWrite
                    ? FloatingActionButton.extended(
                        backgroundColor: AppColors.teal,
                        foregroundColor: Colors.white,
                        onPressed: () => _openForm(categories: categories, itemCount: totalCount),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add Menu Item'),
                      )
                    : null,
                body: RefreshIndicator(
                  color: AppColors.teal,
                  onRefresh: () async {
                    setState(() {
                      _refreshToken++;
                      _limit = _pageSize;
                      _loadingMore = false;
                      _reachedEnd = false;
                    });
                  },
                  child: CustomScrollView(
                    controller: _scrollCtrl,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: _header(
                          totalCount: totalCount,
                          canManageCategories: canManageCategories,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _summaryRow(totalCount, availableCount, hiddenCount),
                      ),
                      SliverToBoxAdapter(child: _searchBar()),
                      SliverToBoxAdapter(
                        child: MenuFilterBar(
                          query: _query,
                          categories: categories,
                          onChanged: _onSortChanged,
                        ),
                      ),
                      if (_query.category != kAllCategoriesFilter && canWrite)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed:
                                    filtered.length < 2 ? null : () => _openReorder(filtered),
                                icon: const Icon(Icons.swap_vert_rounded, size: 18),
                                label: const Text('Reorder this category'),
                              ),
                            ),
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 8)),
                      if (_query.sort == MenuSort.bestSelling && _loadingBestSelling)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                        ),
                      if (error != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: ErrorStateCard(
                              message: error.toString().contains('permission-denied')
                                  ? "You don't have access to menu data. Check your Firestore rules."
                                  : 'Check your connection and try again.',
                              onRetry: () => setState(() => _refreshToken++),
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
                                  child: ShimmerBox(height: 108, borderRadius: 18),
                                ),
                              ),
                            ),
                          ),
                        )
                      else if (filtered.isEmpty)
                        SliverToBoxAdapter(
                          child: EmptyState(
                            icon: Icons.restaurant_menu_rounded,
                            title:
                                all.isEmpty ? 'No menu items yet' : 'Nothing matches those filters',
                            message: all.isEmpty
                                ? (canWrite
                                    ? 'Add your first menu item to see it here.'
                                    : 'No menu items have been added for this branch yet.')
                                : 'Try clearing the search or filters above.',
                            actionLabel: all.isEmpty && canWrite ? 'Add Menu Item' : null,
                            onAction: all.isEmpty && canWrite
                                ? () => _openForm(categories: categories, itemCount: totalCount)
                                : null,
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final item = filtered[i];
                              return MenuItemCard(
                                item: item,
                                index: i,
                                onTap: () => _openDetails(item, canWrite, canDelete),
                                canEdit: canWrite,
                                canDelete: canDelete,
                                onAction: (action) {
                                  switch (action) {
                                    case MenuCardAction.edit:
                                      _openForm(
                                        existing: item,
                                        categories: categories,
                                        itemCount: totalCount,
                                      );
                                      break;
                                    case MenuCardAction.hideToggle:
                                      _hideToggle(item);
                                      break;
                                    case MenuCardAction.duplicate:
                                      _duplicate(item);
                                      break;
                                    case MenuCardAction.delete:
                                      _delete(item);
                                      break;
                                  }
                                },
                              );
                            },
                          ),
                        ),
                      if (!loading && error == null && filtered.isNotEmpty && !reachedEnd)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.2),
                              ),
                            ),
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 96)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _header({required int totalCount, required bool canManageCategories}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Menu Management',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.textDark),
                ),
                SizedBox(height: 4),
                Text(
                  'Configure what shows in the cashier POS.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textGray),
                ),
              ],
            ),
          ),
          if (canManageCategories)
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CategoryManagementPage()),
              ),
              icon: const Icon(Icons.category_outlined, size: 16),
              label: const Text('Categories'),
            ),
        ],
      ),
    );
  }

  Widget _summaryRow(int total, int available, int hidden) {
    final kpis = <KpiData>[
      KpiData(
        label: 'Total Menu Items',
        icon: Icons.restaurant_menu_rounded,
        color: AppColors.teal,
        tint: AppColors.lightSuccess,
        caption: 'items',
        numericValue: total.toDouble(),
      ),
      KpiData(
        label: 'Available Items',
        icon: Icons.check_circle_outline_rounded,
        color: const Color(0xFF3B82F6),
        tint: const Color(0xFF3B82F6).withValues(alpha: 0.10),
        caption: 'in POS',
        numericValue: available.toDouble(),
      ),
      KpiData(
        label: 'Hidden Items',
        icon: Icons.visibility_off_rounded,
        color: AppColors.textGray,
        tint: AppColors.bg,
        caption: 'not in POS',
        numericValue: hidden.toDouble(),
      ),
    ];

    return SizedBox(
      height: 132,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: kpis.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) => KpiCard(data: kpis[i], index: i),
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search menu, category…',
          hintStyle: const TextStyle(fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: _searchCtrl.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    _debounce?.cancel();
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

class _NoAccessView extends StatelessWidget {
  const _NoAccessView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, size: 48, color: AppColors.textGray),
              SizedBox(height: 16),
              Text(
                "You don't have access to Menu Management",
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
              SizedBox(height: 6),
              Text(
                'The finalized menu is available in the POS.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppColors.textGray),
              ),
            ],
          ),
        ),
      ),
    );
  }
}