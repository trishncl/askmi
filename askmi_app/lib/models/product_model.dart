import 'package:cloud_firestore/cloud_firestore.dart';

/// Raw values stored in Firestore for `status`. Kept as strings on the doc
/// (not a Dart enum) so admin edits made directly in the Firebase console
/// stay human-readable — same convention as SaleModel.paymentMethod.
class ProductStatusValues {
  ProductStatusValues._();
  static const available = 'available';
  static const disabled = 'disabled';
  static const outOfStock = 'out_of_stock';
}

class MovementStatusValues {
  MovementStatusValues._();
  static const fastMoving = 'fast_moving';
  static const normal = 'normal';
}

/// What actually renders as a badge. Distinct from the stored `status`
/// string because "Low Stock" is never stored — it's `available` +
/// `stock` below the threshold, computed fresh every read so it can't go
/// stale the way a cached flag could.
enum ProductBadgeStatus { available, lowStock, outOfStock, disabled }

/// Below this, an `available` product shows "Low Stock" instead of
/// "Available". Not a per-product field in this schema (spec lists a
/// fixed field set) — a single shop-wide threshold is the simplest thing
/// that matches "Show Low Stock ... badges" without inventing a field
/// the spec didn't ask for.
const int kLowStockThreshold = 10;

/// Firestore collection: `products` — the Products Management catalog
/// (name, category, branch, price, stock, availability, movement).
class ProductModel {
  final String id;
  final String name;
  final String category;
  final String branch;
  final double price;
  final int stock;
  final String status; // ProductStatusValues
  final String movementStatus; // MovementStatusValues
  final String description;
  final String image; // URL, optional
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductModel({
    required this.id,
    required this.name,
    required this.category,
    required this.branch,
    required this.price,
    required this.stock,
    required this.status,
    required this.movementStatus,
    this.description = '',
    this.image = '',
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isDisabled => status == ProductStatusValues.disabled;
  bool get isFastMoving => movementStatus == MovementStatusValues.fastMoving;

  /// The stored `status` is the source of truth for disabled/out-of-stock
  /// *intent*, but stock hitting 0 or dropping below the threshold always
  /// wins visually — a product can't claim "Available" with 0 units left,
  /// even if nobody remembered to flip its status field.
  ProductBadgeStatus get badgeStatus {
    if (isDisabled) return ProductBadgeStatus.disabled;
    if (stock <= 0 || status == ProductStatusValues.outOfStock) {
      return ProductBadgeStatus.outOfStock;
    }
    if (stock <= kLowStockThreshold) return ProductBadgeStatus.lowStock;
    return ProductBadgeStatus.available;
  }

  /// Out-of-stock products stay sellable-visible but never orderable —
  /// this is the single check the (future) POS/cashier flow should gate on.
  bool get canBeSold => !isDisabled && stock > 0;

  ProductModel copyWith({
    String? name,
    String? category,
    String? branch,
    double? price,
    int? stock,
    String? status,
    String? movementStatus,
    String? description,
    String? image,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      branch: branch ?? this.branch,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      status: status ?? this.status,
      movementStatus: movementStatus ?? this.movementStatus,
      description: description ?? this.description,
      image: image ?? this.image,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory ProductModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return ProductModel(
      id: doc.id,
      name: d['name'] ?? '',
      category: d['category'] ?? '',
      branch: d['branch'] ?? '',
      price: (d['price'] ?? 0).toDouble(),
      stock: (d['stock'] ?? 0) is int ? (d['stock'] ?? 0) as int : (d['stock'] as num).toInt(),
      status: d['status'] ?? ProductStatusValues.available,
      movementStatus: d['movement_status'] ?? MovementStatusValues.normal,
      description: d['description'] ?? '',
      image: d['image'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'category': category,
        'branch': branch,
        'price': price,
        'stock': stock,
        'status': status,
        'movement_status': movementStatus,
        'description': description,
        'image': image,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };
}