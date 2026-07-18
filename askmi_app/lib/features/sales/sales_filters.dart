import '../../models/sale_model.dart';

enum DateRangeFilter { all, today, thisWeek, thisMonth }

enum SaleSort { newest, oldest, highest, lowest }

extension DateRangeFilterLabel on DateRangeFilter {
  String get label => switch (this) {
        DateRangeFilter.all => 'All Time',
        DateRangeFilter.today => 'Today',
        DateRangeFilter.thisWeek => 'This Week',
        DateRangeFilter.thisMonth => 'This Month',
      };
}

extension SaleSortLabel on SaleSort {
  String get label => switch (this) {
        SaleSort.newest => 'Newest First',
        SaleSort.oldest => 'Oldest First',
        SaleSort.highest => 'Highest Amount',
        SaleSort.lowest => 'Lowest Amount',
      };
}

/// All list-narrowing state in one place, so the page widget stays about
/// layout and this stays testable in isolation.
class SalesQuery {
  final String search;
  final String? paymentMethod; // null = all
  final DateRangeFilter range;
  final SaleSort sort;

  const SalesQuery({
    this.search = '',
    this.paymentMethod,
    this.range = DateRangeFilter.all,
    this.sort = SaleSort.newest,
  });

  SalesQuery copyWith({
    String? search,
    Object? paymentMethod = _sentinel,
    DateRangeFilter? range,
    SaleSort? sort,
  }) {
    return SalesQuery(
      search: search ?? this.search,
      // Sentinel lets callers explicitly clear paymentMethod back to null,
      // which a plain `String?` parameter can't distinguish from "unset".
      paymentMethod: identical(paymentMethod, _sentinel)
          ? this.paymentMethod
          : paymentMethod as String?,
      range: range ?? this.range,
      sort: sort ?? this.sort,
    );
  }

  static const _sentinel = Object();

  bool get hasActiveFilters =>
      search.isNotEmpty ||
      paymentMethod != null ||
      range != DateRangeFilter.all ||
      sort != SaleSort.newest;

  /// Applies search, payment, and date filters, then sorts.
  ///
  /// Runs CLIENT-SIDE on purpose: Firestore has no substring search, and
  /// combining several `where` clauses with `orderBy` would need a new
  /// composite index per combination. Fine for the volumes this shop will
  /// see; if `sales` ever reaches tens of thousands of rows, this needs to
  /// move to a search service (Algolia/Typesense) rather than more indexes.
  List<SaleModel> apply(List<SaleModel> input) {
    final now = DateTime.now();
    final q = search.trim().toLowerCase();

    var out = input.where((s) {
      if (paymentMethod != null &&
          s.paymentMethod.toLowerCase() != paymentMethod!.toLowerCase()) {
        return false;
      }

      switch (range) {
        case DateRangeFilter.today:
          if (!_sameDay(s.createdAt, now)) return false;
        case DateRangeFilter.thisWeek:
          final start = DateTime(now.year, now.month, now.day)
              .subtract(Duration(days: now.weekday - 1));
          if (s.createdAt.isBefore(start)) return false;
        case DateRangeFilter.thisMonth:
          if (s.createdAt.year != now.year || s.createdAt.month != now.month) {
            return false;
          }
        case DateRangeFilter.all:
          break;
      }

      if (q.isEmpty) return true;
      return s.product.toLowerCase().contains(q) ||
          s.cashierName.toLowerCase().contains(q) ||
          s.branch.toLowerCase().contains(q) ||
          s.id.toLowerCase().contains(q);
    }).toList();

    out.sort((a, b) => switch (sort) {
          SaleSort.newest => b.createdAt.compareTo(a.createdAt),
          SaleSort.oldest => a.createdAt.compareTo(b.createdAt),
          SaleSort.highest => b.amount.compareTo(a.amount),
          SaleSort.lowest => a.amount.compareTo(b.amount),
        });

    return out;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}