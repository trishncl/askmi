import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/product_model.dart';
import '../../models/sale_model.dart';
import '../../repositories/sales_repository.dart';
import 'widgets/product_badges.dart';

/// Full record for one product, reached via a Hero transition from the
/// list. Operational stats (units sold today/this week, transaction count)
/// come straight from the `sales` collection, live — no AI estimate, no
/// cached counter that could drift from what actually happened.
class ProductDetailsPage extends StatelessWidget {
  final ProductModel product;
  final VoidCallback? onEdit;
  final Future<void> Function()? onToggleStatus;

  const ProductDetailsPage({
    super.key,
    required this.product,
    this.onEdit,
    this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Product Details'),
        actions: [
          if (onEdit != null)
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _header(),
          const SizedBox(height: 20),
          const Text('Product Information',
              style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 10),
          _infoCard([
            _row('Category', product.category),
            _row('Branch', product.branch),
            _row('Price', Fmt.peso.format(product.price)),
            _row('Stock', '${product.stock}'),
            _row('Availability', product.isDisabled ? 'Disabled' : 'Available'),
            _row('Movement', product.isFastMoving ? 'Fast Moving' : 'Normal'),
            _row('Created', Fmt.dateOnly.format(product.createdAt)),
            _row('Last Updated', Fmt.dateOnly.format(product.updatedAt)),
          ]),
          if (product.description.trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Description',
                style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark)),
            const SizedBox(height: 8),
            Text(
              product.description.trim(),
              style: const TextStyle(color: AppColors.textGray, height: 1.5),
            ),
          ],
          const SizedBox(height: 20),
          const Text('Operational Statistics',
              style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 4),
          const Text(
            'From actual recorded sales — not an estimate.',
            style: TextStyle(fontSize: 12, color: AppColors.textGray),
          ),
          const SizedBox(height: 10),
          _statsSection(),
          if (onEdit != null || onToggleStatus != null) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                if (onEdit != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                    ),
                  ),
                if (onEdit != null && onToggleStatus != null) const SizedBox(width: 12),
                if (onToggleStatus != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: product.isDisabled ? AppColors.teal : AppColors.danger,
                        side: BorderSide(
                          color: product.isDisabled ? AppColors.teal : AppColors.danger,
                        ),
                      ),
                      onPressed: () => onToggleStatus!(),
                      icon: Icon(
                        product.isDisabled
                            ? Icons.power_settings_new_rounded
                            : Icons.block_rounded,
                        size: 18,
                      ),
                      label: Text(product.isDisabled ? 'Enable' : 'Disable'),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.teal, Color(0xFF1F8377)],
        ),
      ),
      child: Column(
        children: [
          Hero(
            tag: 'product_avatar_${product.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: product.image.trim().isEmpty
                  ? Container(
                      width: 76,
                      height: 76,
                      color: Colors.white.withValues(alpha: 0.18),
                      alignment: Alignment.center,
                      child: Text(
                        product.name.isNotEmpty ? product.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 30,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : Image.network(
                      product.image,
                      width: 76,
                      height: 76,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 76,
                        height: 76,
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            product.name,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '${product.category} • ${product.branch}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _lightBadge(child: AvailabilityBadge(product: product)),
              _lightBadge(child: MovementBadge(product: product)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lightBadge({required Widget child}) {
    // Same badge widgets used on the card, on a dark gradient here — a
    // plain white backing keeps them legible without a second badge style.
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: child,
    );
  }

  Widget _infoCard(List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: rows),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textGray)),
          Text(value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        ],
      ),
    );
  }

  Widget _statsSection() {
    return StreamBuilder<List<SaleModel>>(
      stream: SalesRepository().watchByProduct(product.name, product.branch),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.2)),
          );
        }
        if (snap.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.lightDanger,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              snap.error.toString().contains('permission-denied')
                  ? "You don't have access to sales data for this product."
                  : "Couldn't load sales stats. Check your connection.",
              style: const TextStyle(color: AppColors.danger, fontSize: 12.5),
            ),
          );
        }

        final sales = snap.data ?? const <SaleModel>[];
        final now = DateTime.now();
        final startOfToday = DateTime(now.year, now.month, now.day);
        final startOfWeek = startOfToday.subtract(Duration(days: now.weekday - 1));

        final soldToday = sales
            .where((s) => !s.createdAt.isBefore(startOfToday))
            .fold<int>(0, (sum, s) => sum + s.quantity);
        final soldThisWeek = sales
            .where((s) => !s.createdAt.isBefore(startOfWeek))
            .fold<int>(0, (sum, s) => sum + s.quantity);

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _statCard('Units Sold Today', '$soldToday', Icons.today_rounded, AppColors.teal),
            _statCard('Units Sold This Week', '$soldThisWeek', Icons.date_range_rounded, AppColors.gold),
            _statCard('Current Stock', '${product.stock}', Icons.inventory_2_outlined,
                const Color(0xFF3B82F6)),
            _statCard('Transactions', '${sales.length}', Icons.receipt_long_rounded, AppColors.orange),
          ],
        );
      },
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, color: AppColors.textGray),
          ),
        ],
      ),
    );
  }
}