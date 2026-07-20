import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_box.dart';
import '../../models/menu_category_model.dart';
import '../../models/menu_item_model.dart';
import '../../models/user_model.dart';
import '../../providers/app_providers.dart';
import '../../repositories/menu_categories_repository.dart';
import '../../repositories/menu_repository.dart';
import '../../repositories/pos_sales_repository.dart';
import 'pos_cart_controller.dart';
import 'widgets/cart_line_tile.dart';
import 'widgets/menu_item_card.dart';
import 'widgets/pos_category_chips.dart';
import 'widgets/pos_payment_section.dart';
import 'widgets/receipt_dialog.dart';

/// The Cashier's Point of Sale — the module's home screen. Tablet-first
/// split layout: a scrollable menu grid (search + category chips) on the
/// left, a live cart + payment + checkout on the right. Below ~900px wide
/// (phone), the cart moves into a bottom sheet behind a floating summary
/// bar instead of a fixed side panel, so the same screen still works on a
/// phone without a separate codepath.
///
/// Menu items come straight from Menu Management's `menuItems` collection,
/// scoped to this Cashier's OWN branch — there is no branch switcher here
/// (see CashierShell's locked branch pill) and no path to edit a menu item
/// from this screen.
class CashierPosPage extends StatefulWidget {
  const CashierPosPage({super.key});

  @override
  State<CashierPosPage> createState() => _CashierPosPageState();
}

class _CashierPosPageState extends State<CashierPosPage> {
  final _menuRepo = MenuRepository();
  final _categoriesRepo = MenuCategoriesRepository();
  final _salesRepo = PosSalesRepository();
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late final PosCartController _cart;

  String _search = '';
  String _category = kPosAllCategories;
  int _refreshToken = 0;
  bool _checkingOut = false;

  // Same widening-window pagination as every other list/grid in this app
  // (see MenuManagementPage, SalesPage) — one live stream, a growing
  // `limit`, so edits stay real-time while the grid still "pages".
  static const _pageSize = 60;
  int _limit = _pageSize;
  bool _reachedEnd = false;

  @override
  void initState() {
    super.initState();
    _cart = PosCartController();
    _scrollCtrl.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_maybeLoadMore);
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    _cart.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_scrollCtrl.hasClients) return;
    if (_reachedEnd) return; // nothing left to fetch — don't keep bumping _limit
    final maxExtent = _scrollCtrl.position.maxScrollExtent;
    // maxExtent == 0 means the grid doesn't even fill the viewport yet (few
    // items, or layout hasn't settled) — NOT "the user scrolled to the
    // bottom". Without this check, `pixels (0) >= maxExtent (0) - 300` is
    // true on every frame the grid is short, bumping _limit repeatedly for
    // no reason (harmless now that _limit isn't in the StreamBuilder's key,
    // but still pointless churn).
    if (maxExtent <= 0) return;
    final nearBottom = _scrollCtrl.position.pixels >= maxExtent - 300;
    if (nearBottom) setState(() => _limit += _pageSize);
  }

  /// Hidden items (`active == false`) never appear in the POS at all.
  /// Out-of-stock items DO still appear, disabled with a badge (see
  /// CashierMenuItemCard) rather than being filtered out — matching how
  /// PosPreviewCard already renders them in Menu Management's own preview
  /// of this same screen.
  List<MenuItemModel> _filter(List<MenuItemModel> all) {
    var items = all.where((m) => m.active).toList();
    if (_category != kPosAllCategories) {
      items = items.where((m) => m.category == _category).toList();
    }
    final q = _search.trim().toLowerCase();
    if (q.isNotEmpty) {
      items = items.where((m) => m.name.toLowerCase().contains(q)).toList();
    }
    return items;
  }

  Future<void> _checkout(UserModel profile, List<MenuItemModel> currentMenu) async {
    if (_checkingOut || !_cart.isPaymentValid) return;

    // Validate cart against the freshest menu snapshot right before
    // writing — catches an item going hidden/out-of-stock between being
    // added and checkout.
    final removed = _cart.pruneUnsellable(currentMenu, profile.branch);
    if (removed.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Removed from cart (no longer available): ${removed.join(', ')}. '
              'Review the cart and try again.',
            ),
          ),
        );
      }
      return;
    }

    setState(() => _checkingOut = true); // also guards against duplicate submissions
    try {
      final sale = await _salesRepo.checkout(
        branch: profile.branch,
        cashierUid: profile.uid,
        cashierName: profile.displayName,
        items: [for (final line in _cart.lines) line.toSaleLineItem()],
        paymentMethod: _cart.paymentMethod.storedValue,
        cashReceived: _cart.cashReceived,
      );
      _cart.clear();
      if (mounted) await showReceiptDialog(context, sale);
    } on PosCheckoutException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      // Was previously swallowed entirely — only a generic snackbar shown,
      // with no trace of what actually failed. Logging it here so the
      // real exception is visible in the browser console for debugging.
      //
      // NOTE: exceptions thrown inside `runTransaction`'s callback (in
      // PosSalesRepository.checkout) cross a JS<->Dart interop boundary on
      // web, which sometimes boxes the real error behind a generic
      // "Dart exception thrown from converted Future" wrapper. That
      // wrapper exposes the real thing via dynamic `.error`/`.stack`
      // properties, so pull those out explicitly rather than just
      // printing `e` and getting the unhelpful wrapper text.
      debugPrint('Checkout failed: $e');
      try {
        final dynamic boxed = e;
        debugPrint('Checkout failed — boxed error: ${boxed.error}');
        debugPrint('Checkout failed — boxed stack: ${boxed.stack}');
      } catch (_) {
        // e didn't have those properties — it was already the real error.
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('permission-denied')
                  ? "You don't have permission to complete this sale."
                  : 'Checkout failed. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserProfileProvider>().profile;
    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return ChangeNotifierProvider<PosCartController>.value(
      value: _cart,
      child: StreamBuilder<List<MenuCategoryModel>>(
        stream: _categoriesRepo.watchAllOrdered(),
        builder: (context, categorySnap) {
          final categories = categorySnap.data ?? const <MenuCategoryModel>[];

          return StreamBuilder<List<MenuItemModel>>(
            // _limit deliberately excluded from the key: MenuRepository
            // applies it client-side (a plain .take(limit) after the
            // snapshot arrives), so it has no effect on the underlying
            // Firestore query. Including it here used to tear down and
            // recreate the live listener on every scroll-triggered
            // page-size bump — and, since filtering shrinks the rendered
            // list enough to look "near the bottom" again, on every
            // category click too — which is what caused the menu to
            // briefly flash the permission-denied error on every filter
            // tap or reload: rapidly destroying/recreating a Firestore
            // listener on the same query is a known trigger for the SDK's
            // transient internal-state errors. Only `_refreshToken` (the
            // deliberate manual refresh) should recreate this listener.
            key: ValueKey('pos_${profile.branch}_$_refreshToken'),
            stream: _menuRepo.watchAllForBranch(
              branch: profile.branch,
              orderByField: 'displayOrder',
              limit: _limit,
            ),
            builder: (context, snap) {
              final loading = snap.connectionState == ConnectionState.waiting;
              final error = snap.error;
              final all = snap.data ?? const <MenuItemModel>[];
              final filtered = _filter(all);
              final reachedEnd = all.length < _limit;
              _reachedEnd = reachedEnd; // plain assignment: only read by
              // _maybeLoadMore's scroll callback, not part of the widget
              // tree itself, so no setState/rebuild needed here.

              final menuPanel = _MenuPanel(
                searchCtrl: _searchCtrl,
                search: _search,
                category: _category,
                categories: categories,
                items: filtered,
                allEmpty: all.isEmpty,
                loading: loading,
                error: error,
                scrollCtrl: _scrollCtrl,
                reachedEnd: reachedEnd,
                onSearchChanged: (v) => setState(() => _search = v),
                onCategoryChanged: (c) => setState(() => _category = c),
                onRefresh: () async {
                  setState(() {
                    _refreshToken++;
                    _limit = _pageSize;
                    _reachedEnd = false;
                  });
                  await Future<void>.delayed(const Duration(milliseconds: 500));
                },
                onTapItem: (item) => _cart.add(item),
              );

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isTablet = constraints.maxWidth >= 900;

                  if (isTablet) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 3, child: menuPanel),
                        const VerticalDivider(width: 1, color: AppColors.border),
                        SizedBox(
                          width: 380,
                          child: _CartPanel(
                            checkingOut: _checkingOut,
                            onCheckout: () => _checkout(profile, all),
                          ),
                        ),
                      ],
                    );
                  }

                  return Stack(
                    children: [
                      Padding(padding: const EdgeInsets.only(bottom: 72), child: menuPanel),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _MobileCartBar(
                          onTap: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.white,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                            ),
                            builder: (sheetContext) => ChangeNotifierProvider<PosCartController>.value(
                              value: _cart,
                              child: DraggableScrollableSheet(
                                initialChildSize: 0.88,
                                minChildSize: 0.5,
                                maxChildSize: 0.95,
                                expand: false,
                                builder: (context, scrollController) => _CartPanel(
                                  checkingOut: _checkingOut,
                                  onCheckout: () async {
                                    await _checkout(profile, all);
                                    if (context.mounted && _cart.isEmpty) {
                                      Navigator.of(sheetContext).maybePop();
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// Left panel: search, category chips, and the scrollable product grid.
class _MenuPanel extends StatelessWidget {
  final TextEditingController searchCtrl;
  final String search;
  final String category;
  final List<MenuCategoryModel> categories;
  final List<MenuItemModel> items;
  final bool allEmpty;
  final bool loading;
  final Object? error;
  final ScrollController scrollCtrl;
  final bool reachedEnd;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCategoryChanged;
  final Future<void> Function() onRefresh;
  final ValueChanged<MenuItemModel> onTapItem;

  const _MenuPanel({
    required this.searchCtrl,
    required this.search,
    required this.category,
    required this.categories,
    required this.items,
    required this.allEmpty,
    required this.loading,
    required this.error,
    required this.scrollCtrl,
    required this.reachedEnd,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onRefresh,
    required this.onTapItem,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg,
      child: RefreshIndicator(
        color: AppColors.teal,
        onRefresh: onRefresh,
        child: CustomScrollView(
          controller: scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  'Menu Items',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textDark),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _searchBar()),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
            SliverToBoxAdapter(
              child: PosCategoryChips(
                categories: categories,
                selected: category,
                onSelected: onCategoryChanged,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            if (error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ErrorStateCard(
                    message: error.toString().contains('permission-denied')
                        ? "You don't have access to this branch's menu. Check your Firestore rules."
                        : 'Check your connection and try again.',
                  ),
                ),
              )
            else if (loading)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 190,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.68,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => const ShimmerBox(height: double.infinity, borderRadius: 16),
                    childCount: 6,
                  ),
                ),
              )
            else if (items.isEmpty)
              SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.restaurant_menu_rounded,
                  title: allEmpty ? 'No menu items for this branch' : 'Nothing matches those filters',
                  message: allEmpty
                      ? 'Ask a Manager or Owner to add items in Menu Management.'
                      : 'Try clearing the search or category filter.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 190,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.68,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final item = items[i];
                      return Consumer<PosCartController>(
                        builder: (context, cart, _) => CashierMenuItemCard(
                          item: item,
                          quantityInCart: cart.quantityFor(item.id),
                          onTap: () => onTapItem(item),
                        ),
                      );
                    },
                    childCount: items.length,
                  ),
                ),
              ),
            if (!loading && error == null && items.isNotEmpty && !reachedEnd)
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
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: TextField(
        controller: searchCtrl,
        onChanged: onSearchChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search menu items…',
          hintStyle: const TextStyle(fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: search.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    searchCtrl.clear();
                    onSearchChanged('');
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
}

/// Right panel (or the phone bottom sheet's content): cart, order summary,
/// payment section, checkout button.
class _CartPanel extends StatelessWidget {
  final bool checkingOut;
  final VoidCallback onCheckout;

  const _CartPanel({required this.checkingOut, required this.onCheckout});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<PosCartController>();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Cart',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.textDark),
              ),
              if (!cart.isEmpty)
                TextButton.icon(
                  onPressed: cart.clear,
                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.danger),
                  label: const Text('Clear Cart', style: TextStyle(color: AppColors.danger, fontSize: 12.5)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: cart.isEmpty
                ? const _EmptyCart()
                : ListView.separated(
                    itemCount: cart.lines.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, i) {
                      final line = cart.lines[i];
                      return CartLineTile(
                        item: line,
                        onIncrement: () => cart.increment(line.menuItem.id),
                        onDecrement: () => cart.decrement(line.menuItem.id),
                        onRemove: () => cart.removeLine(line.menuItem.id),
                      );
                    },
                  ),
          ),
          const Divider(height: 24, color: AppColors.border),
          _summaryRow('Total Quantity', '${cart.totalQuantity}'),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total:',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textDark),
              ),
              Text(
                Fmt.peso.format(cart.total),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.teal),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PosPaymentSection(cart: cart, onCashReceivedChanged: cart.setCashReceived),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.border,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: (cart.isPaymentValid && !checkingOut) ? onCheckout : null,
              child: checkingOut
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shopping_cart_checkout_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text('Checkout${cart.isEmpty ? '' : '  •  ${Fmt.peso.format(cart.total)}'}'),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textGray)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
      ],
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: AppColors.lightSuccess, shape: BoxShape.circle),
            child: const Icon(Icons.shopping_cart_outlined, size: 30, color: AppColors.teal),
          ),
          const SizedBox(height: 12),
          const Text(
            'Your cart is empty.',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textDark),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap a menu item to add it here.',
            style: TextStyle(fontSize: 12, color: AppColors.textGray),
          ),
        ],
      ),
    );
  }
}

/// Phone-width floating bar summarizing the cart, tappable to open the
/// full cart/payment/checkout sheet. Only shown below the tablet breakpoint
/// — see CashierPosPage.build.
class _MobileCartBar extends StatelessWidget {
  final VoidCallback onTap;
  const _MobileCartBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<PosCartController>();
    if (cart.isEmpty) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Material(
          color: AppColors.teal,
          borderRadius: BorderRadius.circular(18),
          elevation: 6,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        '${cart.totalQuantity} item${cart.totalQuantity == 1 ? '' : 's'}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        Fmt.peso.format(cart.total),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}