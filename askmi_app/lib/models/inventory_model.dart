import 'package:cloud_firestore/cloud_firestore.dart';

/// Stock health derived from closing stock vs. this record's par levels.
/// Kept as a getter on the model (not stored) so it always reflects the
/// latest opening/closing/reorderLevel — never a second copy that can
/// silently drift from the numbers it's summarizing.
enum StockStatus { healthy, low, critical, overstock }

/// Firestore collection: `inventory` — raw ingredient/material stock
/// records, separate from finished-product tracking (ProductModel).
class InventoryModel {
  final String id;
  final String itemName;
  final String category; // 'Perishable' | 'Non-Perishable'
  final String branch;
  final double opening;
  final double deliveries;
  final double closing;
  final double wastage;
  final String unit;

  /// Par levels used to derive [status]. `0` means "not set" for that
  /// bound — a record without pars falls back to a percent-of-opening
  /// heuristic rather than reporting Healthy no matter what.
  final double reorderLevel;
  final double maxLevel;

  final String notes;
  final String recordedByUid;
  final DateTime date;

  InventoryModel({
    required this.id,
    required this.itemName,
    required this.category,
    required this.branch,
    required this.opening,
    this.deliveries = 0,
    required this.closing,
    this.wastage = 0,
    required this.unit,
    this.reorderLevel = 0,
    this.maxLevel = 0,
    required this.notes,
    required this.recordedByUid,
    required this.date,
  });

  double get used => opening - closing;
  double get percentRemaining => opening == 0 ? 0 : closing / opening;

  /// Opening + what came in, minus what's left and what was thrown away —
  /// i.e. how much actually got used for orders during the period.
  double get estimatedConsumption {
    final v = opening + deliveries - closing - wastage;
    return v < 0 ? 0 : v;
  }

  StockStatus get status {
    if (closing <= 0) return StockStatus.critical;
    if (maxLevel > 0 && closing >= maxLevel) return StockStatus.overstock;
    if (reorderLevel > 0) {
      if (closing <= reorderLevel * 0.5) return StockStatus.critical;
      if (closing <= reorderLevel) return StockStatus.low;
      return StockStatus.healthy;
    }
    // No par levels recorded — fall back to opening-relative thresholds.
    final pct = percentRemaining;
    if (pct < 0.15) return StockStatus.critical;
    if (pct < 0.35) return StockStatus.low;
    return StockStatus.healthy;
  }

  factory InventoryModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return InventoryModel(
      id: doc.id,
      itemName: _asString(d['itemName']),
      category: _asString(d['category'], 'Perishable'),
      branch: _asString(d['branch']),
      opening: (d['opening'] ?? 0).toDouble(),
      deliveries: (d['deliveries'] ?? 0).toDouble(),
      closing: (d['closing'] ?? 0).toDouble(),
      wastage: (d['wastage'] ?? 0).toDouble(),
      unit: _asString(d['unit']),
      reorderLevel: (d['reorderLevel'] ?? 0).toDouble(),
      maxLevel: (d['maxLevel'] ?? 0).toDouble(),
      notes: _asString(d['notes']),
      recordedByUid: _asString(d['recordedByUid']),
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// See SaleModel._asString — same reasoning: a field saved as a
  /// Reference (or anything else) instead of a String used to crash the
  /// whole stream. This degrades gracefully instead.
  static String _asString(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    if (value is String) return value;
    if (value is DocumentReference) return value.id;
    return value.toString();
  }

  Map<String, dynamic> toMap() => {
        'itemName': itemName,
        'category': category,
        'branch': branch,
        'opening': opening,
        'deliveries': deliveries,
        'closing': closing,
        'wastage': wastage,
        'unit': unit,
        'reorderLevel': reorderLevel,
        'maxLevel': maxLevel,
        'notes': notes,
        'recordedByUid': recordedByUid,
        'date': Timestamp.fromDate(date),
      };
}