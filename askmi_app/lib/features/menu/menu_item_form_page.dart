// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import '../../core/constants/branch_constants.dart';
// import '../../core/theme/app_colors.dart';
// import '../../core/widgets/gradient_button.dart';
// import '../../models/menu_item_model.dart';
// import '../../providers/app_providers.dart';
// import '../../repositories/menu_repository.dart';

// /// Add / edit a POS catalog item (`menuItems` collection). Same shape as
// /// ProductFormPage — including the branch-lock behavior — but this
// /// collection is what CashierPosPage checks out against, so there's no
// /// stock/movement tracking here, just name/price/category/branch/active.
// class MenuItemFormPage extends StatefulWidget {
//   final MenuItemModel? existing;
//   const MenuItemFormPage({super.key, this.existing});

//   bool get isEditing => existing != null;

//   @override
//   State<MenuItemFormPage> createState() => _MenuItemFormPageState();
// }

// class _MenuItemFormPageState extends State<MenuItemFormPage> {
//   static const _categories = ['Food', 'Drinks', 'Add-ons'];

//   final _formKey = GlobalKey<FormState>();
//   final _repo = MenuRepository();

//   late final TextEditingController _nameCtrl;
//   late final TextEditingController _priceCtrl;

//   late String _category;
//   late String _branch;
//   late bool _active;
//   bool _saving = false;
//   bool _dirty = false;

//   /// True for any non-Owner (Manager/Cashier) — see [isRoleBranchLocked].
//   bool _branchLocked = false;

//   @override
//   void initState() {
//     super.initState();
//     final e = widget.existing;
//     final profile = context.read<UserProfileProvider>().profile;
//     _branchLocked = profile != null && isRoleBranchLocked(profile.role);
//     _nameCtrl = TextEditingController(text: e?.name ?? '');
//     _priceCtrl = TextEditingController(text: e == null ? '' : _trimZeros(e.price));
//     _category = e?.category ?? _categories.first;
//     _branch = e?.branch ?? (_branchLocked ? profile!.branch : kBranchNames.first);
//     _active = e?.active ?? true;

//     for (final c in [_nameCtrl, _priceCtrl]) {
//       c.addListener(_markDirty);
//     }
//   }

//   void _markDirty() {
//     if (!_dirty) setState(() => _dirty = true);
//   }

//   static String _trimZeros(double v) =>
//       v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

//   @override
//   void dispose() {
//     _nameCtrl.dispose();
//     _priceCtrl.dispose();
//     super.dispose();
//   }

//   Future<bool> _confirmDiscard() async {
//     if (!_dirty) return true;
//     final ok = await showDialog<bool>(
//       context: context,
//       builder: (dialogContext) => AlertDialog(
//         title: const Text('Discard changes?'),
//         content: const Text('You have unsaved changes. Leaving now will lose them.'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(dialogContext, false),
//             child: const Text('Keep editing'),
//           ),
//           TextButton(
//             onPressed: () => Navigator.pop(dialogContext, true),
//             child: const Text('Discard', style: TextStyle(color: AppColors.danger)),
//           ),
//         ],
//       ),
//     );
//     return ok ?? false;
//   }

//   Future<void> _save() async {
//     if (!_formKey.currentState!.validate()) return;

//     final profile = context.read<UserProfileProvider>().profile;
//     if (profile == null) {
//       _snack('Your profile could not be read. Sign out and back in.');
//       return;
//     }

//     setState(() => _saving = true);
//     try {
//       final item = MenuItemModel(
//         id: widget.existing?.id ?? '',
//         name: _nameCtrl.text.trim(),
//         price: double.parse(_priceCtrl.text.trim()),
//         category: _category,
//         branch: _branch,
//         active: _active,
//         updatedAt: DateTime.now(),
//       );

//       if (widget.isEditing) {
//         await _repo.update(item.id, item);
//       } else {
//         await _repo.add(item);
//       }

//       if (mounted) Navigator.pop(context, true);
//     } catch (e) {
//       _snack(e.toString().contains('permission-denied')
//           ? "You don't have permission to save this."
//           : 'Could not save: $e');
//     } finally {
//       if (mounted) setState(() => _saving = false);
//     }
//   }

//   void _snack(String message) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
//   }

//   @override
//   Widget build(BuildContext context) {
//     return PopScope(
//       canPop: !_dirty,
//       onPopInvoked: (didPop) async {
//         if (didPop) return;
//         if (await _confirmDiscard() && mounted) Navigator.pop(context);
//       },
//       child: Scaffold(
//         backgroundColor: AppColors.bg,
//         appBar: AppBar(title: Text(widget.isEditing ? 'Edit Menu Item' : 'Add Menu Item')),
//         body: Form(
//           key: _formKey,
//           child: ListView(
//             padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
//             children: [
//               _field(
//                 controller: _nameCtrl,
//                 label: 'Item Name',
//                 hint: 'e.g. Special Lomi',
//                 icon: Icons.restaurant_menu_rounded,
//                 validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required.' : null,
//               ),
//               const SizedBox(height: 14),
//               _field(
//                 controller: _priceCtrl,
//                 label: 'Price',
//                 hint: '0.00',
//                 icon: Icons.sell_outlined,
//                 keyboardType: const TextInputType.numberWithOptions(decimal: true),
//                 inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
//                 validator: (v) {
//                   final n = double.tryParse((v ?? '').trim());
//                   if (n == null) return 'Enter a valid amount.';
//                   if (n <= 0) return 'Must be greater than 0.';
//                   return null;
//                 },
//               ),
//               const SizedBox(height: 14),
//               _dropdown(
//                 label: 'Category',
//                 icon: Icons.category_outlined,
//                 value: _category,
//                 items: _categories,
//                 onChanged: (v) => setState(() {
//                   _category = v;
//                   _dirty = true;
//                 }),
//               ),
//               const SizedBox(height: 14),
//               _dropdown(
//                 label: 'Branch',
//                 icon: Icons.storefront_rounded,
//                 value: _branch,
//                 items: kBranchNames,
//                 enabled: !_branchLocked,
//                 helperText: _branchLocked ? 'Locked to your assigned branch' : null,
//                 onChanged: (v) => setState(() {
//                   _branch = v;
//                   _dirty = true;
//                 }),
//               ),
//               const SizedBox(height: 14),
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 4),
//                 decoration: BoxDecoration(
//                   border: Border.all(color: AppColors.border),
//                   borderRadius: BorderRadius.circular(16),
//                 ),
//                 child: SwitchListTile(
//                   activeColor: AppColors.teal,
//                   title: const Text('Available at checkout', style: TextStyle(fontWeight: FontWeight.w600)),
//                   subtitle: Text(
//                     _active ? 'Shown in the POS' : 'Hidden from the POS',
//                     style: const TextStyle(fontSize: 12, color: AppColors.textGray),
//                   ),
//                   secondary: Icon(
//                     _active ? Icons.check_circle_outline_rounded : Icons.block_rounded,
//                     color: _active ? AppColors.teal : AppColors.textGray,
//                   ),
//                   value: _active,
//                   onChanged: (v) => setState(() {
//                     _active = v;
//                     _dirty = true;
//                   }),
//                 ),
//               ),
//               const SizedBox(height: 24),
//               GradientButton(
//                 label: widget.isEditing ? 'Save Changes' : 'Add Item',
//                 loading: _saving,
//                 onPressed: _saving ? null : _save,
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _field({
//     required TextEditingController controller,
//     required String label,
//     required String hint,
//     required IconData icon,
//     TextInputType? keyboardType,
//     List<TextInputFormatter>? inputFormatters,
//     String? Function(String?)? validator,
//   }) {
//     return TextFormField(
//       controller: controller,
//       keyboardType: keyboardType,
//       inputFormatters: inputFormatters,
//       validator: validator,
//       decoration: InputDecoration(
//         labelText: label,
//         hintText: hint,
//         prefixIcon: Icon(icon),
//         border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
//       ),
//     );
//   }

//   Widget _dropdown({
//     required String label,
//     required IconData icon,
//     required String value,
//     required List<String> items,
//     required ValueChanged<String> onChanged,
//     bool enabled = true,
//     String? helperText,
//   }) {
//     return DropdownButtonFormField<String>(
//       initialValue: value,
//       decoration: InputDecoration(
//         labelText: label,
//         prefixIcon: Icon(icon),
//         helperText: helperText,
//         border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
//       ),
//       items: [
//         for (final i in items) DropdownMenuItem(value: i, child: Text(i)),
//       ],
//       onChanged: enabled
//           ? (v) {
//               if (v != null) onChanged(v);
//             }
//           : null,
//     );
//   }
// }