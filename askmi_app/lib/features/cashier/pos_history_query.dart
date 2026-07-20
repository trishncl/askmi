import '../../models/sale_transaction_model.dart';
import '../sales/sales_filters.dart' show DateRangeFilter, DateRangeFilterLabel;

export '../sales/sales_filters.dart' show DateRangeFilter, DateRangeFilterLabel;

/// Search + date-range narrowing for Sales History — same shape and same
/// client-side reasoning as SalesQuery (features/sales/sales_filters.dart),
/// just scoped to SaleTransactionModel's fields (transaction number, item
/// names) instead of SaleModel's single `product` string. Reuses
/// SalesQuery's DateRangeFilter enum directly rather than redefining an
/// identical one.
class PosHistoryQuery {
  final String search;
  final DateRangeFilter range;

  const PosHistoryQuery({this.search = '', this.range = DateRangeFilter.all});

  PosHistoryQuery copyWith({String? search, DateRangeFilter? range}) => PosHistoryQuery(
        search: search ?? this.search,
        range: range ?? this.range,
      );

  bool get hasActiveFilters => search.isNotEmpty || range != DateRangeFilter.all;

  List<SaleTransactionModel> apply(List<SaleTransactionModel> input) {
    final now = DateTime.now();
    final q = search.trim().toLowerCase();

    return input.where((s) {
      switch (range) {
        case DateRangeFilter.today:
          if (!_sameDay(s.createdAt, now)) return false;
        case DateRangeFilter.thisWeek:
          final start =
              DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
          if (s.createdAt.isBefore(start)) return false;
        case DateRangeFilter.thisMonth:
          if (s.createdAt.year != now.year || s.createdAt.month != now.month) return false;
        case DateRangeFilter.all:
          break;
      }

      if (q.isEmpty) return true;
      if (s.transactionNumber.toLowerCase().contains(q)) return true;
      return s.items.any((i) => i.name.toLowerCase().contains(q));
    }).toList();
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
