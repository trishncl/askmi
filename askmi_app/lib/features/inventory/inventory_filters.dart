import '../../models/inventory_model.dart';

enum CategoryFilter { all, perishable, nonPerishable, lowStock, critical, recentlyUpdated }

extension CategoryFilterLabel on CategoryFilter {
  String get label => switch (this) {
        CategoryFilter.all => 'All',
        CategoryFilter.perishable => 'Perishable',
        CategoryFilter.nonPerishable => 'Non-Perishable',
        CategoryFilter.lowStock => 'Low Stock',
        CategoryFilter.critical => 'Critical',
        CategoryFilter.recentlyUpdated => 'Recently Updated',
      };
}

/// All list-narrowing state in one place, so the page widget stays about
/// layout and this stays testable in isolation — same shape as SalesQuery.
class InventoryQuery {
  final String search;
  final CategoryFilter category;

  const InventoryQuery({
    this.search = '',
    this.category = CategoryFilter.all,
  });

  InventoryQuery copyWith({String? search, CategoryFilter? category}) {
    return InventoryQuery(
      search: search ?? this.search,
      category: category ?? this.category,
    );
  }

  bool get hasActiveFilters => search.isNotEmpty || category != CategoryFilter.all;

  /// Runs CLIENT-SIDE on purpose — same rationale as SalesQuery.apply:
  /// Firestore has no substring search, and status/recency filters are
  /// derived values that don't exist as indexable fields.
  List<InventoryModel> apply(List<InventoryModel> input) {
    final q = search.trim().toLowerCase();
    final now = DateTime.now();

    var out = input.where((i) {
      final matchesCategory = switch (category) {
        CategoryFilter.perishable => i.category.toLowerCase() == 'perishable',
        CategoryFilter.nonPerishable => i.category.toLowerCase() == 'non-perishable',
        CategoryFilter.lowStock => i.status == StockStatus.low,
        CategoryFilter.critical => i.status == StockStatus.critical,
        CategoryFilter.recentlyUpdated => now.difference(i.date).inHours <= 48,
        CategoryFilter.all => true,
      };
      if (!matchesCategory) return false;

      if (q.isEmpty) return true;
      return i.itemName.toLowerCase().contains(q) ||
          i.category.toLowerCase().contains(q) ||
          i.branch.toLowerCase().contains(q);
    }).toList();

    // Newest first by default — matches how the shop actually reads this
    // list: "what did I log most recently".
    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }
}