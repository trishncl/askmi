import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/menu_item_model.dart';
import '../../repositories/menu_repository.dart';

/// Drag-and-drop reordering, scoped to one category at a time — the POS
/// grid groups items by category section, so "order" only has a clear
/// meaning within a section; reordering across categories at once would
/// just be two unrelated numbers colliding.
class MenuReorderPage extends StatefulWidget {
  final String category;
  final List<MenuItemModel> items; // already filtered to this category, any order
  const MenuReorderPage({super.key, required this.category, required this.items});

  @override
  State<MenuReorderPage> createState() => _MenuReorderPageState();
}

class _MenuReorderPageState extends State<MenuReorderPage> {
  final _repo = MenuRepository();
  late List<MenuItemModel> _order;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _order = List.of(widget.items)..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _repo.saveDisplayOrder(_order);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save order: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Reorder — ${widget.category}'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save Order'),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.lightSuccess,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.drag_indicator_rounded, color: AppColors.teal, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Drag to reorder. This is the order the POS will show these items in.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.textDark),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: _order.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = _order.removeAt(oldIndex);
                  _order.insert(newIndex, item);
                });
              },
              itemBuilder: (context, i) {
                final item = _order[i];
                return Container(
                  key: ValueKey(item.id),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.lightSuccess,
                      child: Text('${i + 1}',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.teal)),
                    ),
                    title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(Fmt.peso.format(item.price),
                        style: const TextStyle(fontSize: 12, color: AppColors.textGray)),
                    trailing: const Icon(Icons.drag_handle_rounded, color: AppColors.textGray),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}