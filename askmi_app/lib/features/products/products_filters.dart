import '../../models/product_model.dart';

enum StatusFilter { all, available, disabled }

extension StatusFilterLabel on StatusFilter {
  String get label => switch (this) {
        StatusFilter.all => 'All',
        StatusFilter.available => 'Available',
        StatusFilter.disabled => 'Disabled',
      };
}

enum MovementFilter { all, fastMoving, normal }

extension MovementFilterLabel on MovementFilter {
  String get label => switch (this) {
        MovementFilter.all => 'All',
        MovementFilter.fastMoving => 'Fast Moving',
        MovementFilter.normal => 'Normal',
      };
}

enum ProductSort { nameAsc, nameDesc, priceLowHigh, stockLowHigh, recentlyUpdated }

extension ProductSortLabel on ProductSort {
  String get label => switch (this) {
        ProductSort.nameAsc => 'Name A–Z',
        ProductSort.nameDesc => 'Name Z–A',
        ProductSort.priceLowHigh => 'Price',
        ProductSort.stockLowHigh => 'Stock',
        ProductSort.recentlyUpdated => 'Recently Updated',
      };
}

/// All list-narrowing state in one place — same shape as SalesQuery /
/// InventoryQuery, so the page widget stays about layout only.
class ProductsQuery {
  final String search;
  final StatusFilter status;
  final MovementFilter movement;
  final ProductSort sort;

  const ProductsQuery({
    this.search = '',
    this.status = StatusFilter.all,
    this.movement = MovementFilter.all,
    this.sort = ProductSort.nameAsc,
  });

  ProductsQuery copyWith({
    String? search,
    StatusFilter? status,
    MovementFilter? movement,
    ProductSort? sort,
  }) {
    return ProductsQuery(
      search: search ?? this.search,
      status: status ?? this.status,
      movement: movement ?? this.movement,
      sort: sort ?? this.sort,
    );
  }

  bool get hasActiveFilters =>
      search.isNotEmpty || status != StatusFilter.all || movement != MovementFilter.all;

  /// Runs CLIENT-SIDE on purpose: Firestore has no substring search, and
  /// mixing multiple equality filters with several possible sort fields
  /// would need a combinatorial set of composite indexes for very little
  /// benefit at this data scale (a shop's product catalog, not millions
  /// of rows).
  List<ProductModel> apply(List<ProductModel> input) {
    final q = search.trim().toLowerCase();

    var out = input.where((p) {
      final matchesStatus = switch (status) {
        StatusFilter.available => !p.isDisabled,
        StatusFilter.disabled => p.isDisabled,
        StatusFilter.all => true,
      };
      if (!matchesStatus) return false;

      final matchesMovement = switch (movement) {
        MovementFilter.fastMoving => p.isFastMoving,
        MovementFilter.normal => !p.isFastMoving,
        MovementFilter.all => true,
      };
      if (!matchesMovement) return false;

      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.id.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q) ||
          p.branch.toLowerCase().contains(q);
    }).toList();

    out.sort((a, b) => switch (sort) {
          ProductSort.nameAsc => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          ProductSort.nameDesc => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
          ProductSort.priceLowHigh => a.price.compareTo(b.price),
          ProductSort.stockLowHigh => a.stock.compareTo(b.stock),
          ProductSort.recentlyUpdated => b.updatedAt.compareTo(a.updatedAt),
        });
    return out;
  }
}