import 'package:flutter/material.dart';
import '../../core/constants/menu_category_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/menu_category_model.dart';
import '../../repositories/menu_categories_repository.dart';

/// Owner-only (enforced by the caller, ProductsPage-style — see
/// MenuManagementPage). Create, edit, and drag-reorder menu categories;
/// the saved `displayOrder` is what the (future) POS grid's section order
/// follows, via MenuCategoriesRepository.saveOrder.
class CategoryManagementPage extends StatefulWidget {
  const CategoryManagementPage({super.key});

  @override
  State<CategoryManagementPage> createState() => _CategoryManagementPageState();
}

class _CategoryManagementPageState extends State<CategoryManagementPage> {
  final _repo = MenuCategoriesRepository();
  List<MenuCategoryModel> _localOrder = [];
  bool _reordering = false;

  @override
  void initState() {
    super.initState();
    _repo.seedDefaultsIfEmpty(kDefaultCategorySeed);
  }

  Future<void> _openEditor({MenuCategoryModel? existing}) async {
    final result = await showModalBottomSheet<_CategoryDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _CategoryEditorSheet(existing: existing),
    );
    if (result == null) return;

    try {
      final duplicate = await _repo.nameExists(result.name, excludeId: existing?.id);
      if (duplicate) {
        _snack('"${result.name}" already exists.');
        return;
      }
      if (existing == null) {
        await _repo.add(MenuCategoryModel(
          id: '',
          name: result.name,
          iconKey: result.iconKey,
          displayOrder: _localOrder.length,
          updatedAt: DateTime.now(),
        ));
      } else {
        await _repo.update(existing.id, existing.copyWith(name: result.name, iconKey: result.iconKey));
      }
    } catch (e) {
      _snack(e.toString().contains('permission-denied')
          ? "You don't have permission to save this."
          : 'Could not save: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _saveReorder() async {
    try {
      await _repo.saveOrder(_localOrder);
      if (mounted) setState(() => _reordering = false);
    } catch (e) {
      _snack('Could not save order: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Category Management'),
        actions: [
          if (_localOrder.length > 1)
            TextButton(
              onPressed: () {
                if (_reordering) {
                  _saveReorder();
                } else {
                  setState(() => _reordering = true);
                }
              },
              child: Text(_reordering ? 'Save Order' : 'Reorder'),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Category'),
      ),
      body: StreamBuilder<List<MenuCategoryModel>>(
        stream: _repo.watchAllOrdered(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text(
                snap.error.toString().contains('permission-denied')
                    ? "You don't have access to categories."
                    : "Couldn't load categories.",
                style: const TextStyle(color: AppColors.danger),
              ),
            );
          }

          final categories = snap.data ?? const <MenuCategoryModel>[];
          // Keep a local, reorderable copy in sync with the live stream
          // whenever we're NOT mid-drag, so remote edits still show up.
          if (!_reordering) _localOrder = List.of(categories);

          if (categories.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No categories yet. Tap "Add Category" to create your first one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textGray),
                ),
              ),
            );
          }

          return ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: _localOrder.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                _reordering = true;
                if (newIndex > oldIndex) newIndex -= 1;
                final item = _localOrder.removeAt(oldIndex);
                _localOrder.insert(newIndex, item);
              });
            },
            itemBuilder: (context, i) {
              final c = _localOrder[i];
              return Container(
                key: ValueKey(c.id),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.lightSuccess,
                    child: Icon(iconForKey(c.iconKey), color: AppColors.teal, size: 20),
                  ),
                  title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('Order: ${c.displayOrder + 1}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textGray)),
                  trailing: _reordering
                      ? const Icon(Icons.drag_handle_rounded, color: AppColors.textGray)
                      : IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.teal),
                          onPressed: () => _openEditor(existing: c),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CategoryDraft {
  final String name;
  final String iconKey;
  const _CategoryDraft(this.name, this.iconKey);
}

class _CategoryEditorSheet extends StatefulWidget {
  final MenuCategoryModel? existing;
  const _CategoryEditorSheet({this.existing});

  @override
  State<_CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<_CategoryEditorSheet> {
  late final TextEditingController _nameCtrl;
  late String _iconKey;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _iconKey = widget.existing?.iconKey ?? kDefaultCategoryIconKey;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Text(
              widget.existing == null ? 'Add Category' : 'Edit Category',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Category Name',
                hintText: 'e.g. Lomi',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Icon', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final entry in kCategoryIcons.entries)
                  _iconChoice(entry.key, entry.value),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  final name = _nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(context, _CategoryDraft(name, _iconKey));
                },
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconChoice(String key, IconData icon) {
    final selected = _iconKey == key;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _iconKey = key),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? AppColors.teal.withValues(alpha: 0.12) : AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.teal : AppColors.border),
        ),
        child: Icon(icon, color: selected ? AppColors.teal : AppColors.textGray, size: 22),
      ),
    );
  }
}