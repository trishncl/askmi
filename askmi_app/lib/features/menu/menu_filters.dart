import '../../models/menu_item_model.dart';

const String kAllCategoriesFilter = 'All';

enum MenuStatusFilter { all, available, hidden, outOfStock }

extension MenuStatusFilterLabel on MenuStatusFilter {
  String get label => switch (this) {
        MenuStatusFilter.all => 'All',
        MenuStatusFilter.available => 'Available',
        MenuStatusFilter.hidden => 'Hidden',
        MenuStatusFilter.outOfStock => 'Out of Stock',
      };
}

enum MenuSort { alphabetical, bestSelling, recentlyUpdated, price }

extension MenuSortLabel on MenuSort {
  String get label => switch (this) {
        MenuSort.alphabetical => 'Alphabetical',
        MenuSort.bestSelling => 'Best Selling',
        MenuSort.recentlyUpdated => 'Recently Updated',
        MenuSort.price => 'Price',
      };
}

/// All list-narrowing state in one place — same shape as ProductsQuery /
/// InventoryQuery.
class MenuQuery {
  final String search;
  final String category; // kAllCategoriesFilter or a MenuCategoryModel.name
  final MenuStatusFilter status;
  final MenuSort sort;

  const MenuQuery({
    this.search = '',
    this.category = kAllCategoriesFilter,
    this.status = MenuStatusFilter.all,
    this.sort = MenuSort.alphabetical,
  });

  MenuQuery copyWith({
    String? search,
    String? category,
    MenuStatusFilter? status,
    MenuSort? sort,
  }) {
    return MenuQuery(
      search: search ?? this.search,
      category: category ?? this.category,
      status: status ?? this.status,
      sort: sort ?? this.sort,
    );
  }

  bool get hasActiveFilters =>
      search.isNotEmpty || category != kAllCategoriesFilter || status != MenuStatusFilter.all;

  /// [soldCountByName] is only consulted for [MenuSort.bestSelling] — see
  /// MenuManagementPage, which fetches it lazily (no standing counter
  /// field exists in this schema, so it's computed on demand rather than
  /// carried on every item).
  List<MenuItemModel> apply(
    List<MenuItemModel> input, {
    Map<String, int> soldCountByName = const {},
  }) {
    final q = search.trim().toLowerCase();

    var out = input.where((m) {
      if (category != kAllCategoriesFilter && m.category != category) return false;

      final matchesStatus = switch (status) {
        MenuStatusFilter.available => m.status == MenuItemStatus.available,
        MenuStatusFilter.hidden => m.status == MenuItemStatus.hidden,
        MenuStatusFilter.outOfStock => m.status == MenuItemStatus.outOfStock,
        MenuStatusFilter.all => true,
      };
      if (!matchesStatus) return false;

      if (q.isEmpty) return true;
      if (m.name.toLowerCase().contains(q)) return true;
      return m.category.toLowerCase().contains(q);
    }).toList();

    out.sort((a, b) => switch (sort) {
          MenuSort.alphabetical => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          MenuSort.price => a.price.compareTo(b.price),
          MenuSort.recentlyUpdated => b.updatedAt.compareTo(a.updatedAt),
          MenuSort.bestSelling => (soldCountByName[b.name] ?? 0).compareTo(
                soldCountByName[a.name] ?? 0,
              ),
        });
    return out;
  }
}