import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../sales_filters.dart';

/// Horizontally scrolling filter chips: payment method, date range, sort.
/// Chips animate their fill/border on selection.
class SalesFilterBar extends StatelessWidget {
  final SalesQuery query;
  final ValueChanged<SalesQuery> onChanged;

  const SalesFilterBar({super.key, required this.query, required this.onChanged});

  static const _payments = ['Cash', 'GCash', 'Card'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _chip(
            label: query.paymentMethod ?? 'All Payments',
            icon: Icons.credit_card_rounded,
            selected: query.paymentMethod != null,
            onTap: () => _showPaymentSheet(context),
          ),
          const SizedBox(width: 8),
          _chip(
            label: query.range.label,
            icon: Icons.calendar_today_rounded,
            selected: query.range != DateRangeFilter.all,
            onTap: () => _showRangeSheet(context),
          ),
          const SizedBox(width: 8),
          _chip(
            label: query.sort.label,
            icon: Icons.swap_vert_rounded,
            selected: query.sort != SaleSort.newest,
            onTap: () => _showSortSheet(context),
          ),
          if (query.hasActiveFilters) ...[
            const SizedBox(width: 8),
            _chip(
              label: 'Clear',
              icon: Icons.close_rounded,
              selected: false,
              danger: true,
              onTap: () => onChanged(SalesQuery(search: query.search)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final accent = danger ? AppColors.danger : AppColors.teal;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? accent.withValues(alpha: 0.12) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? accent : AppColors.border,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: selected ? accent : AppColors.textGray),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? accent : AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showPaymentSheet(BuildContext context) async {
    await _sheet(
      context,
      title: 'Payment Method',
      children: [
        _option(context, 'All Payments', query.paymentMethod == null,
            () => onChanged(query.copyWith(paymentMethod: null))),
        for (final p in _payments)
          _option(context, p, query.paymentMethod == p,
              () => onChanged(query.copyWith(paymentMethod: p))),
      ],
    );
  }

  Future<void> _showRangeSheet(BuildContext context) async {
    await _sheet(
      context,
      title: 'Date Range',
      children: [
        for (final r in DateRangeFilter.values)
          _option(context, r.label, query.range == r,
              () => onChanged(query.copyWith(range: r))),
      ],
    );
  }

  Future<void> _showSortSheet(BuildContext context) async {
    await _sheet(
      context,
      title: 'Sort By',
      children: [
        for (final s in SaleSort.values)
          _option(context, s.label, query.sort == s,
              () => onChanged(query.copyWith(sort: s))),
      ],
    );
  }

  Future<void> _sheet(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.textDark,
                ),
              ),
            ),
            ...children,
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _option(BuildContext context, String label, bool selected, VoidCallback onTap) {
    return ListTile(
      dense: true,
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppColors.teal : AppColors.textDark,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check_rounded, color: AppColors.teal, size: 20)
          : null,
      onTap: () {
        onTap();
        Navigator.pop(context);
      },
    );
  }
}