import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/branch_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/animated_bar_chart.dart';
import '../../core/widgets/animated_line_chart.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_box.dart';
import '../../models/inventory_model.dart';
import '../../models/sale_model.dart';
import '../../providers/app_providers.dart';
import '../../repositories/inventory_repository.dart';
import '../../repositories/sales_repository.dart';
import 'widgets/fast_moving_tile.dart';
import 'widgets/kpi_card.dart';
import 'widgets/section_card.dart';
import 'widgets/transaction_tile.dart';
import 'widgets/welcome_header.dart';

/// PHASE 4, sprint 1 — Dashboard. Read-only by design: every number here
/// is DERIVED from the sales/inventory collections rather than stored
/// separately, so there's no second copy of the truth to drift out of
/// sync, and nothing on this screen can corrupt data.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _salesRepo = SalesRepository();
  final _inventoryRepo = InventoryRepository();

  /// Bumping this rebuilds the StreamBuilders, which is what pull-to-refresh
  /// does. Firestore streams are already live, so this is mostly a UX
  /// affordance — it also re-runs the query if an earlier one errored.
  int _refreshToken = 0;

  final _peso = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
  final _pesoCompact = NumberFormat.compactCurrency(symbol: '₱', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final branch = context.watch<BranchScope>().filterOrNull;
    final scopeLabel = branch ?? 'Organization-wide overview';

    return RefreshIndicator(
      color: AppColors.teal,
      onRefresh: () async {
        setState(() => _refreshToken++);
        await Future<void>.delayed(const Duration(milliseconds: 600));
      },
      child: StreamBuilder<List<SaleModel>>(
        key: ValueKey('sales_$_refreshToken'),
        stream: _salesRepo.watchAll(branch: branch, orderByField: 'createdAt'),
        builder: (context, salesSnap) {
          return StreamBuilder<List<InventoryModel>>(
            key: ValueKey('inventory_$_refreshToken'),
            stream: _inventoryRepo.watchAll(branch: branch),
            builder: (context, invSnap) {
              final loading = salesSnap.connectionState == ConnectionState.waiting ||
                  invSnap.connectionState == ConnectionState.waiting;
              final error = salesSnap.error ?? invSnap.error;

              return ListView(
                // Always scrollable so pull-to-refresh works even when the
                // content is shorter than the viewport (i.e. empty states).
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                children: [
                  WelcomeHeader(roleLabel: 'Owner', scopeLabel: scopeLabel),
                  const SizedBox(height: 18),
                  if (error != null)
                    ErrorStateCard(
                      message: _friendlyError(error),
                      onRetry: () => setState(() => _refreshToken++),
                    )
                  else if (loading)
                    ..._loadingSkeleton()
                  else
                    ..._content(
                      sales: salesSnap.data ?? const [],
                      inventory: invSnap.data ?? const [],
                      branch: branch,
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String _friendlyError(Object error) {
    // ignore: avoid_print
    print('DASHBOARD STREAM ERROR: $error');
    final s = error.toString();
    if (s.contains('permission-denied')) {
      return "You don't have access to this data. Check your Firestore rules.";
    }
    if (s.contains('failed-precondition') || s.contains('index')) {
      return 'This query needs a Firestore index. Open the debug console — '
          'Firebase logs a direct link to create it.';
    }
    return 'Check your connection and try again.';
  }

  List<Widget> _loadingSkeleton() {
    return [
      SizedBox(
        height: 128,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, __) => const ShimmerBox(width: 168, height: 128, borderRadius: 18),
        ),
      ),
      const SizedBox(height: 18),
      const ShimmerChartCard(),
      const SizedBox(height: 18),
      const ShimmerChartCard(),
    ];
  }

  List<Widget> _content({
    required List<SaleModel> sales,
    required List<InventoryModel> inventory,
    required String? branch,
  }) {
    final revenue = sales.fold<double>(0, (sum, s) => sum + s.amount);
    final orders = sales.length;
    final avgOrder = orders == 0 ? 0.0 : revenue / orders;

    final lowStock = inventory.where((i) => i.percentRemaining < 0.25).toList();
    final critical = inventory.where((i) => i.percentRemaining < 0.15).length;

    final revenueByBranch = <String, double>{for (final b in kBranchNames) b: 0};
    for (final s in sales) {
      if (revenueByBranch.containsKey(s.branch)) {
        revenueByBranch[s.branch] = revenueByBranch[s.branch]! + s.amount;
      }
    }
    final bestBranch = revenueByBranch.entries.fold<MapEntry<String, double>?>(
      null,
      (best, e) => (best == null || e.value > best.value) ? e : best,
    );

    final trend = _last7Days(sales);
    final topProducts = _topProducts(sales);
    final recent = sales.take(5).toList();

    final kpis = <KpiData>[
      KpiData(
        label: 'Total Revenue',
        icon: Icons.payments_rounded,
        color: AppColors.teal,
        tint: AppColors.lightSuccess,
        caption: branch == null ? 'All branches' : branch,
        numericValue: revenue,
        prefix: '₱',
        decimals: 2,
      ),
      KpiData(
        label: 'Total Orders',
        icon: Icons.shopping_cart_rounded,
        color: AppColors.orange,
        tint: AppColors.lightWarning,
        caption: 'All time',
        numericValue: orders.toDouble(),
      ),
      KpiData(
        label: 'Avg Order Value',
        icon: Icons.trending_up_rounded,
        color: const Color(0xFF3B82F6),
        tint: const Color(0xFF3B82F6).withValues(alpha: 0.10),
        caption: 'Per transaction',
        numericValue: avgOrder,
        prefix: '₱',
        decimals: 2,
      ),
      KpiData(
        label: 'Active Alerts',
        icon: Icons.notifications_active_rounded,
        color: AppColors.gold,
        tint: AppColors.lightWarning,
        caption: 'Needs attention',
        numericValue: critical.toDouble(),
      ),
      KpiData(
        label: 'Low-Stock Items',
        icon: Icons.warning_amber_rounded,
        color: AppColors.red,
        tint: AppColors.lightDanger,
        caption: 'Below 25% remaining',
        numericValue: lowStock.length.toDouble(),
      ),
      KpiData(
        label: 'Best Branch',
        icon: Icons.emoji_events_rounded,
        color: AppColors.teal,
        tint: AppColors.lightSuccess,
        caption: bestBranch == null || bestBranch.value == 0
            ? 'No sales yet'
            : _peso.format(bestBranch.value),
        textValue: bestBranch == null || bestBranch.value == 0 ? '—' : bestBranch.key,
      ),
    ];

    return [
      SizedBox(
        height: 132,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: kpis.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, i) => KpiCard(data: kpis[i], index: i),
        ),
      ),
      const SizedBox(height: 18),

      SectionCard(
        title: 'Daily Sales Trend',
        subtitle: 'Last 7 days',
        icon: Icons.show_chart_rounded,
        animationIndex: 1,
        child: SizedBox(
          height: 210,
          child: sales.isEmpty
              ? const EmptyState(
                  compact: true,
                  icon: Icons.show_chart_rounded,
                  title: 'No sales recorded yet',
                  message: 'The trend appears once transactions come in.',
                )
              : AnimatedLineChart(
                  labels: trend.$1,
                  values: trend.$2,
                  valueFormatter: (v) => _pesoCompact.format(v),
                ),
        ),
      ),
      const SizedBox(height: 18),

      SectionCard(
        title: 'Sales by Branch',
        subtitle: 'Revenue comparison',
        icon: Icons.storefront_rounded,
        animationIndex: 2,
        child: SizedBox(
          height: 220,
          child: revenueByBranch.values.every((v) => v == 0)
              ? const EmptyState(
                  compact: true,
                  icon: Icons.storefront_rounded,
                  title: 'No branch revenue yet',
                  message: 'Each branch appears here once it records a sale.',
                )
              : AnimatedBarChart(
                  labels: revenueByBranch.keys.toList(),
                  values: revenueByBranch.values.toList(),
                  valueFormatter: (v) => _pesoCompact.format(v),
                ),
        ),
      ),
      const SizedBox(height: 18),

      SectionCard(
        title: 'Fast Moving Products',
        subtitle: 'Top 5 by quantity sold',
        icon: Icons.inventory_2_rounded,
        animationIndex: 3,
        child: topProducts.isEmpty
            ? const EmptyState(
                compact: true,
                icon: Icons.inventory_2_rounded,
                title: 'Nothing sold yet',
                message: 'Your best sellers will be ranked here.',
              )
            : Column(
                children: [
                  for (int i = 0; i < topProducts.length; i++)
                    FastMovingTile(
                      rank: i + 1,
                      name: topProducts[i].key,
                      quantity: topProducts[i].value,
                      index: i,
                    ),
                ],
              ),
      ),
      const SizedBox(height: 18),

      SectionCard(
        title: 'Recent Transactions',
        subtitle: 'Last 5 sales',
        icon: Icons.receipt_long_rounded,
        animationIndex: 4,
        trailing: TextButton(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('The full Sales list is the next sprint.')),
          ),
          child: const Text('View All'),
        ),
        child: recent.isEmpty
            ? const EmptyState(
                compact: true,
                icon: Icons.receipt_long_rounded,
                title: 'No transactions yet',
                message: 'Sales recorded at any branch will show up here.',
              )
            : Column(
                children: [
                  for (int i = 0; i < recent.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    TransactionTile(sale: recent[i], index: i),
                  ],
                ],
              ),
      ),
    ];
  }

  /// Buckets the last 7 calendar days (oldest → newest) by revenue.
  (List<String>, List<double>) _last7Days(List<SaleModel> sales) {
    final now = DateTime.now();
    final days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    final labels = days.map((d) => DateFormat('E').format(d)).toList();
    final values = days.map((d) {
      return sales
          .where((s) =>
              s.createdAt.year == d.year &&
              s.createdAt.month == d.month &&
              s.createdAt.day == d.day)
          .fold<double>(0, (sum, s) => sum + s.amount);
    }).toList();
    return (labels, values);
  }

  /// Top 5 products by total quantity sold.
  List<MapEntry<String, int>> _topProducts(List<SaleModel> sales) {
    final counts = <String, int>{};
    for (final s in sales) {
      if (s.product.isEmpty) continue;
      counts[s.product] = (counts[s.product] ?? 0) + s.quantity;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(5).toList();
  }
}