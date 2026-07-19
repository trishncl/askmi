import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/animated_line_chart.dart';
import '../../core/widgets/empty_state.dart';
import '../../models/inventory_model.dart';
import '../../models/sale_model.dart';
import '../dashboard/widgets/kpi_card.dart';
import '../dashboard/widgets/section_card.dart';
import 'report_filters.dart';

/// Drill-down for a single branch, opened from the Branch Performance tab.
/// Receives already-filtered data for that branch + the active date range
/// so it doesn't re-query Firestore — the comparison tab already streamed
/// everything it needs.
class BranchReportDetailsPage extends StatelessWidget {
  final String branch;
  final ReportDateRange range;
  final List<SaleModel> sales;
  final List<InventoryModel> inventory;

  const BranchReportDetailsPage({
    super.key,
    required this.branch,
    required this.range,
    required this.sales,
    required this.inventory,
  });

  @override
  Widget build(BuildContext context) {
    final revenue = sales.fold<double>(0, (sum, s) => sum + s.amount);
    final orders = sales.length;
    final avgOrder = orders == 0 ? 0.0 : revenue / orders;
    final critical = inventory.where((i) => i.status == StockStatus.critical).toList();

    final trend = _dailyTrend(sales);

    final kpis = <KpiData>[
      KpiData(
        label: 'Revenue',
        icon: Icons.payments_rounded,
        color: AppColors.teal,
        tint: AppColors.lightSuccess,
        caption: range.label,
        numericValue: revenue,
        prefix: '₱',
        decimals: 2,
      ),
      KpiData(
        label: 'Transactions',
        icon: Icons.receipt_long_rounded,
        color: AppColors.orange,
        tint: AppColors.lightWarning,
        caption: range.label,
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
        label: 'Critical Items',
        icon: Icons.warning_amber_rounded,
        color: AppColors.red,
        tint: AppColors.lightDanger,
        caption: 'Needs restock',
        numericValue: critical.length.toDouble(),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(branch)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            children: [
              Hero(
                tag: 'branch_perf_$branch',
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.lightSuccess,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: AppColors.teal, size: 26),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(branch, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(range.label, style: const TextStyle(color: AppColors.textGray)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
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
            title: 'Revenue Trend',
            subtitle: range.label,
            icon: Icons.show_chart_rounded,
            animationIndex: 1,
            child: SizedBox(
              height: 200,
              child: sales.isEmpty
                  ? const EmptyState(
                      compact: true,
                      icon: Icons.show_chart_rounded,
                      title: 'No sales in this range',
                      message: 'The trend appears once transactions come in.',
                    )
                  : AnimatedLineChart(
                      labels: trend.$1,
                      values: trend.$2,
                      valueFormatter: (v) => Fmt.pesoCompact.format(v),
                    ),
            ),
          ),
          const SizedBox(height: 18),
          SectionCard(
            title: 'Inventory Alerts',
            subtitle: '${critical.length} item${critical.length == 1 ? '' : 's'} critical',
            icon: Icons.warning_amber_rounded,
            animationIndex: 2,
            child: critical.isEmpty
                ? const EmptyState(
                    compact: true,
                    icon: Icons.check_circle_outline_rounded,
                    title: 'Nothing critical',
                    message: 'This branch has no critical stock alerts right now.',
                  )
                : Column(
                    children: [
                      for (int i = 0; i < critical.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  critical[i].itemName,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ),
                              Text(
                                '${critical[i].closing.toStringAsFixed(0)} ${critical[i].unit} left',
                                style: const TextStyle(fontSize: 12.5, color: AppColors.danger, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Buckets [sales] by calendar day across the range. Capped at 14 daily
  /// points for readability — longer custom ranges bucket weekly instead.
  (List<String>, List<double>) _dailyTrend(List<SaleModel> sales) {
    final days = range.dayCount;
    if (days <= 14) {
      final labels = <String>[];
      final values = <double>[];
      for (int i = 0; i < days; i++) {
        final d = range.start.add(Duration(days: i));
        labels.add(DateFormat('MMM d').format(d));
        values.add(
          sales
              .where((s) => s.createdAt.year == d.year && s.createdAt.month == d.month && s.createdAt.day == d.day)
              .fold<double>(0, (sum, s) => sum + s.amount),
        );
      }
      return (labels, values);
    }
    // Weekly buckets for longer custom ranges.
    final weeks = (days / 7).ceil();
    final labels = <String>[];
    final values = <double>[];
    for (int w = 0; w < weeks; w++) {
      final weekStart = range.start.add(Duration(days: w * 7));
      final weekEnd = weekStart.add(const Duration(days: 6));
      labels.add(DateFormat('MMM d').format(weekStart));
      values.add(
        sales
            .where((s) => !s.createdAt.isBefore(weekStart) && !s.createdAt.isAfter(weekEnd))
            .fold<double>(0, (sum, s) => sum + s.amount),
      );
    }
    return (labels, values);
  }
}