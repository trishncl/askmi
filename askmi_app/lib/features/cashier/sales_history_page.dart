import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_box.dart';
import '../../models/sale_transaction_model.dart';
import '../../providers/app_providers.dart';
import '../../repositories/pos_sales_repository.dart';
import '../sales/widgets/payment_badge.dart';
import 'pos_history_query.dart';
import 'pos_transaction_details_page.dart';

/// Read-only history of the CURRENT cashier's own POS transactions — never
/// other cashiers' sales, and never the Owner/Manager's manual "Sales"
/// module. `PosSalesRepository.watchOwnTransactions` already scopes the
/// query to `cashierUid`; this page only adds search/date narrowing and
/// list chrome.
class SalesHistoryPage extends StatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  final _repo = PosSalesRepository();
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  PosHistoryQuery _query = const PosHistoryQuery();
  int _refreshToken = 0;

  // Same widening-window pagination as SalesPage — one live stream, a
  // growing `limit`, so edits stay real-time while the list still "pages".
  static const _pageSize = 25;
  int _limit = _pageSize;

  // Set from the StreamBuilder each time data arrives. Once true, there is
  // nothing more to fetch, so the scroll listener must stop bumping _limit —
  // otherwise a short list (fewer docs than a page) keeps the scroll
  // position "near bottom" on every micro-scroll, firing setState dozens of
  // times a second and resubscribing the stream each time.
  bool _reachedEnd = false;

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
    if (!_scrollCtrl.hasClients || _reachedEnd) return;
    final nearBottom =
        _scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 300;
    if (nearBottom) setState(() => _limit += _pageSize);
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserProfileProvider>().profile;
    if (profile == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: StreamBuilder<List<SaleTransactionModel>>(
        key: ValueKey('pos_history_$_refreshToken'),
        stream: _repo.watchOwnTransactions(cashierUid: profile.uid, limit: _limit),
        builder: (context, snap) {
          final loading = snap.connectionState == ConnectionState.waiting;
          final error = snap.error;
          final all = snap.data ?? const <SaleTransactionModel>[];
          final filtered = _query.apply(all);
          final total = filtered.fold<double>(0, (sum, s) => sum + s.total);
          final reachedEnd = all.length < _limit;
          if (!loading && error == null) _reachedEnd = reachedEnd;

          return RefreshIndicator(
            color: AppColors.teal,
            onRefresh: () async {
              setState(() {
                _refreshToken++;
                _limit = _pageSize;
                _reachedEnd = false;
              });
              await Future<void>.delayed(const Duration(milliseconds: 500));
            },
            child: CustomScrollView(
              controller: _scrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _summary(filtered.length, total)),
                SliverToBoxAdapter(child: _searchBar()),
                SliverToBoxAdapter(child: _dateChips()),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                if (error != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ErrorStateCard(
                        message: error.toString().contains('permission-denied')
                            ? "You don't have access to your sales history. Check your Firestore rules."
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
                            child: ShimmerBox(height: 96, borderRadius: 18),
                          ),
                        ),
                      ),
                    ),
                  )
                else if (filtered.isEmpty)
                  SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.receipt_long_rounded,
                      title: all.isEmpty ? 'No sales yet' : 'Nothing matches those filters',
                      message: all.isEmpty
                          ? 'Transactions you complete at the POS will show up here.'
                          : 'Try clearing the search or date filter above.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) => _HistoryCard(
                        sale: filtered[i],
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PosTransactionDetailsPage(sale: filtered[i]),
                          ),
                        ),
                      ),
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
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _summary(int count, double total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.teal,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your Sales',
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 12.5)),
                const SizedBox(height: 4),
                Text('$count transaction${count == 1 ? '' : 's'}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              ],
            ),
            Text(
              Fmt.peso.format(total),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = _query.copyWith(search: v)),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search by transaction # or item…',
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

  Widget _dateChips() {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final r in DateRangeFilter.values) ...[
            _chip(r),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _chip(DateRangeFilter range) {
    final selected = _query.range == range;
    return Material(
      color: selected ? AppColors.teal.withValues(alpha: 0.12) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _query = _query.copyWith(range: range)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.teal : AppColors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Text(
            range.label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? AppColors.teal : AppColors.textDark,
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final SaleTransactionModel sale;
  final VoidCallback onTap;

  const _HistoryCard({required this.sale, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final itemsPreview = sale.items.map((i) => '${i.quantity}× ${i.name}').join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: AppColors.lightSuccess,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: AppColors.teal, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            sale.transactionNumber,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                          ),
                          const SizedBox(width: 8),
                          PaymentBadge(method: sale.paymentMethod),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        itemsPreview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.textGray),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Fmt.dateTime.format(sale.createdAt),
                        style: const TextStyle(fontSize: 11, color: AppColors.textGray),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  Fmt.peso.format(sale.total),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.teal),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}