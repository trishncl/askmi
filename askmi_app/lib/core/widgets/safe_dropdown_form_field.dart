import 'package:flutter/material.dart';
import '../utils/dropdown_utils.dart';

/// Drop-in replacement for form dropdowns. Deduplicates items, validates
/// the selected value, and resets invalid Firestore values to [fallback].
class SafeDropdownFormField extends StatefulWidget {
  const SafeDropdownFormField({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.fallback,
    required this.onChanged,
    this.itemLabel,
  });

  final String label;
  final IconData icon;
  final String value;
  final List<String> items;
  final String fallback;
  final ValueChanged<String> onChanged;
  final String Function(String value)? itemLabel;

  @override
  State<SafeDropdownFormField> createState() => _SafeDropdownFormFieldState();
}

class _SafeDropdownFormFieldState extends State<SafeDropdownFormField> {
  @override
  void initState() {
    super.initState();
    _resetInvalidValueIfNeeded();
  }

  @override
  void didUpdateWidget(SafeDropdownFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value || oldWidget.items != widget.items) {
      _resetInvalidValueIfNeeded();
    }
  }

  void _resetInvalidValueIfNeeded() {
    final uniqueItems = dedupeDropdownItems(widget.items);
    final safeValue = sanitizeDropdownValue(widget.value, uniqueItems);
    if (safeValue != null || uniqueItems.isEmpty) return;

    final reset = uniqueItems.contains(widget.fallback)
        ? widget.fallback
        : uniqueItems.first;

    if (widget.value == reset) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onChanged(reset);
    });
  }

  @override
  Widget build(BuildContext context) {
    final uniqueItems = dedupeDropdownItems(widget.items);
    final safeValue = sanitizeDropdownValue(widget.value, uniqueItems);
    final displayValue = safeValue ??
        (uniqueItems.contains(widget.fallback)
            ? widget.fallback
            : (uniqueItems.isNotEmpty ? uniqueItems.first : null));

    return DropdownButtonFormField<String>(
      initialValue: displayValue,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: Icon(widget.icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
      items: [
        for (final item in uniqueItems)
          DropdownMenuItem<String>(
            value: item,
            child: Text(widget.itemLabel?.call(item) ?? item),
          ),
      ],
      onChanged: uniqueItems.isEmpty
          ? null
          : (selected) {
              if (selected != null) widget.onChanged(selected);
            },
    );
  }
}