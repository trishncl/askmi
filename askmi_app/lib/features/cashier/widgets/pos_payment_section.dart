import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../pos_cart_controller.dart';

/// Payment method toggle (Cash / GCash) plus, for Cash, a tendered-amount
/// field with a live change calculation. For GCash there's nothing to type
/// — just the method itself, per the brief ("Display payment method. No
/// cash amount required.").
class PosPaymentSection extends StatelessWidget {
  final PosCartController cart;
  final ValueChanged<double> onCashReceivedChanged;

  const PosPaymentSection({
    super.key,
    required this.cart,
    required this.onCashReceivedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Method',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textDark),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _MethodChip(
                label: 'Cash',
                icon: Icons.payments_outlined,
                selected: cart.paymentMethod == PosPaymentSelection.cash,
                onTap: () => cart.setPaymentMethod(PosPaymentSelection.cash),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MethodChip(
                label: 'GCash',
                icon: Icons.qr_code_rounded,
                selected: cart.paymentMethod == PosPaymentSelection.gcash,
                onTap: () => cart.setPaymentMethod(PosPaymentSelection.gcash),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (cart.paymentMethod == PosPaymentSelection.cash) ...[
          TextField(
            key: ValueKey('cash_field_${cart.total}'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            onChanged: (v) => onCashReceivedChanged(double.tryParse(v.trim()) ?? 0),
            decoration: InputDecoration(
              labelText: 'Cash Amount',
              prefixText: '₱ ',
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Change',
                style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textGray, fontSize: 13),
              ),
              Text(
                Fmt.peso.format(cart.change),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textDark),
              ),
            ],
          ),
        ] else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.lightSuccess,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: AppColors.teal),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Confirm the GCash payment was received before checking out.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textDark),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MethodChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _MethodChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.teal.withValues(alpha: 0.12) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.teal : AppColors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: selected ? AppColors.teal : AppColors.textGray),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13,
                  color: selected ? AppColors.teal : AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
