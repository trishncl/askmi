import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/branch_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/dropdown_utils.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/safe_dropdown_form_field.dart';
import '../../models/product_model.dart';
import '../../providers/app_providers.dart';
import '../../repositories/products_repository.dart';

/// Add / edit a product. Doubles as both by taking an optional [existing]
/// — same shape as SaleFormPage / InventoryFormPage.
///
/// Two things this form does that the others don't yet: an async
/// duplicate-name check before writing, and a "discard changes?" guard on
/// the way out, since a product edit is more likely to be a longer, more
/// deliberate session (branch, pricing, availability all at once) than a
/// quick sale entry.
class ProductFormPage extends StatefulWidget {
  final ProductModel? existing;
  const ProductFormPage({super.key, this.existing});

  bool get isEditing => existing != null;

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _repo = ProductsRepository();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _imageCtrl;

  late String _branch;
  late String _status; // ProductStatusValues.available | .disabled
  late String _movementStatus; // MovementStatusValues.fastMoving | .normal
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _categoryCtrl = TextEditingController(text: e?.category ?? '');
    _priceCtrl = TextEditingController(text: e == null ? '' : _trimZeros(e.price));
    _stockCtrl = TextEditingController(text: e == null ? '' : '${e.stock}');
    _descriptionCtrl = TextEditingController(text: e?.description ?? '');
    _imageCtrl = TextEditingController(text: e?.image ?? '');
    _branch = resolveDropdownValue(
      value: e?.branch,
      items: kBranchNames,
      fallback: kBranchNames.first,
    );
    _status = e?.status ?? ProductStatusValues.available;
    _movementStatus = resolveDropdownValue(
      value: e?.movementStatus,
      items: const [MovementStatusValues.normal, MovementStatusValues.fastMoving],
      fallback: MovementStatusValues.normal,
    );

    for (final c in [_nameCtrl, _categoryCtrl, _priceCtrl, _stockCtrl, _descriptionCtrl, _imageCtrl]) {
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
    _categoryCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    _descriptionCtrl.dispose();
    _imageCtrl.dispose();
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

    final profile = context.read<UserProfileProvider>().profile;
    if (profile == null) {
      _snack('Your profile could not be read. Sign out and back in.');
      return;
    }

    setState(() => _saving = true);
    try {
      final name = _nameCtrl.text.trim();

      final duplicate = await _repo.nameExistsInBranch(
        name,
        _branch,
        excludeId: widget.existing?.id,
      );
      if (duplicate) {
        if (mounted) {
          _snack('"$name" already exists in $_branch. Use a different name or branch.');
        }
        return;
      }

      final now = DateTime.now();
      final product = ProductModel(
        id: widget.existing?.id ?? '',
        name: name,
        category: _categoryCtrl.text.trim(),
        branch: _branch,
        price: double.parse(_priceCtrl.text.trim()),
        stock: int.parse(_stockCtrl.text.trim()),
        status: _status,
        movementStatus: _movementStatus,
        description: _descriptionCtrl.text.trim(),
        image: _imageCtrl.text.trim(),
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: now,
      );

      if (widget.isEditing) {
        await _repo.update(widget.existing!.id, product);
      } else {
        await _repo.add(product);
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
        appBar: AppBar(
          title: Text(widget.isEditing ? 'Edit Product' : 'Add Product'),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _field(
                controller: _nameCtrl,
                label: 'Name',
                hint: 'e.g. Buko Juice',
                icon: Icons.local_drink_outlined,
                textCapitalization: TextCapitalization.words,
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return 'Product name is required.';
                  if (t.length < 2) return 'Name looks too short.';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _field(
                controller: _categoryCtrl,
                label: 'Category',
                hint: 'e.g. Fruit Juice',
                icon: Icons.category_outlined,
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v ?? '').trim().isEmpty ? 'Category is required.' : null,
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _field(
                      controller: _priceCtrl,
                      label: 'Price (₱)',
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
                      controller: _stockCtrl,
                      label: widget.isEditing ? 'Stock' : 'Initial Stock',
                      hint: '0',
                      icon: Icons.inventory_2_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        final n = int.tryParse((v ?? '').trim());
                        if (n == null) return 'Enter a whole number.';
                        if (n < 0) return "Can't be negative.";
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
                onChanged: (v) => setState(() {
                  _branch = v;
                  _dirty = true;
                }),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SwitchListTile(
                  activeColor: AppColors.teal,
                  title: const Text('Availability', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    _status == ProductStatusValues.available
                        ? 'Available to sell'
                        : 'Disabled — hidden from checkout',
                    style: const TextStyle(fontSize: 12, color: AppColors.textGray),
                  ),
                  secondary: Icon(
                    _status == ProductStatusValues.available
                        ? Icons.check_circle_outline_rounded
                        : Icons.block_rounded,
                    color: _status == ProductStatusValues.available
                        ? AppColors.teal
                        : AppColors.textGray,
                  ),
                  value: _status == ProductStatusValues.available,
                  onChanged: (v) => setState(() {
                    _status = v ? ProductStatusValues.available : ProductStatusValues.disabled;
                    _dirty = true;
                  }),
                ),
              ),
              const SizedBox(height: 14),
              SafeDropdownFormField(
                label: 'Movement Status',
                icon: Icons.trending_up_rounded,
                value: _movementStatus,
                items: const [MovementStatusValues.normal, MovementStatusValues.fastMoving],
                fallback: MovementStatusValues.normal,
                itemLabel: (v) => v == MovementStatusValues.fastMoving ? 'Fast Moving' : 'Normal',
                onChanged: (v) => setState(() {
                  _movementStatus = v;
                  _dirty = true;
                }),
              ),
              const SizedBox(height: 14),
              _field(
                controller: _descriptionCtrl,
                label: 'Description (optional)',
                hint: 'Short note about this product',
                icon: Icons.notes_rounded,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 14),
              _field(
                controller: _imageCtrl,
                label: 'Image URL (optional)',
                hint: 'https://…',
                icon: Icons.image_outlined,
                keyboardType: TextInputType.url,
              ),
              if (_imageCtrl.text.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    _imageCtrl.text.trim(),
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 120,
                      alignment: Alignment.center,
                      color: AppColors.lightDanger,
                      child: const Text(
                        "Couldn't load that image URL",
                        style: TextStyle(color: AppColors.danger, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              GradientButton(
                label: widget.isEditing ? 'Save Changes' : 'Add Product',
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
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
        if (controller == _imageCtrl) setState(() {});
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