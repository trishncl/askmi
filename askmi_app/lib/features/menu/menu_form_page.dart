// ignore_for_file: unused_import
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/branch_constants.dart';
import '../../core/constants/menu_category_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_button.dart';
import '../../models/menu_category_model.dart';
import '../../models/menu_item_model.dart';
import '../../models/product_model.dart';
import '../../providers/app_providers.dart';
import '../../repositories/menu_repository.dart';
import '../../repositories/products_repository.dart';
import 'widgets/pos_preview_card.dart';
class MenuFormPage extends StatefulWidget {
  final MenuItemModel? existing;
  final List<MenuCategoryModel> categories;
  final int nextDisplayOrder;

  const MenuFormPage({
    super.key,
    this.existing,
    required this.categories,
    required this.nextDisplayOrder,
  });

  bool get isEditing => existing != null;

  @override
  State<MenuFormPage> createState() => _MenuFormPageState();
}

class _MenuFormPageState extends State<MenuFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _repo = MenuRepository();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _imageCtrl;
  late final TextEditingController _orderCtrl;

  String? _category;
  late Set<String> _branches;
  late bool _active;
  late bool _outOfStock;

  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _descriptionCtrl = TextEditingController(text: e?.description ?? '');
    _priceCtrl = TextEditingController(text: e == null ? '' : _trimZeros(e.price));
    _imageCtrl = TextEditingController(text: e?.image ?? '');
    _orderCtrl = TextEditingController(text: '${e?.displayOrder ?? widget.nextDisplayOrder}');
    _category = e?.category ?? (widget.categories.isNotEmpty ? widget.categories.first.name : null);
    _branches = {...(e?.branches ?? const <String>[])};
    _active = e?.active ?? true;
    _outOfStock = e?.outOfStock ?? false;

    for (final c in [_nameCtrl, _descriptionCtrl, _priceCtrl, _imageCtrl, _orderCtrl]) {
      c.addListener(_markDirty);
    }
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  static String _trimZeros(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _priceCtrl.dispose();
    _imageCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes. Leaving now will lose them.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Discard', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_category == null) {
      _snack('Add a category first (Category Management), then pick one here.');
      return;
    }
    if (_branches.isEmpty) {
      _snack('Select at least one branch.');
      return;
    }

    final profile = context.read<UserProfileProvider>().profile;
    if (profile == null) {
      _snack('Your profile could not be read. Sign out and back in.');
      return;
    }

    setState(() => _saving = true);
    try {
      final name = _nameCtrl.text.trim();
      final duplicate = await _repo.nameExists(name, excludeId: widget.existing?.id);
      if (duplicate) {
        if (mounted) _snack('"$name" already exists. Use a different name.');
        return;
      }

      final now = DateTime.now();
      final item = MenuItemModel(
        id: widget.existing?.id ?? '',
        name: name,
        description: _descriptionCtrl.text.trim(),
        category: _category!,
        price: double.parse(_priceCtrl.text.trim()),
        image: _imageCtrl.text.trim(),
        branches: _branches.toList(),
        active: _active,
        outOfStock: _outOfStock,
        displayOrder: int.tryParse(_orderCtrl.text.trim()) ?? widget.nextDisplayOrder,
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: now,
      );

      if (widget.isEditing) {
        await _repo.update(widget.existing!.id, item);
      } else {
        await _repo.add(item);
      }

      _dirty = false;
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (await _confirmDiscard() && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(title: Text(widget.isEditing ? 'Edit Menu Item' : 'Add Menu Item')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _field(
                controller: _nameCtrl,
                label: 'Menu Name',
                hint: 'e.g. Special Lomi',
                icon: Icons.restaurant_menu_rounded,
                textCapitalization: TextCapitalization.words,
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return 'Menu name is required.';
                  if (t.length < 2) return 'Name looks too short.';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              widget.categories.isEmpty
                  ? _noCategoriesNotice()
                  : DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        prefixIcon: const Icon(Icons.category_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      items: [
                        // DropdownButtonFormField requires every item's `value`
                        // to be unique. Two Firestore documents can end up with
                        // the same category `name` (e.g. one added by hand in
                        // the console, bypassing the app's own duplicate-name
                        // check) — de-dupe by name here so leftover duplicate
                        // data can't crash this form.
                        for (final c in {for (final c in widget.categories) c.name: c}.values)
                          DropdownMenuItem(value: c.name, child: Text(c.name)),
                      ],
                      onChanged: (v) => setState(() {
                        _category = v;
                        _dirty = true;
                      }),
                    ),
              const SizedBox(height: 14),
              _field(
                controller: _descriptionCtrl,
                label: 'Description (optional)',
                hint: 'Short description shown in POS Preview',
                icon: Icons.notes_rounded,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _field(
                      controller: _priceCtrl,
                      label: 'Selling Price (₱)',
                      hint: '0.00',
                      icon: Icons.sell_outlined,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      validator: (v) {
                        final n = double.tryParse((v ?? '').trim());
                        if (n == null) return 'Enter a valid amount.';
                        if (n <= 0) return 'Must be greater than 0.';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      controller: _orderCtrl,
                      label: 'Display Order',
                      hint: '0',
                      icon: Icons.low_priority_rounded,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _field(
                controller: _imageCtrl,
                label: 'Image URL (optional)',
                hint: 'https://…',
                icon: Icons.image_outlined,
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 20),
              const Text('Available Branches',
                  style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark)),
              const SizedBox(height: 4),
              const Text(
                'Only checked branches show this item in the POS.',
                style: TextStyle(fontSize: 12, color: AppColors.textGray),
              ),
              const SizedBox(height: 8),
              _branchChecklist(),
              const SizedBox(height: 20),
              const Text('Availability',
                  style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark)),
              const SizedBox(height: 8),
              _availabilityToggles(),
              const SizedBox(height: 20),
              const Text('POS Preview',
                  style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark)),
              const SizedBox(height: 10),
              PosPreviewCard(
                name: _nameCtrl.text,
                category: _category ?? '',
                price: double.tryParse(_priceCtrl.text.trim()) ?? 0,
                image: _imageCtrl.text.trim(),
                outOfStock: _outOfStock,
              ),
              const SizedBox(height: 24),
              GradientButton(
                label: widget.isEditing ? 'Save Changes' : 'Add Menu Item',
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _noCategoriesNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lightWarning,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.gold, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'No categories yet. Set one up in Category Management first.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _branchChecklist() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (final b in kBranchNames)
            CheckboxListTile(
              activeColor: AppColors.teal,
              dense: true,
              title: Text(b),
              secondary: const Icon(Icons.storefront_rounded, color: AppColors.textGray, size: 20),
              value: _branches.contains(b),
              onChanged: (checked) => setState(() {
                if (checked ?? false) {
                  _branches = {..._branches, b};
                } else {
                  _branches = {..._branches}..remove(b);
                }
                _dirty = true;
              }),
            ),
        ],
      ),
    );
  }

  Widget _availabilityToggles() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          SwitchListTile(
            activeColor: AppColors.teal,
            title: const Text('Active', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              _active ? 'Visible in the POS' : 'Hidden — removed from POS, sales history kept',
              style: const TextStyle(fontSize: 12, color: AppColors.textGray),
            ),
            value: _active,
            onChanged: (v) => setState(() {
              _active = v;
              _dirty = true;
            }),
          ),
          const Divider(height: 1),
          SwitchListTile(
            activeColor: AppColors.danger,
            title: const Text('Out of Stock', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text(
              'Stays visible in the POS but can’t be ordered',
              style: TextStyle(fontSize: 12, color: AppColors.textGray),
            ),
            value: _outOfStock,
            onChanged: (v) => setState(() {
              _outOfStock = v;
              _dirty = true;
            }),
          ),
        ],
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
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      onChanged: (_) {
        if (controller == _imageCtrl || controller == _nameCtrl || controller == _priceCtrl) {
          setState(() {}); // keeps the POS Preview live
        }
      },
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}