import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/branch_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/gradient_button.dart';
import '../../models/sale_model.dart';
import '../../providers/app_providers.dart';
import '../../repositories/sales_repository.dart';
import '../../core/widgets/safe_dropdown_form_field.dart';

/// Add / edit a sale. Doubles as both by taking an optional [existing].
///
/// Validation lives here rather than in the repository so errors can be
/// attached to the specific field that's wrong. The repository stays a dumb
/// data-access layer — that separation is what lets Phase 5's POS reuse it
/// without inheriting a form's opinions.
class SaleFormPage extends StatefulWidget {
  final SaleModel? existing;
  const SaleFormPage({super.key, this.existing});

  bool get isEditing => existing != null;

  @override
  State<SaleFormPage> createState() => _SaleFormPageState();
}

class _SaleFormPageState extends State<SaleFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _repo = SalesRepository();

  late final TextEditingController _productCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;

  late String _branch;
  late String _paymentMethod;
  late DateTime _createdAt;
  bool _saving = false;

  /// True for any non-Owner (Manager/Cashier) — see [isRoleBranchLocked].
  bool _branchLocked = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final profile = context.read<UserProfileProvider>().profile;
    _branchLocked = profile != null && isRoleBranchLocked(profile.role);
    _productCtrl = TextEditingController(text: e?.product ?? '');
    _qtyCtrl = TextEditingController(text: e == null ? '1' : '${e.quantity}');
    _priceCtrl = TextEditingController(
        text: e == null ? '' : e.unitPrice.toStringAsFixed(2));
    _branch = e?.branch ?? (_branchLocked ? profile!.branch : kBranchNames.first);
    _paymentMethod = e?.paymentMethod ?? 'Cash';
    _createdAt = e?.createdAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _productCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  /// Live total so the user sees the computed amount before saving —
  /// `amount` is derived, never typed, so it can't disagree with qty × price.
  double get _computedAmount {
    final q = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final p = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    return q * p;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final profile = context.read<UserProfileProvider>().profile;
    if (profile == null) {
      _snack('Your profile could not be read. Sign out and back in.');
      return;
    }

    setState(() => _saving = true);
    try {
      final qty = int.parse(_qtyCtrl.text.trim());
      final price = double.parse(_priceCtrl.text.trim());

      final sale = SaleModel(
        id: widget.existing?.id ?? '',
        product: _productCtrl.text.trim(),
        quantity: qty,
        unitPrice: price,
        amount: qty * price,
        paymentMethod: _paymentMethod,
        branch: _branch,
        // On edit, preserve who ORIGINALLY rang up the sale — overwriting it
        // with whoever edited would destroy the accountability trail.
        cashierUid: widget.existing?.cashierUid ?? profile.uid,
        cashierName: widget.existing?.cashierName ?? profile.name,
        createdAt: _createdAt,
      );

      if (widget.isEditing) {
        await _repo.update(widget.existing!.id, sale);
      } else {
        await _repo.add(sale);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _snack(_friendlyWriteError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _friendlyWriteError(Object e) {
    final s = e.toString();
    if (s.contains('permission-denied')) {
      return "You don't have permission to save this. Check your Firestore rules.";
    }
    return 'Could not save: $e';
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _createdAt,
      firstDate: DateTime(2020),
      // No future-dated sales: a transaction that hasn't happened yet would
      // silently skew every "today"/"this week" total on the dashboard.
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_createdAt),
    );
    if (!mounted) return;

    setState(() {
      _createdAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _createdAt.hour,
        time?.minute ?? _createdAt.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Sale' : 'New Sale'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _field(
              controller: _productCtrl,
              label: 'Product',
              hint: 'e.g. Lomi Special',
              icon: Icons.lunch_dining_rounded,
              textCapitalization: TextCapitalization.words,
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'Product name is required.';
                if (t.length < 2) return 'Product name looks too short.';
                return null;
              },
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _field(
                    controller: _qtyCtrl,
                    label: 'Quantity',
                    hint: '1',
                    icon: Icons.numbers_rounded,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      if (n == null) return 'Enter a whole number.';
                      if (n <= 0) return 'Must be at least 1.';
                      if (n > 1000) return 'That looks like a typo.';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    controller: _priceCtrl,
                    label: 'Unit Price',
                    hint: '0.00',
                    icon: Icons.sell_outlined,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final n = double.tryParse((v ?? '').trim());
                      if (n == null) return 'Enter a valid amount.';
                      if (n <= 0) return 'Must be greater than 0.';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SafeDropdownFormField(
              label: 'Branch',
              icon: Icons.storefront_rounded,
              value: _branch,
              items: kBranchNames,
              fallback: kBranchNames.first,
              onChanged: (v) => setState(() => _branch = v),
            ),
            const SizedBox(height: 14),
            SafeDropdownFormField(
              label: 'Payment Method',
              icon: Icons.credit_card_rounded,
              value: _paymentMethod,
              items: const ['Cash', 'GCash', 'Card'],
              fallback: 'Cash',
              onChanged: (v) => setState(() => _paymentMethod = v),
            ),
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _pickDateTime,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Date & Time',
                  prefixIcon: const Icon(Icons.schedule_rounded),
                  suffixIcon: const Icon(Icons.edit_calendar_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(Fmt.dateTime.format(_createdAt)),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.lightSuccess,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Amount',
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      Fmt.peso.format(_computedAmount),
                      key: ValueKey(_computedAmount),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: AppColors.teal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            GradientButton(
              label: widget.isEditing ? 'Save Changes' : 'Record Sale',
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      // Errors appear as soon as a field is touched and left invalid,
      // rather than only on submit.
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // ignore: unused_element
  Widget _dropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
      items: [
        for (final i in items) DropdownMenuItem(value: i, child: Text(i)),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}