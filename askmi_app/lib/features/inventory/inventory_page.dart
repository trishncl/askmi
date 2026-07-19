import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_box.dart';
import '../../models/inventory_model.dart';
import '../../models/user_model.dart';
import '../../providers/app_providers.dart';
import '../../repositories/inventory_repository.dart';
import '../dashboard/widgets/kpi_card.dart';
import 'inventory_filters.dart';
import 'inventory_details_page.dart';
import 'inventory_form_page.dart';
import 'widgets/inventory_alert_card.dart';
import 'widgets/inventory_filter_bar.dart';
import 'widgets/stock_item_card.dart';
import 'widgets/stock_status_badge.dart';

/// PHASE 4 — Owner build (3rd: Inventory). Daily stock records & ingredient
/// tracking: summary KPIs, search/filter, add/edit/delete, low-stock alerts.
///
/// Lives inside OwnerShell, so the AppBar (drawer button, title, branch
/// selector, notifications) is already supplied by the shell — this page
/// only owns the body. Changing branch in the shell rebuilds BranchScope,
/// which this page watches, so the whole screen (summary + list) refreshes
/// automatically without any wiring here.
class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  static const _pageSize = 12;

  final _repo = InventoryRepository();
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  InventoryQuery _query = const InventoryQuery();
  int _refreshToken = 0;
  int _limit = _pageSize;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_maybeLoadMore);
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_scrollCtrl.hasClients) return;
    final nearBottom = _scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 280;
    if (nearBottom) {
      setState(() => _limit += _pageSize);
    }
  }

  Future<void> _openForm({InventoryModel? existing}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => InventoryFormPage(existing: existing)),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(existing == null ? 'Inventory log added.' : 'Inventory log updated.')),
      );
    }
  }

  Future<bool> _confirmDelete(InventoryModel item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete inventory log?'),
        content: Text(
          '${item.itemName} (${Fmt.dateOnly.format(item.date)}) will be permanently removed. '
          'This also changes your reported stock totals.',
        ),
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
    if (ok != true) return false;

    try {
      await _repo.delete(item.id);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Inventory log deleted.')));
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().contains('permission-denied')
                ? "You don't have permission to delete this."
                : 'Delete failed: $e'),
          ),
        );
      }
      return false;
    }
  }

  Future<void> _showDetails(InventoryModel item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InventoryDetailsPage(
          item: item,
          canMutate: _canMutate,
          onEdit: _canMutate ? () => _openForm(existing: item) : null,
          onDelete: _canMutate ? () => _confirmDelete(item) : null,
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textGray)),
          Text(value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        ],
      ),
    );
  }

  static String _n(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  UserModel? get _currentProfile => context.read<UserProfileProvider>().profile;

  // Owner/Manager can edit or delete inventory logs; everyone else (Staff/
  // Cashier) is view-only, matching the permission model used in Products.
  bool get _canMutate {
    final role = (_currentProfile?.role ?? '').toLowerCase();
    return role == 'owner' || role == 'manager';
  }

  @override
  Widget build(BuildContext context) {
    final branch = context.watch<BranchScope>().filterOrNull;

    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: _canMutate
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.teal,
              foregroundColor: Colors.white,
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Log'),
            )
          : null,
      body: RefreshIndicator(
        color: AppColors.teal,
        onRefresh: () async {
          setState(() {
            _refreshToken++;
            _limit = _pageSize;
          });
          await Future<void>.delayed(const Duration(milliseconds: 500));
        },
        // The summary stream stays full-branch so the cards always reflect
        // the selected scope, while the list stream grows in batches for
        // cheaper scrolling and fewer initial reads.
        child: StreamBuilder<List<InventoryModel>>(
          key: ValueKey('inventory_summary_${branch}_$_refreshToken'),
          stream: _repo.watchAll(branch: branch, orderByField: 'date'),
          builder: (context, summarySnap) {
            final summaryLoading = summarySnap.connectionState == ConnectionState.waiting;
            final summaryError = summarySnap.error;
            final all = summarySnap.data ?? const <InventoryModel>[];

            final critical = all.where((i) => i.status == StockStatus.critical).toList();
            final perishable = all.where((i) => i.category.toLowerCase() == 'perishable').length;
            final nonPerishable = all.where((i) => i.category.toLowerCase() == 'non-perishable').length;
            final estConsumption = all.fold<double>(0, (sum, i) => sum + i.estimatedConsumption);
            final totalWastage = all.fold<double>(0, (sum, i) => sum + i.wastage);

            final kpis = <KpiData>[
              KpiData(
                label: 'Critical Items',
                icon: Icons.warning_amber_rounded,
                color: AppColors.danger,
                tint: AppColors.lightDanger,
                caption: 'Needs restock',
                numericValue: critical.length.toDouble(),
              ),
              KpiData(
                label: 'Perishable',
                icon: Icons.eco_outlined,
                color: AppColors.gold,
                tint: AppColors.lightWarning,
                caption: 'Ingredients',
                numericValue: perishable.toDouble(),
              ),
              KpiData(
                label: 'Non-Perishable',
                icon: Icons.category_outlined,
                color: const Color(0xFF3B82F6),
                tint: const Color(0xFF3B82F6).withValues(alpha: 0.10),
                caption: 'Ingredients',
                numericValue: nonPerishable.toDouble(),
              ),
              KpiData(
                label: 'Est. Consumption',
                icon: Icons.calculate_outlined,
                color: AppColors.teal,
                tint: AppColors.lightSuccess,
                caption: 'units',
                numericValue: estConsumption,
                decimals: 1,
              ),
              KpiData(
                label: 'Total Wastage',
                icon: Icons.delete_sweep_outlined,
                color: AppColors.orange,
                tint: AppColors.lightWarning,
                caption: 'units',
                numericValue: totalWastage,
                decimals: 1,
              ),
            ];

            return StreamBuilder<List<InventoryModel>>(
              key: ValueKey('inventory_list_${branch}_${_refreshToken}_$_limit'),
              stream: _repo.watchAll(branch: branch, orderByField: 'date', limit: _limit),
              builder: (context, listSnap) {
                final loading = summaryLoading || listSnap.connectionState == ConnectionState.waiting;
                final error = summaryError ?? listSnap.error;
                final loaded = listSnap.data ?? const <InventoryModel>[];
                final filtered = _query.apply(loaded);
                final reachedEnd = loaded.length < _limit;

                return CustomScrollView(
                  controller: _scrollCtrl,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 132,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          itemCount: kpis.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, i) => KpiCard(data: kpis[i], index: i),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: _searchBar()),
                    SliverToBoxAdapter(
                      child: InventoryFilterBar(
                        query: _query,
                        onChanged: (q) => setState(() => _query = q),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    if (!loading && error == null)
                      SliverToBoxAdapter(
                        child: InventoryAlertCard(
                          criticalItems: critical,
                          onTap: () => setState(
                            () => _query = _query.copyWith(category: CategoryFilter.critical),
                          ),
                        ),
                      ),
                    if (error != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: ErrorStateCard(
                            message: error.toString().contains('permission-denied')
                                ? "You don't have access to inventory data. Check your Firestore rules."
                                : 'Check your connection and try again.',
                            onRetry: () => setState(() {
                              _refreshToken++;
                              _limit = _pageSize;
                            }),
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
                                child: ShimmerBox(height: 210, borderRadius: 18),
                              ),
                            ),
                          ),
                        ),
                      )
                    else if (filtered.isEmpty)
                      SliverToBoxAdapter(
                        child: EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: all.isEmpty
                              ? 'No inventory logs found'
                              : 'Nothing matches those filters',
                          message: all.isEmpty
                              ? 'Add your first stock log to see it here.'
                              : 'Try clearing the search or filters above.',
                          actionLabel: all.isEmpty && _canMutate ? 'Add Log' : null,
                          onAction: all.isEmpty && _canMutate ? () => _openForm() : null,
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, i) => StockItemCard(
                            item: filtered[i],
                            index: i,
                            canMutate: _canMutate,
                            onTap: () => _showDetails(filtered[i]),
                            onEdit: _canMutate ? () => _openForm(existing: filtered[i]) : null,
                            onDelete: _canMutate ? () => _confirmDelete(filtered[i]) : null,
                          ),
                        ),
                      ),
                    if (!reachedEnd)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.only(top: 8, bottom: 12),
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
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = _query.copyWith(search: v)),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search ingredients, category…',
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