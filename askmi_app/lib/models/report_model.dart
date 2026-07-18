import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore collection: `reports` — Manager submits, Owner receives.
class ReportModel {
  final String id;
  final String type; // 'Financial Report' | 'Analytics Report' | 'Inventory Report'
  final String branch;
  final String senderUid;
  final String senderName;
  final String notes;
  final bool reviewed;
  final DateTime createdAt;

  ReportModel({
    required this.id,
    required this.type,
    required this.branch,
    required this.senderUid,
    required this.senderName,
    required this.notes,
    required this.reviewed,
    required this.createdAt,
  });

  factory ReportModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return ReportModel(
      id: doc.id,
      type: d['type'] ?? '',
      branch: d['branch'] ?? '',
      senderUid: d['senderUid'] ?? '',
      senderName: d['senderName'] ?? '',
      notes: d['notes'] ?? '',
      reviewed: d['reviewed'] ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type,
        'branch': branch,
        'senderUid': senderUid,
        'senderName': senderName,
        'notes': notes,
        'reviewed': reviewed,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}