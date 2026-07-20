import 'package:cloud_firestore/cloud_firestore.dart';

enum MenuItemStatus { available, hidden, outOfStock }

/// Firestore collection: `menuItems` — the POS catalog. Separate from
/// ProductModel (raw ingredients/ledger items) on purpose: a menu item is
/// what a cashier taps to sell.
class MenuItemModel {
  final String id;
  final String name;
  final String description;
  final String category; // matches a MenuCategoryModel.name
  final double price;
  final String image; // URL, optional — UI falls back to a placeholder
  final List<String> branches; // branches where this item is orderable
  final bool active; // false = Hidden (removed from POS, sales history kept)
  final bool outOfStock; // true = temporarily unsellable without hiding it
  final int displayOrder; // POS grid / category section order
  final DateTime createdAt;
  final DateTime updatedAt;

  MenuItemModel({
    required this.id,
    required this.name,
    this.description = '',
    required this.category,
    required this.price,
    this.image = '',
    required this.branches,
    this.active = true,
    this.outOfStock = false,
    this.displayOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Hidden always wins the badge, even if someone also flipped
  /// out-of-stock — there's no point showing "Out of Stock" for an item
  /// that's already off the POS entirely.
  MenuItemStatus get status {
    if (!active) return MenuItemStatus.hidden;
    if (outOfStock) return MenuItemStatus.outOfStock;
    return MenuItemStatus.available;
  }

  /// The single check the (future) POS grid should gate rendering on for
  /// a given branch: hidden, out of stock, and not-this-branch all mean
  /// "don't show it here."
  bool isSellableAt(String branch) => active && !outOfStock && branches.contains(branch);

  MenuItemModel copyWith({
    String? name,
    String? description,
    String? category,
    double? price,
    String? image,
    List<String>? branches,
    bool? active,
    bool? outOfStock,
    int? displayOrder,
    DateTime? updatedAt,
  }) {
    return MenuItemModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      price: price ?? this.price,
      image: image ?? this.image,
      branches: branches ?? this.branches,
      active: active ?? this.active,
      outOfStock: outOfStock ?? this.outOfStock,
      displayOrder: displayOrder ?? this.displayOrder,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory MenuItemModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return MenuItemModel(
      id: doc.id,
      name: _asString(d['name']),
      description: _asString(d['description']),
      category: _asString(d['category']),
      price: (d['price'] ?? 0).toDouble(),
      image: _asString(d['image']),
      branches: _asBranchList(d['branch']),
      active: d['active'] is bool ? d['active'] as bool : true,
      outOfStock: d['outOfStock'] is bool ? d['outOfStock'] as bool : false,
      displayOrder: ((d['displayOrder'] ?? 0) as num).toInt(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// See SaleModel._asString — a field saved as a Reference (or anything
  /// else) instead of a String used to crash the whole stream.
  static String _asString(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    if (value is String) return value;
    if (value is DocumentReference) return value.id;
    return value.toString();
  }

  /// `branch` should be a List<String> of branch names (see toMap()
  /// below), but a document created by hand in the Firebase console is
  /// easy to get wrong — e.g. picking "Reference" as the field type and
  /// linking straight to a `branches/{docId}` doc, or typing a single
  /// string instead of an array. Both used to crash this entire stream
  /// (`List<String>.from(aSingleReference)` throws — it isn't iterable).
  /// This tolerates either shape so one bad document doesn't take down
  /// every menu item. NOTE: if a document's `branch` really is a
  /// `branches/{docId}` Reference, the value recovered here is that
  /// document's ID, NOT the branch's name (e.g. "BA42VkwIXMvnAEsiU1Gl",
  /// not "Taal") — it won't match anything elsewhere in the app (branch
  /// filters, sameBranch() security rules, etc.) until that document's
  /// `branch` field is fixed at the source to hold the actual branch
  /// name(s) as a plain string array, e.g. ["Taal"].
  static List<String> _asBranchList(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value.map(_asString).where((s) => s.isNotEmpty).toList();
    }
    final single = _asString(value);
    return single.isEmpty ? const [] : [single];
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'category': category,
        'price': price,
        'image': image,
        // Field name kept as `branch` (singular) to match the schema note
        // in the brief ("Fields: ... branch ...") — it now holds a LIST
        // rather than one string, since an item can be available at
        // several branches at once. `fromDoc` above reads it back as a
        // List either way.
        'branch': branches,
        'active': active,
        'outOfStock': outOfStock,
        'displayOrder': displayOrder,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };
}