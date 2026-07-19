import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../core/constants/role_permissions.dart';
import '../models/user_model.dart';

class UserAdminException implements Exception {
  final String message;
  const UserAdminException(this.message);

  @override
  String toString() => message;
}

/// SPARK-PLAN VERSION — no Cloud Functions, no Blaze plan required.
///
/// Creating a user for someone else still needs a real Firebase Auth
/// account. Without a backend, the only client-side way to do that
/// without kicking the admin out of their own session is to spin up a
/// second, throwaway Firebase App instance, sign up on THAT instance
/// (which has its own isolated auth state), then tear it down. The
/// admin's own FirebaseAuth.instance session is never touched.
///
/// Everything else (role, status, permissions) is enforced by
/// firestore.rules instead of a trusted server, since there is no server.
/// That's a real trust trade-off worth knowing about: it relies entirely
/// on Owner/Manager accounts having strong passwords, since nothing but
/// the rules stands between an authenticated admin and these writes.
class UserAdminService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  UserAdminService({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String get _callerUidOrThrow {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const UserAdminException('You must be signed in to do that.');
    }
    return uid;
  }

  Future<void> createUser({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String contactNumber,
    required String role,
    required String branch,
    required String password,
    required String status,
    String profileImageUrl = '',
  }) async {
    final callerUid = _callerUidOrThrow;
    final cleanUsername = username.trim();
    final cleanEmail = email.trim().toLowerCase();
    final usernameRef = _db.collection('usernames').doc(cleanUsername);

    // 1. Reserve the username. Doc ID = username, so this fails cleanly
    //    if it's already taken (see firestore.rules).
    try {
      await _db.runTransaction((tx) async {
        final existing = await tx.get(usernameRef);
        if (existing.exists) {
          throw const UserAdminException('That username is already taken.');
        }
        tx.set(usernameRef, {
          'reservedAt': FieldValue.serverTimestamp(),
          'reservedBy': callerUid,
        });
      });
    } on UserAdminException {
      rethrow;
    } on FirebaseException catch (e) {
      throw UserAdminException(_friendlyFirestoreMessage(e));
    }

    // 2. Create the real Auth account on an isolated secondary App, then
    //    write the Firestore profile while still "signed in" as the new
    //    user on that secondary instance — that's what lets us roll the
    //    Auth account back if the Firestore write fails.
    FirebaseApp? secondaryApp;
    User? newAuthUser;
    try {
      secondaryApp = await Firebase.initializeApp(
        name: 'UserCreation-${DateTime.now().microsecondsSinceEpoch}',
        options: Firebase.app().options,
      );
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      newAuthUser = credential.user;
      await credential.user?.updateDisplayName('$firstName $lastName'.trim());

      final now = FieldValue.serverTimestamp();
      await _db.collection('users').doc(newAuthUser!.uid).set({
        'user_id': newAuthUser.uid,
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'name': '${firstName.trim()} ${lastName.trim()}'.trim(),
        'username': cleanUsername,
        'email': cleanEmail,
        'contact_number': contactNumber.trim(),
        'role': role,
        'branch': branch,
        'status': status,
        'active': status == 'active',
        'profile_image_url': profileImageUrl.trim(),
        'permissions': defaultPermissionsForRole(role),
        'created_at': now,
        'updated_at': now,
        'created_by': callerUid,
        'updated_by': callerUid,
        'sales_transactions_created': 0,
        'inventory_logs_submitted': 0,
      });
    } on FirebaseAuthException catch (e) {
      await usernameRef.delete().catchError((_) {});
      throw UserAdminException(_authErrorMessage(e));
    } on FirebaseException catch (e) {
      // Firestore write failed after the Auth account was already
      // created — clean up the orphan so a retry with the same details
      // works, instead of hitting "email already registered" forever.
      await usernameRef.delete().catchError((_) {});
      await newAuthUser?.delete().catchError((_) {});
      throw UserAdminException(_friendlyFirestoreMessage(e));
    } finally {
      if (secondaryApp != null) {
        await FirebaseAuth.instanceFor(app: secondaryApp).signOut().catchError((_) {});
        await secondaryApp.delete();
      }
    }
  }

  Future<void> updateUser({
    required UserModel existing,
    required String firstName,
    required String lastName,
    required String username,
    required String contactNumber,
    required String role,
    required String branch,
    required String status,
    String profileImageUrl = '',
  }) async {
    final callerUid = _callerUidOrThrow;
    final isSelf = callerUid == existing.uid;
    final cleanUsername = username.trim();

    if (cleanUsername != existing.username) {
      final newUsernameRef = _db.collection('usernames').doc(cleanUsername);
      try {
        await _db.runTransaction((tx) async {
          final existingDoc = await tx.get(newUsernameRef);
          if (existingDoc.exists) {
            throw const UserAdminException('That username is already taken.');
          }
          tx.set(newUsernameRef, {
            'reservedAt': FieldValue.serverTimestamp(),
            'reservedBy': callerUid,
          });
          if (existing.username.trim().isNotEmpty) {
            tx.delete(_db.collection('usernames').doc(existing.username.trim()));
          }
        });
      } on UserAdminException {
        rethrow;
      } on FirebaseException catch (e) {
        throw UserAdminException(_friendlyFirestoreMessage(e));
      }
    }

    final payload = <String, dynamic>{
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'name': '${firstName.trim()} ${lastName.trim()}'.trim(),
      'username': cleanUsername,
      'contact_number': contactNumber.trim(),
      'profile_image_url': profileImageUrl.trim(),
      'updated_at': FieldValue.serverTimestamp(),
      'updated_by': callerUid,
    };

    // Only an admin editing someone ELSE's account may change
    // role/branch/status — matches firestore.rules exactly. A self-edit
    // (e.g. Owner editing their own name) stays limited to identity
    // fields, same as before.
    if (!isSelf) {
      payload.addAll({
        'role': role,
        'branch': branch,
        'status': status,
        'active': status == 'active',
        'permissions': defaultPermissionsForRole(role),
      });
    }

    try {
      await _db.collection('users').doc(existing.uid).update(payload);
    } on FirebaseException catch (e) {
      throw UserAdminException(_friendlyFirestoreMessage(e));
    }
  }

  /// NOTE — Spark-plan limitation: this only flips the Firestore `status`
  /// field. It can NOT disable the person's Firebase Auth account (that
  /// requires the Admin SDK), so a "deactivated" user could still
  /// technically authenticate. The app's sign-in flow must check
  /// `status == 'active'` right after sign-in and sign the person back
  /// out if it isn't — ask me if you'd like that wired into AuthGate.
  Future<void> setStatus(UserModel user, String status) async {
    final callerUid = _callerUidOrThrow;
    if (callerUid == user.uid && user.role == 'Owner' && status != 'active') {
      throw const UserAdminException('Owners cannot deactivate their own account.');
    }
    try {
      await _db.collection('users').doc(user.uid).update({
        'status': status,
        'active': status == 'active',
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': callerUid,
      });
    } on FirebaseException catch (e) {
      throw UserAdminException(_friendlyFirestoreMessage(e));
    }
  }

  Future<void> sendPasswordReset(UserModel user) async {
    _callerUidOrThrow;
    try {
      await _auth.sendPasswordResetEmail(email: user.email);
      await _db.collection('user_activity').add({
        'action': 'Password reset',
        'target_uid': user.uid,
        'target_name': user.displayName.isNotEmpty ? user.displayName : user.email,
        'administrator_uid': _auth.currentUser!.uid,
        'administrator_name': _auth.currentUser!.displayName ?? _auth.currentUser!.email,
        'branch': user.branch,
        'notes': '',
        'created_at': FieldValue.serverTimestamp(),
      });
    } on FirebaseAuthException catch (e) {
      throw UserAdminException(_authErrorMessage(e));
    } on FirebaseException catch (e) {
      throw UserAdminException(_friendlyFirestoreMessage(e));
    }
  }

  String _authErrorMessage(FirebaseAuthException e) {
    return switch (e.code) {
      'email-already-in-use' => 'Email address is already registered.',
      'invalid-email' => 'Enter a valid email address.',
      'weak-password' => 'Password must be at least 8 characters and include a letter and a number.',
      _ => e.message ?? 'Could not create the account. Please try again.',
    };
  }

  String _friendlyFirestoreMessage(FirebaseException e) {
    return switch (e.code) {
      'permission-denied' => "You don't have permission to manage this account.",
      _ => e.message ?? 'Something went wrong. Please try again.',
    };
  }
}