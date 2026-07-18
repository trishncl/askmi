import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore collection: `products` — movement tracking (Inventory
/// Management tab), NOT the POS catalog. See MenuItemModel for that.
class ProductModel {
  final String id;
  final String name;
  final String branch;
  final int addedStock;
  final int soldStock;
  final String remark;
  final String detail;
  final DateTime updatedAt;

  ProductModel({
    required this.id,
    required this.name,
    required this.branch,
    required this.addedStock,
    required this.soldStock,
    required this.remark,
    required this.detail,
    required this.updatedAt,
  });

  factory ProductModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return ProductModel(
      id: doc.id,
      name: d['name'] ?? '',
      branch: d['branch'] ?? '',
      addedStock: (d['addedStock'] ?? 0) as int,
      soldStock: (d['soldStock'] ?? 0) as int,
      remark: d['remark'] ?? '',
      detail: d['detail'] ?? '',
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'branch': branch,
        'addedStock': addedStock,
        'soldStock': soldStock,
        'remark': remark,
        'detail': detail,
        'updatedAt': Timestamp.fromDate(updatedAt),
      };
}