import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore collection: `branches`
class BranchModel {
  final String id;
  final String name;
  final String address;
  final String contactNumber;
  final bool active;
  final DateTime createdAt;

  BranchModel({
    required this.id,
    required this.name,
    required this.address,
    required this.contactNumber,
    required this.active,
    required this.createdAt,
  });

  factory BranchModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return BranchModel(
      id: doc.id,
      name: d['name'] ?? '',
      address: d['address'] ?? '',
      contactNumber: d['contactNumber'] ?? '',
      active: d['active'] ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'address': address,
        'contactNumber': contactNumber,
        'active': active,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}