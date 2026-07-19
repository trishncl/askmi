import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../user_query.dart';

const _kRoles = ['Owner', 'Manager', 'Cashier'];
const _kStatuses = ['active', 'inactive', 'pending'];

class UserFilterBar extends StatelessWidget {
  final UserQuery query;
  final ValueChanged<UserQuery> onChanged;

  const UserFilterBar({super.key, required this.query, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _dropdown(
              hint: 'All Roles',
              value: query.role,
              items: _kRoles,
              itemLabel: (v) => v,
              onChanged: (v) => onChanged(query.copyWith(role: v)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _dropdown(
              hint: 'All Status',
              value: query.status,
              items: _kStatuses,
              itemLabel: (v) => v[0].toUpperCase() + v.substring(1),
              onChanged: (v) => onChanged(query.copyWith(status: v)),
            ),
          ),
          const SizedBox(width: 10),
          _sortButton(context),
        ],
      ),
    );
  }

  Widget _dropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required String Function(String) itemLabel,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isDense: true,
          isExpanded: true,
          hint: Text(hint, style: const TextStyle(fontSize: 13, color: AppColors.textGray)),
          icon: const Icon(Icons.expand_more_rounded, size: 18),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
          items: [
            DropdownMenuItem<String?>(value: null, child: Text(hint)),
            for (final item in items)
              DropdownMenuItem<String?>(value: item, child: Text(itemLabel(item))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _sortButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: PopupMenuButton<UserSort>(
        tooltip: 'Sort',
        initialValue: query.sort,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onSelected: (v) => onChanged(query.copyWith(sort: v)),
        itemBuilder: (context) => [
          for (final s in UserSort.values)
            PopupMenuItem(
              value: s,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (s == query.sort)
                    const Icon(Icons.check_rounded, size: 16, color: AppColors.teal)
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 6),
                  Text(s.label),
                ],
              ),
            ),
        ],
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Icon(Icons.sort_rounded, size: 20, color: AppColors.textDark),
        ),
      ),
    );
  }
}