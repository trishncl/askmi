import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// PHASE 2 — minimal so far: sign in/out + password reset. This is
/// intentionally not the full Phase 2 scope from the roadmap (no
/// UserProfileProvider/role lookup yet) — just enough to make the Login
/// screen's Sign In button actually work. Role-based routing gets added
/// when Phase 4's Owner/Manager/Cashier shells exist.
class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  AuthService({FirebaseAuth? auth, FirebaseFunctions? functions})
      : _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn({required String email, required String password}) async {
  final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
  // Best-effort: sign-in should never fail because recordLogin failed.
  unawaited(_recordLoginBestEffort());
  return credential;
}

Future<void> _recordLoginBestEffort() async {
  try {
    await _functions.httpsCallable('recordLogin').call();
  } catch (_) {
    // Ignore — login already succeeded.
  }
}

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() => _auth.signOut();
}