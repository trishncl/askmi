import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/role_permissions.dart';

/// Firestore collection: `users`
/// Document ID = Firebase Auth UID.
class UserModel {
  final String uid;
  final String firstName;
  final String lastName;
  final String name;
  final String username;
  final String email;
  final String contactNumber;
  final String role; // 'Owner' | 'Manager' | 'Cashier' (legacy docs may say 'Staff')
  final String branch;
  final String status; // 'active' | 'inactive' | 'pending'
  final bool active;
  final String profileImageUrl;
  final Map<String, bool> permissions;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLoginAt;
  final int salesTransactionsCreated;
  final int inventoryLogsSubmitted;

  UserModel({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.name,
    required this.username,
    required this.email,
    required this.contactNumber,
    required this.role,
    required this.branch,
    required this.status,
    required this.active,
    required this.profileImageUrl,
    required this.permissions,
    required this.createdAt,
    required this.updatedAt,
    this.lastLoginAt,
    this.salesTransactionsCreated = 0,
    this.inventoryLogsSubmitted = 0,
  });

  /// Normalizes legacy `Staff` docs to `Cashier` for UI display.
  String get displayRole => role == 'Staff' ? 'Cashier' : role;

  String get displayName =>
      name.trim().isNotEmpty ? name.trim() : '$firstName $lastName'.trim();

  String get initials {
    final parts = displayName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  factory UserModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};

    final firstName = _asString(d['first_name']);
    final lastName = _asString(d['last_name']);
    final name = _asString(d['name'], '$firstName $lastName'.trim());
    final role = _asString(d['role'], 'Cashier');

    final rawStatus = _asString(d['status']);
    final hasStatus = rawStatus.isNotEmpty;
    final hasActive = d.containsKey('active');

    late final bool active;
    late final String status;

    if (!hasStatus && !hasActive) {
      active = true;
      status = 'active';
    } else if (hasStatus) {
      status = rawStatus;
      active = hasActive ? _asBool(d['active'], fallback: status == 'active') : status == 'active';
    } else {
      active = _asBool(d['active'], fallback: true);
      status = active ? 'active' : 'inactive';
    }

    final rawPermissions = d['permissions'];
    final permissions = rawPermissions is Map
        ? rawPermissions.map((k, v) => MapEntry(k.toString(), v == true))
        : defaultPermissionsForRole(role == 'Staff' ? 'Cashier' : role);

    return UserModel(
      uid: doc.id,
      firstName: firstName,
      lastName: lastName,
      name: name,
      username: _asString(d['username']),
      email: _asString(d['email']),
      contactNumber: _asString(d['contact_number']),
      role: role,
      branch: _asString(d['branch']),
      status: status,
      active: active,
      profileImageUrl: _asString(d['profile_image_url']),
      permissions: permissions,
      createdAt: _readTimestamp(d['created_at'] ?? d['createdAt']),
      updatedAt: _readTimestamp(d['updated_at'] ?? d['updatedAt']),
      lastLoginAt: _readTimestampOrNull(d['last_login_at']),
      salesTransactionsCreated: _asInt(d['sales_transactions_created']),
      inventoryLogsSubmitted: _asInt(d['inventory_logs_submitted']),
    );
  }

  Map<String, dynamic> toMap() => {
        'first_name': firstName,
        'last_name': lastName,
        'name': name,
        'username': username,
        'email': email,
        'contact_number': contactNumber,
        'role': role,
        'branch': branch,
        'status': status,
        'active': active,
        'profile_image_url': profileImageUrl,
        'permissions': permissions,
        'created_at': Timestamp.fromDate(createdAt),
        'updated_at': Timestamp.fromDate(updatedAt),
        if (lastLoginAt != null) 'last_login_at': Timestamp.fromDate(lastLoginAt!),
        'sales_transactions_created': salesTransactionsCreated,
        'inventory_logs_submitted': inventoryLogsSubmitted,
      };

  static String _asString(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    return value.toString();
  }

  static bool _asBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    return fallback;
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static DateTime _readTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  static DateTime? _readTimestampOrNull(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}