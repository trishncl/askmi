import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_box.dart';
import '../../models/product_model.dart';
import '../../models/user_model.dart';
import '../../providers/app_providers.dart';
import '../../repositories/products_repository.dart';
import 'product_details_page.dart';
import 'product_form_page.dart';
import 'products_filters.dart';
import 'widgets/product_card.dart';
import 'widgets/products_filter_bar.dart';

/// PHASE 4 — Owner build (4th: Products). Products Management: search,
/// filters, sorting, add/edit, enable/disable (never a hard delete).
///
/// Lives inside OwnerShell AND ManagerShell — both shells supply the
/// AppBar/drawer/nav around it, so this page only owns the body. Branch
/// scoping comes entirely from `BranchScope.filterOrNull`: for an Owner
/// that's whatever the shell's selector is set to, for a Manager it's
/// permanently their own branch (see BranchScope's doc comment) — this
/// page doesn't need to know or care which, it just reads one value.
///
/// PERMISSIONS: write access (`_canWrite`) is still gated here in the UI
/// (Owner + Manager can add/edit, Cashier is view-only). firestore.rules
/// enforces the branch match server-side (`sameBranch()` on the
/// `products` collection) as defense in depth — this UI gate is not the
/// only enforcement.
class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _repo = ProductsRepository();
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  ProductsQuery _query = const ProductsQuery();
  int _refreshToken = 0;
  Timer? _debounce;

  static const _pageSize = 30;
  int _limit = _pageSize;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollCtrl.removeListener(_maybeLoadMore);
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_scrollCtrl.hasClients) return;
    final nearBottom =
        _scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 300;
    if (nearBottom) setState(() => _limit += _pageSize);
  }

  void _onSearchChanged(String value) {
    setState(() {}); // updates the clear (×) button right away
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = _query.copyWith(search: value));
    });
  }

  /// Owner sees whatever the shell's branch selector is set to (including
  /// "All Branches"). Manager/Cashier are locked to their own branch
  /// regardless of that selector — there's no UI for them to change it
  /// yet, and defaulting to "everything" for a branch-scoped role would be
  /// the wrong failure mode.
  bool _canWrite(UserModel profile) => profile.role == 'Owner' || profile.role == 'Manager';

  Future<void> _openForm({ProductModel? existing}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProductFormPage(existing: existing)),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(existing == null ? 'Product added.' : 'Product updated.')),
      );
    }
  }

  void _openDetails(ProductModel product, bool canWrite) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailsPage(
          product: product,
          onEdit: canWrite
              ? () {
                  Navigator.pop(context);
                  _openForm(existing: product);
                }
              : null,
          onToggleStatus: canWrite ? () => _toggleStatus(product) : null,
        ),
      ),
    );
  }

  /// Enable/Disable only — see ProductsRepository.setStatus. Products are
  /// never hard-deleted, so this is the sole way to take one out of
  /// circulation, and it's always reversible.
  Future<void> _toggleStatus(ProductModel product) async {
    final disabling = !product.isDisabled;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(disabling ? 'Disable product?' : 'Enable product?'),
        content: Text(
          disabling
              ? '${product.name} will be hidden from checkout at ${product.branch}. '
                  'You can re-enable it anytime.'
              : '${product.name} will become available for sale again at ${product.branch}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              disabling ? 'Disable' : 'Enable',
              style: TextStyle(color: disabling ? AppColors.danger : AppColors.teal),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _repo.setStatus(
        product.id,
        disabling ? ProductStatusValues.disabled : ProductStatusValues.available,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(disabling ? 'Product disabled.' : 'Product enabled.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().contains('permission-denied')
                ? "You don't have permission to change this."
                : 'Could not update: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserProfileProvider>().profile;
    final branch = context.watch<BranchScope>().filterOrNull;

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final canWrite = _canWrite(profile);

    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.teal,
              foregroundColor: Colors.white,
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Product'),
            )
          : null,
      body: StreamBuilder<List<ProductModel>>(
        key: ValueKey('products_${branch}_${_refreshToken}_$_limit'),
        stream: _repo.watchAll(branch: branch, orderByField: 'updatedAt', limit: _limit),
        builder: (context, snap) {
          final loading = snap.connectionState == ConnectionState.waiting;
          final error = snap.error;
          final all = snap.data ?? const <ProductModel>[];
          final filtered = _query.apply(all);
          final reachedEnd = all.length < _limit;

          return RefreshIndicator(
            color: AppColors.teal,
            onRefresh: () async {
              setState(() {
                _refreshToken++;
                _limit = _pageSize;
              });
              await Future<void>.delayed(const Duration(milliseconds: 500));
            },
            child: CustomScrollView(
              controller: _scrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _header(all.length)),
                SliverToBoxAdapter(child: _searchBar()),
                SliverToBoxAdapter(
                  child: ProductsFilterBar(
                    query: _query,
                    onChanged: (q) => setState(() => _query = q),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 14)),
                if (error != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Builder(builder: (context) {
                        // ignore: avoid_print
                        print('PRODUCTS STREAM ERROR: $error');
                        return ErrorStateCard(
                          message: error.toString().contains('permission-denied')
                              ? "You don't have access to product data. Check your Firestore rules."
                              : 'Check your connection and try again.',
                          onRetry: () => setState(() => _refreshToken++),
                        );
                      }),
                    ),
                  )
                else if (loading)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: List.generate(
                          4,
                          (_) => const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: ShimmerBox(height: 168, borderRadius: 18),
                          ),
                        ),
                      ),
                    ),
                  )
                else if (filtered.isEmpty)
                  SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: all.isEmpty ? 'No products found' : 'Nothing matches those filters',
                      message: all.isEmpty
                          ? (canWrite
                              ? 'Add your first product to see it here.'
                              : 'No products have been added for this branch yet.')
                          : 'Try clearing the search or filters above.',
                      actionLabel: all.isEmpty && canWrite ? 'Add Product' : null,
                      onAction: all.isEmpty && canWrite ? () => _openForm() : null,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final product = filtered[i];
                        return ProductCard(
                          product: product,
                          index: i,
                          onTap: () => _openDetails(product, canWrite),
                          onEdit: canWrite ? () => _openForm(existing: product) : null,
                          onToggleStatus: canWrite ? () => _toggleStatus(product) : null,
                        );
                      },
                    ),
                  ),
                if (!loading && error == null && filtered.isNotEmpty && !reachedEnd)
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
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _header(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Products',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.textDark),
          ),
          const SizedBox(height: 2),
          Text(
            '$count product${count == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 13, color: AppColors.textGray),
          ),
          const SizedBox(height: 4),
          const Text(
            'Manage product availability, pricing, and stock.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textGray),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search products, IDs, categories…',
          hintStyle: const TextStyle(fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: _searchCtrl.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    _debounce?.cancel();
                    _searchCtrl.clear();
                    setState(() => _query = _query.copyWith(search: ''));
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