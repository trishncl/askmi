import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/branch_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/report_export.dart';
import '../../core/widgets/animated_bar_chart.dart';
import '../../core/widgets/animated_line_chart.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_box.dart';
import '../../models/inventory_model.dart';
import '../../models/product_model.dart';
import '../../models/sale_model.dart';
import '../../models/user_model.dart';
import '../../providers/app_providers.dart';
import '../../repositories/inventory_repository.dart';
import '../../repositories/products_repository.dart';
import '../../repositories/sales_repository.dart';
import '../dashboard/widgets/kpi_card.dart';
import '../dashboard/widgets/section_card.dart';
import '../../models/report_model.dart';
import '../../repositories/reports_repository.dart';
import '../inventory/widgets/stock_status_badge.dart';
import '../sales/widgets/payment_badge.dart';
import 'branch_report_details_page.dart';
import 'report_filters.dart';
import 'submitted_reports_page.dart';
import 'widgets/branch_performance_card.dart';
import 'widgets/expandable_record_card.dart';

/// PHASE 4 — Owner build (Reports). Lives inside OwnerShell, so the AppBar
/// (drawer button, title "Reports", branch selector, avatar) is already
/// supplied by the shell — this page only owns the body. Deliberately
/// does NOT add a second branch selector in the body: the shell's AppBar
/// one is the single source of truth, same as every other module.
///
/// Reads directly from the `sales` / `inventory` / `products` operational
/// collections (same as Dashboard) rather than the `reports` collection —
/// `reports` is a different feature (Manager → Owner review notes, see
/// ReportModel), not raw analytics data to report on.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final _salesRepo = SalesRepository();
  final _inventoryRepo = InventoryRepository();
  final _productsRepo = ProductsRepository();
  final _reportsRepo = ReportsRepository();

  ReportTabType _tab = ReportTabType.sales;
  ReportDateRange _range = ReportDateRange.today();
  ReportFilters _filters = const ReportFilters();
  int _refreshToken = 0;

  /// Grows on scroll to cap how many cards render at once. KPIs/charts are
  /// always computed from the FULL date-range-filtered set (fetched
  /// unpaginated per branch), never just the visible page — only the
  /// rendered list is paginated, so totals are always accurate.
  static const _pageSize = 20;
  int _limit = _pageSize;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_maybeLoadMore);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_scrollCtrl.hasClients) return;
    final nearBottom =
        _scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 300;
    if (nearBottom) setState(() => _limit += _pageSize);
  }

  Future<void> _onRefresh() async {
    setState(() {
      _refreshToken++;
      _limit = _pageSize;
    });
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  void _changeTab(ReportTabType tab) {
    if (tab == _tab) return;
    setState(() {
      _tab = tab;
      _limit = _pageSize;
    });
  }

  UserModel? get _currentProfile => context.read<UserProfileProvider>().profile;

  bool get _isOwner => (_currentProfile?.role ?? '').toLowerCase() == 'owner';
  bool get _isManager => (_currentProfile?.role ?? '').toLowerCase() == 'manager';

  /// Owner: view all branches + export. Manager: view/export own branch
  /// only. Staff/Cashier: view only, no export, no cross-branch tab.
  bool get _canExport => _isOwner || _isManager;
  bool get _canViewBranchPerformance => _isOwner;

  /// Manager/Staff are locked to their own branch regardless of the
  /// shared BranchScope selector — enforced here defensively so the rule
  /// holds even before a Manager-specific shell exists to hide the
  /// selector outright.
  String? _effectiveBranch(String? scopeBranch) {
    if (_isOwner) return scopeBranch;
    return _currentProfile?.branch;
  }

  @override
  Widget build(BuildContext context) {
    final scopeBranch = context.watch<BranchScope>().filterOrNull;
    final branch = _effectiveBranch(scopeBranch);
    final branchLabel = branch ?? 'All Branches';

    // Branch Performance is Owner-only — fall back to Sales if a
    // non-Owner profile somehow lands on it (e.g. role changed mid-session).
    if (_tab == ReportTabType.branchPerformance && !_canViewBranchPerformance) {
      _tab = ReportTabType.sales;
    }

    switch (_tab) {
      case ReportTabType.sales:
        return _salesTab(branch, branchLabel);
      case ReportTabType.inventory:
        return _inventoryTab(branch, branchLabel);
      case ReportTabType.products:
        return _productsTab(branch, branchLabel);
      case ReportTabType.branchPerformance:
        return _branchPerformanceTab();
    }
  }

  // ───────────────────────── shared header pieces ─────────────────────────

  Widget _pageHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reports', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              SizedBox(height: 4),
              Text('View and export operational data', style: TextStyle(color: AppColors.textGray, fontSize: 13)),
            ],
          ),
        ),
        if (_isOwner) _submittedReportsEntryPoint(),
      ],
    );
  }

  /// These are Manager → Owner report NOTES (financial/analytics/inventory
  /// write-ups with a reviewed flag) — a different thing from the
  /// Sales/Inventory/Products/Branch Performance analytics this page shows.
  /// Kept as its own screen rather than folded in as a fifth tab so the two
  /// don't get confused with each other.
  Widget _submittedReportsEntryPoint() {
    return StreamBuilder<List<ReportModel>>(
      stream: _reportsRepo.watchAll(orderByField: 'createdAt'),
      builder: (context, snap) {
        final pending = (snap.data ?? const <ReportModel>[]).where((r) => !r.reviewed).length;
        return Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Manager Submissions',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SubmittedReportsPage()),
                ),
                icon: const Icon(Icons.mark_email_unread_outlined, color: AppColors.teal),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.lightSuccess,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (pending > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      pending > 9 ? '9+' : '$pending',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _tabBar() {
    final tabs = <(ReportTabType, String, IconData)>[
      (ReportTabType.sales, 'Sales', Icons.attach_money_rounded),
      (ReportTabType.inventory, 'Inventory', Icons.inventory_2_outlined),
      (ReportTabType.products, 'Products', Icons.restaurant_menu_rounded),
      if (_canViewBranchPerformance)
        (ReportTabType.branchPerformance, 'Branch Performance', Icons.trending_up_rounded),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final t in tabs) ...[
            _tabPill(t.$2, t.$3, t.$1),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _tabPill(String label, IconData icon, ReportTabType type) {
    final selected = _tab == type;
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: selected ? Colors.white : AppColors.teal),
      label: Text(label),
      selected: selected,
      onSelected: (_) => _changeTab(type),
      selectedColor: AppColors.teal,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textDark,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
      side: BorderSide(color: selected ? AppColors.teal : AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    );
  }

  Widget _rangeAndFilterBar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _rangeChip('Today', RangePreset.today, () => _setRange(ReportDateRange.today())),
                const SizedBox(width: 8),
                _rangeChip('This Week', RangePreset.thisWeek, () => _setRange(ReportDateRange.thisWeek())),
                const SizedBox(width: 8),
                _rangeChip('This Month', RangePreset.thisMonth, () => _setRange(ReportDateRange.thisMonth())),
                const SizedBox(width: 8),
                _rangeChip(
                  _range.preset == RangePreset.custom ? _range.label : 'Custom Range',
                  RangePreset.custom,
                  _pickCustomRange,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _filtersButton(),
      ],
    );
  }

  void _setRange(ReportDateRange range) {
    setState(() {
      _range = range;
      _limit = _pageSize;
    });
  }

  Widget _rangeChip(String label, RangePreset preset, VoidCallback onTap) {
    final selected = _range.preset == preset;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.lightSuccess,
      labelStyle: TextStyle(
        color: selected ? AppColors.teal : AppColors.textGray,
        fontWeight: FontWeight.w700,
        fontSize: 12.5,
      ),
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? AppColors.teal : AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _range.preset == RangePreset.custom
          ? DateTimeRange(start: _range.start, end: _range.end)
          : DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now),
    );
    if (picked != null) {
      _setRange(ReportDateRange.custom(picked.start, picked.end));
    }
  }

  Widget _filtersButton() {
    final count = _filters.activeCountFor(_tab);
    final disabled = _tab == ReportTabType.branchPerformance;
    return OutlinedButton.icon(
      onPressed: disabled ? null : _openFiltersSheet,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.border),
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      icon: Icon(Icons.filter_list_rounded, size: 18, color: count > 0 ? AppColors.teal : AppColors.textGray),
      label: Text(
        count > 0 ? 'Filters ($count)' : 'Filters',
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: count > 0 ? AppColors.teal : AppColors.textGray),
      ),
    );
  }

  Future<void> _openFiltersSheet() async {
    var draft = _filters;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(10)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Filters', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textDark)),
                      ),
                      TextButton(
                        onPressed: () => setSheetState(() => draft = const ReportFilters()),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _filterSheetContent(draft, (next) => setSheetState(() => draft = next)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _filters = draft;
                          _limit = _pageSize;
                        });
                        Navigator.pop(sheetContext);
                      },
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterSheetContent(ReportFilters draft, void Function(ReportFilters) onChange) {
    switch (_tab) {
      case ReportTabType.sales:
        return _chipGroup(
          'Payment Method',
          const ['All', 'Cash', 'GCash'],
          draft.paymentMethod,
          (v) => onChange(draft.copyWith(paymentMethod: v)),
        );
      case ReportTabType.inventory:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _chipGroup(
              'Category',
              const ['All', 'Perishable', 'Non-Perishable'],
              draft.inventoryCategory,
              (v) => onChange(draft.copyWith(inventoryCategory: v)),
            ),
            const SizedBox(height: 16),
            _chipGroup(
              'Stock Status',
              const ['All', 'Healthy', 'Low Stock', 'Critical', 'Overstock'],
              draft.inventoryStatus,
              (v) => onChange(draft.copyWith(inventoryStatus: v)),
            ),
          ],
        );
      case ReportTabType.products:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _chipGroup(
              'Movement',
              const ['All', 'Fast Moving', 'Normal'],
              draft.productMovement,
              (v) => onChange(draft.copyWith(productMovement: v)),
            ),
            const SizedBox(height: 16),
            _chipGroup(
              'Status',
              const ['All', 'Available', 'Disabled'],
              draft.productStatus,
              (v) => onChange(draft.copyWith(productStatus: v)),
            ),
          ],
        );
      case ReportTabType.branchPerformance:
        return const Text(
          'Branch Performance compares all branches — there are no additional filters for this tab.',
          style: TextStyle(color: AppColors.textGray),
        );
    }
  }

  Widget _chipGroup(String title, List<String> options, String value, ValueChanged<String> onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textDark)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in options)
              ChoiceChip(
                label: Text(o),
                selected: value == o,
                onSelected: (_) => onSelect(o),
                selectedColor: AppColors.lightSuccess,
                labelStyle: TextStyle(
                  color: value == o ? AppColors.teal : AppColors.textGray,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
                side: BorderSide(color: value == o ? AppColors.teal : AppColors.border),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _exportRow({required VoidCallback onCsv, required VoidCallback onPdf}) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onCsv,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.table_chart_outlined, size: 18, color: AppColors.teal),
            label: const Text('Export CSV'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPdf,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18, color: AppColors.red),
            label: const Text('Export PDF'),
          ),
        ),
      ],
    );
  }

  List<Widget> _loadingSkeleton() {
    return [
      SizedBox(
        height: 132,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 4,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, __) => const ShimmerBox(width: 168, height: 132, borderRadius: 18),
        ),
      ),
      const SizedBox(height: 18),
      const ShimmerChartCard(),
      const SizedBox(height: 18),
      const ShimmerBox(height: 100, borderRadius: 18),
      const SizedBox(height: 12),
      const ShimmerBox(height: 100, borderRadius: 18),
    ];
  }

  String _friendlyError(Object error) {
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

  /// Buckets [items] by calendar day across the active date range — daily
  /// if the range is 14 days or fewer, weekly otherwise (keeps the x-axis
  /// readable for a full month or a long custom range).
  (List<String>, List<double>) _bucketRange<T>(
    List<T> items,
    DateTime Function(T) dateOf,
    double Function(T) valueOf,
  ) {
    final days = _range.dayCount;
    if (days <= 14) {
      final labels = <String>[];
      final values = <double>[];
      for (int i = 0; i < days; i++) {
        final d = _range.start.add(Duration(days: i));
        labels.add(DateFormat('MMM d').format(d));
        values.add(
          items
              .where((it) {
                final dt = dateOf(it);
                return dt.year == d.year && dt.month == d.month && dt.day == d.day;
              })
              .fold<double>(0, (sum, it) => sum + valueOf(it)),
        );
      }
      return (labels, values);
    }
    final weeks = (days / 7).ceil();
    final labels = <String>[];
    final values = <double>[];
    for (int w = 0; w < weeks; w++) {
      final weekStart = _range.start.add(Duration(days: w * 7));
      final weekEnd = weekStart.add(const Duration(days: 6));
      labels.add(DateFormat('MMM d').format(weekStart));
      values.add(
        items
            .where((it) {
              final dt = dateOf(it);
              return !dt.isBefore(weekStart) && !dt.isAfter(weekEnd);
            })
            .fold<double>(0, (sum, it) => sum + valueOf(it)),
      );
    }
    return (labels, values);
  }

  // ───────────────────────────── Sales tab ─────────────────────────────

  Widget _salesTab(String? branch, String branchLabel) {
    return StreamBuilder<List<SaleModel>>(
      key: ValueKey('rep_sales_${branch}_$_refreshToken'),
      stream: _salesRepo.watchAll(branch: branch, orderByField: 'createdAt'),
      builder: (context, snap) {
        final loading = snap.connectionState == ConnectionState.waiting;
        final error = snap.error;
        final all = snap.data ?? const <SaleModel>[];

        final inRange = all.where((s) => _range.contains(s.createdAt)).toList();
        final filtered = _filters.paymentMethod == 'All'
            ? inRange
            : inRange.where((s) => s.paymentMethod.toLowerCase() == _filters.paymentMethod.toLowerCase()).toList();
        final visible = filtered.take(_limit).toList();

        final total = filtered.fold<double>(0, (sum, s) => sum + s.amount);
        final txCount = filtered.length;
        final avgOrder = txCount == 0 ? 0.0 : total / txCount;
        final today = DateTime.now();
        final todaysOrders = all
            .where((s) => s.createdAt.year == today.year && s.createdAt.month == today.month && s.createdAt.day == today.day)
            .length;

        final trend = _bucketRange<SaleModel>(filtered, (s) => s.createdAt, (s) => s.amount);

        final kpis = <KpiData>[
          KpiData(
            label: 'Total Sales',
            icon: Icons.payments_rounded,
            color: AppColors.teal,
            tint: AppColors.lightSuccess,
            caption: branchLabel,
            numericValue: total,
            prefix: '₱',
            decimals: 2,
          ),
          KpiData(
            label: 'Transactions',
            icon: Icons.shopping_cart_rounded,
            color: AppColors.orange,
            tint: AppColors.lightWarning,
            caption: _range.label,
            numericValue: txCount.toDouble(),
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
            label: "Today's Orders",
            icon: Icons.today_rounded,
            color: AppColors.gold,
            tint: AppColors.lightWarning,
            caption: 'Regardless of range',
            numericValue: todaysOrders.toDouble(),
          ),
        ];

        return RefreshIndicator(
          color: AppColors.teal,
          onRefresh: _onRefresh,
          child: ListView(
            controller: _scrollCtrl,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _pageHeader(),
              const SizedBox(height: 16),
              _tabBar(),
              const SizedBox(height: 14),
              _rangeAndFilterBar(),
              if (_canExport) ...[
                const SizedBox(height: 12),
                _exportRow(
                  onCsv: () => _exportSalesCsv(filtered, branchLabel),
                  onPdf: () => _exportSalesPdf(filtered, branchLabel, total, txCount, avgOrder),
                ),
              ],
              const SizedBox(height: 16),
              if (error != null)
                ErrorStateCard(message: _friendlyError(error), onRetry: () => setState(() => _refreshToken++))
              else if (loading)
                ..._loadingSkeleton()
              else ...[
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
                  title: 'Sales Trend',
                  subtitle: _range.label,
                  icon: Icons.show_chart_rounded,
                  animationIndex: 1,
                  child: SizedBox(
                    height: 200,
                    child: filtered.isEmpty
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
                Row(
                  children: [
                    const Expanded(
                      child: Text('Recent Transactions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textDark)),
                    ),
                    Text(
                      '${filtered.length} record${filtered.length == 1 ? '' : 's'}',
                      style: const TextStyle(color: AppColors.textGray, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (filtered.isEmpty)
                  const EmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'No sales transactions found',
                    message: 'Nothing recorded for this range, branch, and filters yet.',
                  )
                else
                  for (int i = 0; i < visible.length; i++)
                    ExpandableRecordCard(
                      title: visible[i].product,
                      subtitle: '${visible[i].branch} • ${Fmt.dateTime.format(visible[i].createdAt)}',
                      trailing: Fmt.peso.format(visible[i].amount),
                      badge: PaymentBadge(method: visible[i].paymentMethod),
                      index: i,
                      details: [
                        MapEntry('Reference', Fmt.txnRef(visible[i].id)),
                        MapEntry('Quantity', '${visible[i].quantity}'),
                        MapEntry('Unit Price', Fmt.peso.format(visible[i].unitPrice)),
                        MapEntry('Cashier', visible[i].cashierName),
                        MapEntry('Payment', visible[i].paymentMethod),
                      ],
                    ),
                if (!loading && error == null && visible.length < filtered.length)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2))),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _exportSalesCsv(List<SaleModel> rows, String branchLabel) {
    ReportExporter.exportCsv(
      context: context,
      fileNamePrefix: 'askmi_sales_report',
      headers: const ['Reference', 'Product', 'Qty', 'Unit Price', 'Amount', 'Payment', 'Branch', 'Cashier', 'Date'],
      rows: [
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
      ],
      shareText: 'AskMi — Sales Report ($branchLabel, ${_range.label})',
    );
  }

  void _exportSalesPdf(List<SaleModel> rows, String branchLabel, double total, int count, double avg) {
    ReportExporter.exportPdf(
      context: context,
      fileNamePrefix: 'askmi_sales_report',
      reportTitle: 'Sales Report',
      branchLabel: branchLabel,
      dateRangeLabel: _range.label,
      kpiSummary: [
        MapEntry('Total Sales', Fmt.peso.format(total)),
        MapEntry('Transactions', '$count'),
        MapEntry('Avg Order Value', Fmt.peso.format(avg)),
      ],
      tableHeaders: const ['Reference', 'Product', 'Qty', 'Amount', 'Payment', 'Branch', 'Date'],
      tableRows: [
        for (final s in rows)
          [Fmt.txnRef(s.id), s.product, '${s.quantity}', Fmt.peso.format(s.amount), s.paymentMethod, s.branch, Fmt.dateOnly.format(s.createdAt)],
      ],
    );
  }

  // ─────────────────────────── Inventory tab ───────────────────────────

  String _stockStatusText(StockStatus s) {
    switch (s) {
      case StockStatus.healthy:
        return 'Healthy';
      case StockStatus.low:
        return 'Low Stock';
      case StockStatus.critical:
        return 'Critical';
      case StockStatus.overstock:
        return 'Overstock';
    }
  }

  Widget _inventoryTab(String? branch, String branchLabel) {
    return StreamBuilder<List<InventoryModel>>(
      key: ValueKey('rep_inventory_${branch}_$_refreshToken'),
      stream: _inventoryRepo.watchAll(branch: branch, orderByField: 'date'),
      builder: (context, snap) {
        final loading = snap.connectionState == ConnectionState.waiting;
        final error = snap.error;
        final all = snap.data ?? const <InventoryModel>[];

        final inRange = all.where((i) => _range.contains(i.date)).toList();
        final filtered = inRange.where((i) {
          if (_filters.inventoryCategory != 'All' && i.category != _filters.inventoryCategory) return false;
          if (_filters.inventoryStatus != 'All' && _stockStatusText(i.status) != _filters.inventoryStatus) return false;
          return true;
        }).toList();
        final visible = filtered.take(_limit).toList();

        final critical = filtered.where((i) => i.status == StockStatus.critical).length;
        final perishable = filtered.where((i) => i.category == 'Perishable').length;
        final totalWastage = filtered.fold<double>(0, (sum, i) => sum + i.wastage);

        // Top 5 items by estimated consumption within the range.
        final consumptionByItem = <String, double>{};
        for (final i in filtered) {
          consumptionByItem[i.itemName] = (consumptionByItem[i.itemName] ?? 0) + i.estimatedConsumption;
        }
        final topConsumed = consumptionByItem.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final top5 = topConsumed.take(5).toList();

        final kpis = <KpiData>[
          KpiData(
            label: 'Inventory Logs',
            icon: Icons.assignment_rounded,
            color: AppColors.teal,
            tint: AppColors.lightSuccess,
            caption: branchLabel,
            numericValue: filtered.length.toDouble(),
          ),
          KpiData(
            label: 'Critical Items',
            icon: Icons.warning_amber_rounded,
            color: AppColors.red,
            tint: AppColors.lightDanger,
            caption: _range.label,
            numericValue: critical.toDouble(),
          ),
          KpiData(
            label: 'Perishable Logs',
            icon: Icons.eco_rounded,
            color: AppColors.gold,
            tint: AppColors.lightWarning,
            caption: _range.label,
            numericValue: perishable.toDouble(),
          ),
          KpiData(
            label: 'Total Wastage',
            icon: Icons.delete_outline_rounded,
            color: const Color(0xFF3B82F6),
            tint: const Color(0xFF3B82F6).withValues(alpha: 0.10),
            caption: _range.label,
            numericValue: totalWastage,
          ),
        ];

        return RefreshIndicator(
          color: AppColors.teal,
          onRefresh: _onRefresh,
          child: ListView(
            controller: _scrollCtrl,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _pageHeader(),
              const SizedBox(height: 16),
              _tabBar(),
              const SizedBox(height: 14),
              _rangeAndFilterBar(),
              if (_canExport) ...[
                const SizedBox(height: 12),
                _exportRow(
                  onCsv: () => _exportInventoryCsv(filtered, branchLabel),
                  onPdf: () => _exportInventoryPdf(filtered, branchLabel, critical, perishable, totalWastage),
                ),
              ],
              const SizedBox(height: 16),
              if (error != null)
                ErrorStateCard(message: _friendlyError(error), onRetry: () => setState(() => _refreshToken++))
              else if (loading)
                ..._loadingSkeleton()
              else ...[
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
                  title: 'Top Consumption',
                  subtitle: 'By item, ${_range.label.toLowerCase()}',
                  icon: Icons.local_fire_department_rounded,
                  animationIndex: 1,
                  child: SizedBox(
                    height: 200,
                    child: top5.isEmpty
                        ? const EmptyState(
                            compact: true,
                            icon: Icons.local_fire_department_rounded,
                            title: 'Nothing consumed yet',
                            message: 'Consumption appears once logs come in for this range.',
                          )
                        : AnimatedBarChart(
                            labels: [for (final e in top5) e.key],
                            values: [for (final e in top5) e.value],
                            valueFormatter: (v) => v.toStringAsFixed(0),
                          ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Inventory Records', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textDark)),
                    ),
                    Text(
                      '${filtered.length} record${filtered.length == 1 ? '' : 's'}',
                      style: const TextStyle(color: AppColors.textGray, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (filtered.isEmpty)
                  const EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'No inventory logs found',
                    message: 'Nothing recorded for this range, branch, and filters yet.',
                  )
                else
                  for (int i = 0; i < visible.length; i++)
                    ExpandableRecordCard(
                      title: visible[i].itemName,
                      subtitle: '${visible[i].branch} • ${Fmt.dateOnly.format(visible[i].date)}',
                      trailing: '${visible[i].closing.toStringAsFixed(0)} ${visible[i].unit}',
                      trailingColor: AppColors.textDark,
                      badge: StockStatusBadge(status: visible[i].status),
                      index: i,
                      details: [
                        MapEntry('Category', visible[i].category),
                        MapEntry('Opening', '${visible[i].opening.toStringAsFixed(1)} ${visible[i].unit}'),
                        MapEntry('Deliveries', '${visible[i].deliveries.toStringAsFixed(1)} ${visible[i].unit}'),
                        MapEntry('Closing', '${visible[i].closing.toStringAsFixed(1)} ${visible[i].unit}'),
                        MapEntry('Wastage', '${visible[i].wastage.toStringAsFixed(1)} ${visible[i].unit}'),
                        MapEntry('Est. Consumption', '${visible[i].estimatedConsumption.toStringAsFixed(1)} ${visible[i].unit}'),
                        if (visible[i].notes.isNotEmpty) MapEntry('Notes', visible[i].notes),
                      ],
                    ),
                if (!loading && error == null && visible.length < filtered.length)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2))),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _exportInventoryCsv(List<InventoryModel> rows, String branchLabel) {
    ReportExporter.exportCsv(
      context: context,
      fileNamePrefix: 'askmi_inventory_report',
      headers: const ['Item', 'Category', 'Branch', 'Opening', 'Deliveries', 'Closing', 'Wastage', 'Unit', 'Status', 'Date'],
      rows: [
        for (final i in rows)
          [
            i.itemName,
            i.category,
            i.branch,
            i.opening.toStringAsFixed(1),
            i.deliveries.toStringAsFixed(1),
            i.closing.toStringAsFixed(1),
            i.wastage.toStringAsFixed(1),
            i.unit,
            _stockStatusText(i.status),
            Fmt.dateOnly.format(i.date),
          ],
      ],
      shareText: 'AskMi — Inventory Report ($branchLabel, ${_range.label})',
    );
  }

  void _exportInventoryPdf(List<InventoryModel> rows, String branchLabel, int critical, int perishable, double wastage) {
    ReportExporter.exportPdf(
      context: context,
      fileNamePrefix: 'askmi_inventory_report',
      reportTitle: 'Inventory Report',
      branchLabel: branchLabel,
      dateRangeLabel: _range.label,
      kpiSummary: [
        MapEntry('Inventory Logs', '${rows.length}'),
        MapEntry('Critical Items', '$critical'),
        MapEntry('Perishable Logs', '$perishable'),
        MapEntry('Total Wastage', wastage.toStringAsFixed(1)),
      ],
      tableHeaders: const ['Item', 'Category', 'Closing', 'Status', 'Date'],
      tableRows: [
        for (final i in rows)
          [i.itemName, i.category, '${i.closing.toStringAsFixed(1)} ${i.unit}', _stockStatusText(i.status), Fmt.dateOnly.format(i.date)],
      ],
    );
  }

  // ──────────────────────────── Products tab ────────────────────────────

  String _movementLabel(String raw) => raw.toLowerCase() == 'fast_moving' ? 'Fast Moving' : 'Normal';

  String _statusLabel(ProductModel p) {
    if (p.isDisabled) return 'Disabled';
    return switch (p.badgeStatus) {
      ProductBadgeStatus.outOfStock => 'Out of Stock',
      ProductBadgeStatus.lowStock => 'Available',
      ProductBadgeStatus.available => 'Available',
      ProductBadgeStatus.disabled => 'Disabled',
    };
  }

  Widget _productsTab(String? branch, String branchLabel) {
    return StreamBuilder<List<ProductModel>>(
      key: ValueKey('rep_products_${branch}_$_refreshToken'),
      stream: _productsRepo.watchAll(branch: branch),
      builder: (context, prodSnap) {
        return StreamBuilder<List<SaleModel>>(
          key: ValueKey('rep_products_sales_${branch}_$_refreshToken'),
          stream: _salesRepo.watchAll(branch: branch, orderByField: 'createdAt'),
          builder: (context, saleSnap) {
            final loading = prodSnap.connectionState == ConnectionState.waiting ||
                saleSnap.connectionState == ConnectionState.waiting;
            final error = prodSnap.error ?? saleSnap.error;

            final allProducts = prodSnap.data ?? const <ProductModel>[];
            final allSales = saleSnap.data ?? const <SaleModel>[];
            final salesInRange = allSales.where((s) => _range.contains(s.createdAt)).toList();

            final filteredProducts = allProducts.where((p) {
              if (_filters.productMovement != 'All') {
                final wantFast = _filters.productMovement == 'Fast Moving';
                final isFast = p.movementStatus.toLowerCase() == 'fast_moving';
                if (wantFast != isFast) return false;
              }
              if (_filters.productStatus != 'All') {
                final want = _filters.productStatus;
                if (want == 'Available' && p.isDisabled) return false;
                if (want == 'Disabled' && !p.isDisabled) return false;
              }
              return true;
            }).toList();
            final visibleProducts = filteredProducts.take(_limit).toList();

            final revenueByProduct = <String, double>{};
            final unitsByProduct = <String, double>{};
            for (final s in salesInRange) {
              if (s.product.isEmpty) continue;
              revenueByProduct[s.product] = (revenueByProduct[s.product] ?? 0) + s.amount;
              unitsByProduct[s.product] = (unitsByProduct[s.product] ?? 0) + s.quantity;
            }
            final totalRevenue = salesInRange.fold<double>(0, (sum, s) => sum + s.amount);
            final totalUnits = salesInRange.fold<int>(0, (sum, s) => sum + s.quantity);
            final fastMovingCount = filteredProducts.where((p) => p.movementStatus.toLowerCase() == 'fast_moving').length;

            final topRevenue = revenueByProduct.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
            final top5Revenue = topRevenue.take(5).toList();

            final kpis = <KpiData>[
              KpiData(
                label: 'Total Products',
                icon: Icons.restaurant_menu_rounded,
                color: AppColors.teal,
                tint: AppColors.lightSuccess,
                caption: branchLabel,
                numericValue: filteredProducts.length.toDouble(),
              ),
              KpiData(
                label: 'Fast Moving',
                icon: Icons.bolt_rounded,
                color: AppColors.gold,
                tint: AppColors.lightWarning,
                caption: 'Of listed products',
                numericValue: fastMovingCount.toDouble(),
              ),
              KpiData(
                label: 'Units Sold',
                icon: Icons.shopping_bag_outlined,
                color: AppColors.orange,
                tint: AppColors.lightWarning,
                caption: _range.label,
                numericValue: totalUnits.toDouble(),
              ),
              KpiData(
                label: 'Revenue',
                icon: Icons.payments_rounded,
                color: const Color(0xFF3B82F6),
                tint: const Color(0xFF3B82F6).withValues(alpha: 0.10),
                caption: _range.label,
                numericValue: totalRevenue,
                prefix: '₱',
                decimals: 2,
              ),
            ];

            return RefreshIndicator(
              color: AppColors.teal,
              onRefresh: _onRefresh,
              child: ListView(
                controller: _scrollCtrl,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  _pageHeader(),
                  const SizedBox(height: 16),
                  _tabBar(),
                  const SizedBox(height: 14),
                  _rangeAndFilterBar(),
                  if (_canExport) ...[
                    const SizedBox(height: 12),
                    _exportRow(
                      onCsv: () => _exportProductsCsv(filteredProducts, revenueByProduct, unitsByProduct, branchLabel),
                      onPdf: () => _exportProductsPdf(
                        filteredProducts,
                        revenueByProduct,
                        unitsByProduct,
                        branchLabel,
                        totalRevenue,
                        totalUnits,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (error != null)
                    ErrorStateCard(message: _friendlyError(error), onRetry: () => setState(() => _refreshToken++))
                  else if (loading)
                    ..._loadingSkeleton()
                  else ...[
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
                      title: 'Revenue by Product',
                      subtitle: 'Top 5, ${_range.label.toLowerCase()}',
                      icon: Icons.bar_chart_rounded,
                      animationIndex: 1,
                      child: SizedBox(
                        height: 200,
                        child: top5Revenue.isEmpty
                            ? const EmptyState(
                                compact: true,
                                icon: Icons.bar_chart_rounded,
                                title: 'Nothing sold yet',
                                message: 'Product revenue appears once sales come in for this range.',
                              )
                            : AnimatedBarChart(
                                labels: [for (final e in top5Revenue) e.key],
                                values: [for (final e in top5Revenue) e.value],
                                valueFormatter: (v) => Fmt.pesoCompact.format(v),
                              ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Product Records', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textDark)),
                        ),
                        Text(
                          '${filteredProducts.length} record${filteredProducts.length == 1 ? '' : 's'}',
                          style: const TextStyle(color: AppColors.textGray, fontSize: 12),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 2, bottom: 10),
                      child: Text(
                        'Catalog listing — not date filtered. Revenue/units above are.',
                        style: TextStyle(fontSize: 11, color: AppColors.textGray, fontStyle: FontStyle.italic),
                      ),
                    ),
                    if (filteredProducts.isEmpty)
                      const EmptyState(
                        icon: Icons.restaurant_menu_rounded,
                        title: 'No products found',
                        message: 'Nothing matches this branch and filters yet.',
                      )
                    else
                      for (int i = 0; i < visibleProducts.length; i++)
                        ExpandableRecordCard(
                          title: visibleProducts[i].name,
                          subtitle: '${visibleProducts[i].category} • ${visibleProducts[i].branch}',
                          trailing: Fmt.peso.format(visibleProducts[i].price),
                          badge: _movementChip(visibleProducts[i]),
                          index: i,
                          details: [
                            MapEntry('Status', _statusLabel(visibleProducts[i])),
                            MapEntry('Movement', _movementLabel(visibleProducts[i].movementStatus)),
                            MapEntry('Current Stock', '${visibleProducts[i].stock}'),
                            MapEntry(
                              'Units Sold (${_range.label})',
                              (unitsByProduct[visibleProducts[i].name] ?? 0).toStringAsFixed(0),
                            ),
                            MapEntry(
                              'Revenue (${_range.label})',
                              Fmt.peso.format(revenueByProduct[visibleProducts[i].name] ?? 0),
                            ),
                            MapEntry('Updated', Fmt.dateTime.format(visibleProducts[i].updatedAt)),
                          ],
                        ),
                    if (!loading && error == null && visibleProducts.length < filteredProducts.length)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2))),
                      ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _movementChip(ProductModel p) {
    final isFast = p.movementStatus.toLowerCase() == 'fast_moving';
    final color = isFast ? AppColors.teal : AppColors.textGray;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(
        _movementLabel(p.movementStatus),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  void _exportProductsCsv(
    List<ProductModel> rows,
    Map<String, double> revenueByProduct,
    Map<String, double> unitsByProduct,
    String branchLabel,
  ) {
    ReportExporter.exportCsv(
      context: context,
      fileNamePrefix: 'askmi_products_report',
      headers: const ['Product', 'Category', 'Branch', 'Price', 'Stock', 'Status', 'Movement', 'Units Sold', 'Revenue'],
      rows: [
        for (final p in rows)
          [
            p.name,
            p.category,
            p.branch,
            p.price.toStringAsFixed(2),
            '${p.stock}',
            _statusLabel(p),
            _movementLabel(p.movementStatus),
            (unitsByProduct[p.name] ?? 0).toStringAsFixed(0),
            (revenueByProduct[p.name] ?? 0).toStringAsFixed(2),
          ],
      ],
      shareText: 'AskMi — Products Report ($branchLabel, ${_range.label})',
    );
  }

  void _exportProductsPdf(
    List<ProductModel> rows,
    Map<String, double> revenueByProduct,
    Map<String, double> unitsByProduct,
    String branchLabel,
    double totalRevenue,
    int totalUnits,
  ) {
    ReportExporter.exportPdf(
      context: context,
      fileNamePrefix: 'askmi_products_report',
      reportTitle: 'Products Report',
      branchLabel: branchLabel,
      dateRangeLabel: _range.label,
      kpiSummary: [
        MapEntry('Total Products', '${rows.length}'),
        MapEntry('Units Sold', '$totalUnits'),
        MapEntry('Revenue', Fmt.peso.format(totalRevenue)),
      ],
      tableHeaders: const ['Product', 'Category', 'Stock', 'Status', 'Units Sold', 'Revenue'],
      tableRows: [
        for (final p in rows)
          [
            p.name,
            p.category,
            '${p.stock}',
            _statusLabel(p),
            (unitsByProduct[p.name] ?? 0).toStringAsFixed(0),
            Fmt.peso.format(revenueByProduct[p.name] ?? 0),
          ],
      ],
    );
  }

  // ─────────────────────── Branch Performance tab ───────────────────────

  Widget _branchPerformanceTab() {
    return StreamBuilder<List<SaleModel>>(
      key: ValueKey('rep_bp_sales_$_refreshToken'),
      stream: _salesRepo.watchAll(orderByField: 'createdAt'),
      builder: (context, saleSnap) {
        return StreamBuilder<List<InventoryModel>>(
          key: ValueKey('rep_bp_inv_$_refreshToken'),
          stream: _inventoryRepo.watchAll(),
          builder: (context, invSnap) {
            final loading =
                saleSnap.connectionState == ConnectionState.waiting || invSnap.connectionState == ConnectionState.waiting;
            final error = saleSnap.error ?? invSnap.error;

            final allSales = saleSnap.data ?? const <SaleModel>[];
            final allInv = invSnap.data ?? const <InventoryModel>[];
            final salesInRange = allSales.where((s) => _range.contains(s.createdAt)).toList();
            final invInRange = allInv.where((i) => _range.contains(i.date)).toList();

            final rows = <_BranchRow>[
              for (final b in kBranchNames)
                _BranchRow(
                  branch: b,
                  sales: salesInRange.where((s) => s.branch == b).toList(),
                  inventory: invInRange.where((i) => i.branch == b).toList(),
                ),
            ]..sort((a, b) => b.revenue.compareTo(a.revenue));

            final revenueByBranch = {for (final r in rows) r.branch: r.revenue};
            final totalRevenue = rows.fold<double>(0, (sum, r) => sum + r.revenue);

            return RefreshIndicator(
              color: AppColors.teal,
              onRefresh: _onRefresh,
              child: ListView(
                controller: _scrollCtrl,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  _pageHeader(),
                  const SizedBox(height: 16),
                  _tabBar(),
                  const SizedBox(height: 14),
                  _rangeAndFilterBar(),
                  if (_canExport) ...[
                    const SizedBox(height: 12),
                    _exportRow(
                      onCsv: () => _exportBranchPerfCsv(rows),
                      onPdf: () => _exportBranchPerfPdf(rows, totalRevenue),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (error != null)
                    ErrorStateCard(message: _friendlyError(error), onRetry: () => setState(() => _refreshToken++))
                  else if (loading)
                    ..._loadingSkeleton()
                  else ...[
                    SectionCard(
                      title: 'Revenue by Branch',
                      subtitle: _range.label,
                      icon: Icons.bar_chart_rounded,
                      animationIndex: 1,
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
                                valueFormatter: (v) => Fmt.pesoCompact.format(v),
                              ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text('Branch Comparison', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textDark)),
                    const SizedBox(height: 10),
                    for (int i = 0; i < rows.length; i++)
                      BranchPerformanceCard(
                        branch: rows[i].branch,
                        revenue: rows[i].revenue,
                        transactions: rows[i].sales.length,
                        lowStockCount:
                            rows[i].inventory.where((inv) => inv.status == StockStatus.critical || inv.status == StockStatus.low).length,
                        isTopBranch: i == 0 && rows[i].revenue > 0,
                        index: i,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BranchReportDetailsPage(
                              branch: rows[i].branch,
                              range: _range,
                              sales: rows[i].sales,
                              inventory: rows[i].inventory,
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _exportBranchPerfCsv(List<_BranchRow> rows) {
    ReportExporter.exportCsv(
      context: context,
      fileNamePrefix: 'askmi_branch_performance',
      headers: const ['Branch', 'Revenue', 'Transactions', 'Avg Order Value', 'Critical/Low Stock Items'],
      rows: [
        for (final r in rows)
          [
            r.branch,
            r.revenue.toStringAsFixed(2),
            '${r.sales.length}',
            (r.sales.isEmpty ? 0 : r.revenue / r.sales.length).toStringAsFixed(2),
            '${r.inventory.where((i) => i.status == StockStatus.critical || i.status == StockStatus.low).length}',
          ],
      ],
      shareText: 'AskMi — Branch Performance (${_range.label})',
    );
  }

  void _exportBranchPerfPdf(List<_BranchRow> rows, double totalRevenue) {
    final best = rows.isEmpty ? null : rows.first;
    ReportExporter.exportPdf(
      context: context,
      fileNamePrefix: 'askmi_branch_performance',
      reportTitle: 'Branch Performance Report',
      branchLabel: 'All Branches',
      dateRangeLabel: _range.label,
      kpiSummary: [
        MapEntry('Total Revenue', Fmt.peso.format(totalRevenue)),
        MapEntry('Best Branch', best == null || best.revenue == 0 ? '—' : best.branch),
      ],
      tableHeaders: const ['Branch', 'Revenue', 'Transactions', 'Avg Order Value'],
      tableRows: [
        for (final r in rows)
          [r.branch, Fmt.peso.format(r.revenue), '${r.sales.length}', Fmt.peso.format(r.sales.isEmpty ? 0 : r.revenue / r.sales.length)],
      ],
    );
  }
}

class _BranchRow {
  final String branch;
  final List<SaleModel> sales;
  final List<InventoryModel> inventory;

  _BranchRow({required this.branch, required this.sales, required this.inventory});

  double get revenue => sales.fold<double>(0, (sum, s) => sum + s.amount);
}