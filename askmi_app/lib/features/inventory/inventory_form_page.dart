import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/branch_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/gradient_button.dart';
import '../../models/inventory_model.dart';
import '../../providers/app_providers.dart';
import '../../repositories/inventory_repository.dart';

/// Add / edit a daily inventory log. Doubles as both by taking an optional
/// [existing] — same shape as SaleFormPage so the two forms feel identical.
class InventoryFormPage extends StatefulWidget {
  final InventoryModel? existing;
  const InventoryFormPage({super.key, this.existing});

  bool get isEditing => existing != null;

  @override
  State<InventoryFormPage> createState() => _InventoryFormPageState();
}

class _InventoryFormPageState extends State<InventoryFormPage> {
  static const _categories = ['Perishable', 'Non-Perishable'];
  static const _units = ['kg', 'g', 'L', 'mL', 'pcs', 'pack', 'box'];

  final _formKey = GlobalKey<FormState>();
  final _repo = InventoryRepository();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _openingCtrl;
  late final TextEditingController _deliveriesCtrl;
  late final TextEditingController _closingCtrl;
  late final TextEditingController _wastageCtrl;
  late final TextEditingController _reorderCtrl;
  late final TextEditingController _maxCtrl;
  late final TextEditingController _notesCtrl;

  late String _category;
  late String _branch;
  late String _unit;
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.itemName ?? '');
    _openingCtrl = TextEditingController(text: e == null ? '' : _num(e.opening));
    _deliveriesCtrl = TextEditingController(text: e == null ? '0' : _num(e.deliveries));
    _closingCtrl = TextEditingController(text: e == null ? '' : _num(e.closing));
    _wastageCtrl = TextEditingController(text: e == null ? '0' : _num(e.wastage));
    _reorderCtrl = TextEditingController(text: e == null || e.reorderLevel == 0 ? '' : _num(e.reorderLevel));
    _maxCtrl = TextEditingController(text: e == null || e.maxLevel == 0 ? '' : _num(e.maxLevel));
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _category = e?.category ?? _categories.first;
    _branch = e?.branch ?? kBranchNames.first;
    _unit = (e?.unit.isNotEmpty ?? false) ? e!.unit : _units.first;
    _date = e?.date ?? DateTime.now();
  }

  static String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _openingCtrl.dispose();
    _deliveriesCtrl.dispose();
    _closingCtrl.dispose();
    _wastageCtrl.dispose();
    _reorderCtrl.dispose();
    _maxCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  /// Live estimate so the user sees it before saving — always derived,
  /// never typed, so it can't disagree with opening/deliveries/closing/wastage.
  double get _computedConsumption {
    final opening = double.tryParse(_openingCtrl.text.trim()) ?? 0;
    final deliveries = double.tryParse(_deliveriesCtrl.text.trim()) ?? 0;
    final closing = double.tryParse(_closingCtrl.text.trim()) ?? 0;
    final wastage = double.tryParse(_wastageCtrl.text.trim()) ?? 0;
    final v = opening + deliveries - closing - wastage;
    return v < 0 ? 0 : v;
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
      final record = InventoryModel(
        id: widget.existing?.id ?? '',
        itemName: _nameCtrl.text.trim(),
        category: _category,
        branch: _branch,
        opening: double.parse(_openingCtrl.text.trim()),
        deliveries: double.tryParse(_deliveriesCtrl.text.trim()) ?? 0,
        closing: double.parse(_closingCtrl.text.trim()),
        wastage: double.tryParse(_wastageCtrl.text.trim()) ?? 0,
        unit: _unit,
        reorderLevel: double.tryParse(_reorderCtrl.text.trim()) ?? 0,
        maxLevel: double.tryParse(_maxCtrl.text.trim()) ?? 0,
        notes: _notesCtrl.text.trim(),
        recordedByUid: widget.existing?.recordedByUid ?? profile.uid,
        date: _date,
      );

      if (widget.isEditing) {
        await _repo.update(widget.existing!.id, record);
      } else {
        await _repo.add(record);
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

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    setState(() => _date = DateTime(date.year, date.month, date.day, _date.hour, _date.minute));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Inventory Log' : 'Add Inventory Log'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _field(
              controller: _nameCtrl,
              label: 'Ingredient Name',
              hint: 'e.g. Lomi Noodles',
              icon: Icons.inventory_2_outlined,
              textCapitalization: TextCapitalization.words,
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'Ingredient name is required.';
                if (t.length < 2) return 'Name looks too short.';
                return null;
              },
            ),
            const SizedBox(height: 14),
            _dropdown(
              label: 'Category',
              icon: Icons.category_outlined,
              value: _category,
              items: _categories,
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 14),
            _dropdown(
              label: 'Branch',
              icon: Icons.storefront_rounded,
              value: _branch,
              items: kBranchNames,
              onChanged: (v) => setState(() => _branch = v),
            ),
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Date',
                  prefixIcon: const Icon(Icons.schedule_rounded),
                  suffixIcon: const Icon(Icons.edit_calendar_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(Fmt.dateOnly.format(_date)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Stock Movement',
                style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark)),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _numField(
                    controller: _openingCtrl,
                    label: 'Opening Stock',
                    icon: Icons.inbox_outlined,
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final n = double.tryParse((v ?? '').trim());
                      if (n == null) return 'Required.';
                      if (n < 0) return 'Can\'t be negative.';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _numField(
                    controller: _deliveriesCtrl,
                    label: 'Deliveries',
                    icon: Icons.local_shipping_outlined,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _numField(
                    controller: _closingCtrl,
                    label: 'Closing Stock',
                    icon: Icons.outbox_outlined,
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final n = double.tryParse((v ?? '').trim());
                      if (n == null) return 'Required.';
                      if (n < 0) return 'Can\'t be negative.';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _numField(
                    controller: _wastageCtrl,
                    label: 'Wastage',
                    icon: Icons.delete_sweep_outlined,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _dropdown(
              label: 'Unit',
              icon: Icons.straighten_rounded,
              value: _unit,
              items: _units,
              onChanged: (v) => setState(() => _unit = v),
            ),
            const SizedBox(height: 20),
            const Text('Par Levels (optional)',
                style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark)),
            const SizedBox(height: 4),
            const Text(
              'Used to flag Low Stock / Critical / Overstock on the list.',
              style: TextStyle(fontSize: 12, color: AppColors.textGray),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _numField(
                    controller: _reorderCtrl,
                    label: 'Reorder Level',
                    icon: Icons.warning_amber_outlined,
                    required: false,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _numField(
                    controller: _maxCtrl,
                    label: 'Max Level',
                    icon: Icons.trending_up_rounded,
                    required: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'e.g. Normal day',
                prefixIcon: const Icon(Icons.sticky_note_2_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
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
                    'Estimated Consumption',
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      '${_num(_computedConsumption)} $_unit',
                      key: ValueKey(_computedConsumption),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppColors.teal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            GradientButton(
              label: widget.isEditing ? 'Save Changes' : 'Add Log',
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
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _numField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = true,
    ValueChanged<String>? onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
      onChanged: onChanged,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: validator ??
          (required
              ? (v) {
                  final n = double.tryParse((v ?? '').trim());
                  if (n == null) return 'Required.';
                  if (n < 0) return 'Can\'t be negative.';
                  return null;
                }
              : (v) {
                  if ((v ?? '').trim().isEmpty) return null;
                  final n = double.tryParse(v!.trim());
                  if (n == null) return 'Invalid number.';
                  if (n < 0) return 'Can\'t be negative.';
                  return null;
                }),
      decoration: InputDecoration(
        labelText: label,
        hintText: '0',
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

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
