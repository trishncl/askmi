import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore collection: `menuItems` — the POS catalog. Separate from
/// ProductModel on purpose (see the schema doc's notes on this decision).
class MenuItemModel {
  final String id;
  final String name;
  final double price;
  final String category; // 'Food' | 'Drinks' | 'Add-ons'
  final String branch;
  final bool active;
  final DateTime updatedAt;

  MenuItemModel({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.branch,
    required this.active,
    required this.updatedAt,
  });

  factory MenuItemModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return MenuItemModel(
      id: doc.id,
      name: d['name'] ?? '',
      price: (d['price'] ?? 0).toDouble(),
      category: d['category'] ?? 'Food',
      branch: d['branch'] ?? '',
      active: d['active'] ?? true,
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'price': price,
        'category': category,
        'branch': branch,
        'active': active,
        'updatedAt': Timestamp.fromDate(updatedAt),
      };
}