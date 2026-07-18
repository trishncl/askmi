import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore collection: `users`
/// Document ID = the Firebase Auth UID (not auto-generated) — this is
/// what makes role lookup in UserProfileProvider possible.
class UserModel {
  final String uid;
  final String name;
  final String email;
  final String role; // 'Owner' | 'Manager' | 'Cashier'
  final String branch; // one of branches.name, or 'All Branches' for Owner
  final bool active;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.branch,
    required this.active,
    required this.createdAt,
  });

  factory UserModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return UserModel(
      uid: doc.id,
      name: d['name'] ?? '',
      email: d['email'] ?? '',
      role: d['role'] ?? 'Cashier',
      branch: d['branch'] ?? '',
      active: d['active'] ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'role': role,
        'branch': branch,
        'active': active,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}