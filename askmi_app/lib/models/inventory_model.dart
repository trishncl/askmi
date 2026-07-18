import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore collection: `inventory` — raw ingredient/material stock
/// records, separate from finished-product tracking (ProductModel).
class InventoryModel {
  final String id;
  final String itemName;
  final String category; // 'Perishable' | 'Non-Perishable'
  final String branch;
  final double opening;
  final double closing;
  final String unit;
  final String notes;
  final String recordedByUid;
  final DateTime date;

  InventoryModel({
    required this.id,
    required this.itemName,
    required this.category,
    required this.branch,
    required this.opening,
    required this.closing,
    required this.unit,
    required this.notes,
    required this.recordedByUid,
    required this.date,
  });

  double get used => opening - closing;
  double get percentRemaining => opening == 0 ? 0 : closing / opening;

  factory InventoryModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return InventoryModel(
      id: doc.id,
      itemName: d['itemName'] ?? '',
      category: d['category'] ?? 'Perishable',
      branch: d['branch'] ?? '',
      opening: (d['opening'] ?? 0).toDouble(),
      closing: (d['closing'] ?? 0).toDouble(),
      unit: d['unit'] ?? '',
      notes: d['notes'] ?? '',
      recordedByUid: d['recordedByUid'] ?? '',
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'itemName': itemName,
        'category': category,
        'branch': branch,
        'opening': opening,
        'closing': closing,
        'unit': unit,
        'notes': notes,
        'recordedByUid': recordedByUid,
        'date': Timestamp.fromDate(date),
      };
}