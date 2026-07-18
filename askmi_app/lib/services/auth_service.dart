import 'package:firebase_auth/firebase_auth.dart';

/// PHASE 2 — minimal so far: sign in/out + password reset. This is
/// intentionally not the full Phase 2 scope from the roadmap (no
/// UserProfileProvider/role lookup yet) — just enough to make the Login
/// screen's Sign In button actually work. Role-based routing gets added
/// when Phase 4's Owner/Manager/Cashier shells exist.
class AuthService {
  final FirebaseAuth _auth;

  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn({required String email, required String password}) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() => _auth.signOut();
}