import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore collection: `menuCategories` — Owner/Manager-configured
/// groupings shown as filter chips here and as section headers in the
/// (future) POS grid, in `displayOrder`.
class MenuCategoryModel {
  final String id;
  final String name;
  final String iconKey; // key into kCategoryIcons
  final int displayOrder;
  final DateTime updatedAt;

  MenuCategoryModel({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.displayOrder,
    required this.updatedAt,
  });

  MenuCategoryModel copyWith({String? name, String? iconKey, int? displayOrder}) {
    return MenuCategoryModel(
      id: id,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      displayOrder: displayOrder ?? this.displayOrder,
      updatedAt: DateTime.now(),
    );
  }

  factory MenuCategoryModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return MenuCategoryModel(
      id: doc.id,
      name: _asString(d['name']),
      iconKey: _asString(d['iconKey'], 'other'),
      displayOrder: ((d['displayOrder'] ?? 0) as num).toInt(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// See MenuItemModel._asString — same reasoning.
  static String _asString(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    if (value is String) return value;
    if (value is DocumentReference) return value.id;
    return value.toString();
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'iconKey': iconKey,
        'displayOrder': displayOrder,
        'updatedAt': Timestamp.fromDate(updatedAt),
      };
}