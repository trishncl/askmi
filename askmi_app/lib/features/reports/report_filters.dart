import '../../core/utils/formatters.dart';

/// Which report category is currently selected. Deliberately just these
/// four — per spec, no Alerts / AI Insights / Predictive / ML tabs here.
enum ReportTabType { sales, inventory, products, branchPerformance }

enum RangePreset { today, thisWeek, thisMonth, custom }

/// Today / This Week / This Month / Custom Range, resolved to a concrete
/// inclusive [start, end] so every tab filters records the same way.
class ReportDateRange {
  final RangePreset preset;
  final DateTime start; // inclusive, 00:00:00.000
  final DateTime end; // inclusive, 23:59:59.999

  const ReportDateRange._(this.preset, this.start, this.end);

  factory ReportDateRange.today() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
    return ReportDateRange._(RangePreset.today, start, end);
  }

  factory ReportDateRange.thisWeek() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Monday as the start of the week.
    final start = today.subtract(Duration(days: today.weekday - 1));
    final end = start.add(const Duration(days: 7)).subtract(const Duration(milliseconds: 1));
    return ReportDateRange._(RangePreset.thisWeek, start, end);
  }

  factory ReportDateRange.thisMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1).subtract(const Duration(milliseconds: 1));
    return ReportDateRange._(RangePreset.thisMonth, start, end);
  }

  factory ReportDateRange.custom(DateTime rangeStart, DateTime rangeEnd) {
    final s = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
    final e = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day)
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));
    return ReportDateRange._(RangePreset.custom, s, e);
  }

  bool contains(DateTime dt) => !dt.isBefore(start) && !dt.isAfter(end);

  int get dayCount => end.difference(start).inDays + 1;

  String get label {
    switch (preset) {
      case RangePreset.today:
        return 'Today';
      case RangePreset.thisWeek:
        return 'This Week';
      case RangePreset.thisMonth:
        return 'This Month';
      case RangePreset.custom:
        return '${Fmt.dateOnly.format(start)} – ${Fmt.dateOnly.format(end)}';
    }
  }
}

/// All per-tab filters live in one object so switching tabs doesn't
/// require juggling four separate pieces of state — mirrors the single
/// `SalesQuery` / `InventoryQuery` pattern used elsewhere in the app.
class ReportFilters {
  final String paymentMethod; // Sales: 'All' | 'Cash' | 'GCash'
  final String inventoryCategory; // Inventory: 'All' | 'Perishable' | 'Non-Perishable'
  final String inventoryStatus; // Inventory: 'All' | 'Healthy' | 'Low' | 'Critical' | 'Overstock'
  final String productMovement; // Products: 'All' | 'Fast Moving' | 'Normal'
  final String productStatus; // Products: 'All' | 'Available' | 'Disabled'

  const ReportFilters({
    this.paymentMethod = 'All',
    this.inventoryCategory = 'All',
    this.inventoryStatus = 'All',
    this.productMovement = 'All',
    this.productStatus = 'All',
  });

  ReportFilters copyWith({
    String? paymentMethod,
    String? inventoryCategory,
    String? inventoryStatus,
    String? productMovement,
    String? productStatus,
  }) {
    return ReportFilters(
      paymentMethod: paymentMethod ?? this.paymentMethod,
      inventoryCategory: inventoryCategory ?? this.inventoryCategory,
      inventoryStatus: inventoryStatus ?? this.inventoryStatus,
      productMovement: productMovement ?? this.productMovement,
      productStatus: productStatus ?? this.productStatus,
    );
  }

  /// How many non-default filters are active for [tab] — drives the
  /// little count badge next to the Filters button.
  int activeCountFor(ReportTabType tab) {
    switch (tab) {
      case ReportTabType.sales:
        return paymentMethod == 'All' ? 0 : 1;
      case ReportTabType.inventory:
        return (inventoryCategory == 'All' ? 0 : 1) + (inventoryStatus == 'All' ? 0 : 1);
      case ReportTabType.products:
        return [productMovement, productStatus].where((f) => f != 'All').length;
      case ReportTabType.branchPerformance:
        return 0; // Cross-branch comparison — nothing to filter.
    }
  }
}