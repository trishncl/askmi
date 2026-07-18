import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore collection: `notifications` — in-app only (no push, see the
/// earlier Blaze-plan decision).
class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type; // 'low_stock' | 'report' | 'system'
  final String branch; // specific branch, or 'All Branches' for Owner-wide
  final bool read;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.branch,
    required this.read,
    required this.createdAt,
  });

  factory NotificationModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return NotificationModel(
      id: doc.id,
      title: d['title'] ?? '',
      body: d['body'] ?? '',
      type: d['type'] ?? 'system',
      branch: d['branch'] ?? 'All Branches',
      read: d['read'] ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'body': body,
        'type': type,
        'branch': branch,
        'read': read,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}