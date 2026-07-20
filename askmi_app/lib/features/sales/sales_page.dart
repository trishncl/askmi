import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_box.dart';
import '../../models/sale_model.dart';
import '../../providers/app_providers.dart';
import '../../repositories/sales_repository.dart';
import 'sale_form_page.dart';
import 'sales_filters.dart';
import 'transaction_details_page.dart';
import 'widgets/sales_filter_bar.dart';
import 'widgets/sales_summary_card.dart';
import 'widgets/transaction_card.dart';

/// PHASE 4, sprint 2 — Sales. First module with WRITES, so this is where
/// validation (SaleFormPage) and destructive-action confirmation live.
class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final _repo = SalesRepository();
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  SalesQuery _query = const SalesQuery();
  int _refreshToken = 0;

  /// Grows as the user scrolls. See FirestoreRepository.watchAll — one live
  /// stream over a widening window, so edits stay real-time throughout.
  static const _pageSize = 25;
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

  bool _loadingMore = false;
  bool _reachedEnd = false;

  void _maybeLoadMore() {
    if (!_scrollCtrl.hasClients || _loadingMore || _reachedEnd) return;
    final nearBottom =
        _scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 300;
    if (nearBottom) {
      setState(() => _limit += _pageSize);
    }
  }

  Future<void> _openForm({SaleModel? existing}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SaleFormPage(existing: existing)),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(existing == null ? 'Sale recorded.' : 'Sale updated.')),
      );
    }
  }

  void _openDetails(SaleModel sale) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TransactionDetailsPage(
          sale: sale,
          onEdit: () {
            Navigator.pop(context);
            _openForm(existing: sale);
          },
        ),
      ),
    );
  }

  /// Destructive, so it always confirms first and names what's being
  /// removed. Returns true only if the row should actually disappear.
  Future<bool> _confirmDelete(SaleModel sale) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: Text(
          '${Fmt.txnRef(sale.id)} — ${sale.product} '
          '(${Fmt.peso.format(sale.amount)}) will be permanently removed. '
          'This also changes your reported totals.',
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
      await _repo.delete(sale.id);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Transaction deleted.')));
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

  Future<void> _showExportSheet(List<SaleModel> rows) async {
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Nothing to export.')));
      return;
    }
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Export',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined, color: AppColors.teal),
              title: const Text('Export as CSV'),
              subtitle: Text('${rows.length} filtered transactions'),
              onTap: () {
                Navigator.pop(sheetContext);
                _exportCsv(rows);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _exportCsv(List<SaleModel> rows) async {
    try {
      final data = <List<String>>[
        ['Reference', 'Product', 'Qty', 'Unit Price', 'Amount', 'Payment', 'Branch', 'Cashier', 'Date'],
        for (final s in rows)
          [
            Fmt.txnRef(s.id),
            s.product,
            '${s.quantity}',
            s.unitPrice.toStringAsFixed(2),
            s.amount.toStringAsFixed(2),
            s.paymentMethod,
            s.branch,
            s.cashierName,
            Fmt.dateTime.format(s.createdAt),
          ],
      ];
      final csv = const ListToCsvConverter().convert(data);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/askmi_sales_export.csv');
      await file.writeAsString(csv);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: "AA's Lomi — Sales export"),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final branch = context.watch<BranchScope>().filterOrNull;
    final branchLabel = branch ?? 'All Branches';

    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Sale'),
      ),
      body: StreamBuilder<List<SaleModel>>(
        // _limit is intentionally NOT part of this key — see comment in
        // MenuManagementPage for why keying on it caused the scroll jank.
        key: ValueKey('sales_$_refreshToken'),
        stream: _repo.watchAll(
          branch: branch,
          orderByField: 'createdAt',
          limit: _limit,
        ),
        builder: (context, snap) {
          // NOT just `connectionState == waiting` — every time _limit grows,
          // watchAll(...) returns a brand-new Stream instance, and
          // StreamBuilder briefly flips back to `waiting` for that
          // resubscribe while still holding the OLD (valid) data. Treating
          // that as "loading" replaced the real list with short shimmer
          // placeholders on every "load more", which is what made the
          // scroll position clamp back near the top. Only the very first
          // load (genuinely no data yet) should show shimmer.
          final loading = snap.connectionState == ConnectionState.waiting && !snap.hasData;
          final error = snap.error;
          final all = snap.data ?? const <SaleModel>[];
          final filtered = _query.apply(all);

          final total = filtered.fold<double>(0, (sum, s) => sum + s.amount);
          final reachedEnd = all.length < _limit;

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

          return RefreshIndicator(
            color: AppColors.teal,
            onRefresh: () async {
              setState(() {
                _refreshToken++;
                _limit = _pageSize;
                _loadingMore = false;
                _reachedEnd = false;
              });
              await Future<void>.delayed(const Duration(milliseconds: 500));
            },
            child: CustomScrollView(
              controller: _scrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: SalesSummaryCard(
                      transactionCount: filtered.length,
                      totalSales: total,
                      branchLabel: branchLabel,
                      rangeLabel: _query.range.label,
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: _searchAndExport(filtered)),
                SliverToBoxAdapter(
                  child: SalesFilterBar(
                    query: _query,
                    onChanged: (q) => setState(() => _query = q),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 14)),

                if (error != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ErrorStateCard(
                        message: error.toString().contains('permission-denied')
                            ? "You don't have access to sales data. Check your Firestore rules."
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
                            child: ShimmerBox(height: 118, borderRadius: 18),
                          ),
                        ),
                      ),
                    ),
                  )
                else if (filtered.isEmpty)
                  SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.receipt_long_rounded,
                      title: all.isEmpty
                          ? 'No sales transactions found'
                          : 'Nothing matches those filters',
                      message: all.isEmpty
                          ? 'Record your first sale to see it here.'
                          : 'Try clearing the search or filters above.',
                      actionLabel: all.isEmpty ? 'Create New Sale' : null,
                      onAction: all.isEmpty ? () => _openForm() : null,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) => TransactionCard(
                        sale: filtered[i],
                        index: i,
                        onTap: () => _openDetails(filtered[i]),
                        onDelete: () => _confirmDelete(filtered[i]),
                      ),
                    ),
                  ),

                // Only show the "loading more" hint when more rows might
                // exist; otherwise it spins forever at the end of the list.
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
          );
        },
      ),
    );
  }

  Widget _searchAndExport(List<SaleModel> filtered) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = _query.copyWith(search: v)),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search transactions, products, cashiers…',
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
          ),
          const SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: IconButton(
              tooltip: 'Export',
              icon: const Icon(Icons.file_download_outlined, color: AppColors.teal),
              onPressed: () => _showExportSheet(filtered),
            ),
          ),
        ],
      ),
    );
  }
}