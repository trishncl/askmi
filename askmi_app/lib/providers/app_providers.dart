import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../repositories/users_repository.dart';
import '../services/auth_service.dart';
import '../core/constants/branch_constants.dart';

/// PHASE 2 — exposes the Firebase auth stream reactively. BranchScope
/// (the Owner's branch filter) still gets added in Phase 4 — there's no
/// Owner dashboard for it to serve yet.
class AuthState extends ChangeNotifier {
  final AuthService _authService;
  User? _user;

  AuthState(this._authService) {
    _authService.authStateChanges.listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  User? get user => _user;
  bool get isSignedIn => _user != null;
  AuthService get service => _authService;
}

/// PHASE 2 — the security-critical piece. Firebase Auth only proves
/// someone signed in; it says nothing about whether they're an Owner,
/// Manager, or Cashier. That lives in Firestore at `users/{uid}` (doc ID
/// = the Auth UID). This watches that document and exposes role/branch —
/// and deliberately does NOT default to any role if the lookup fails.
///
/// `notConfigured` being true is the expected, safe state for a signed-in
/// user with no matching profile doc — AuthGate must route that to a
/// dead-end screen, never to any shell.
class UserProfileProvider extends ChangeNotifier {
  final AuthState _authState;
  final UsersRepository _usersRepository;
  StreamSubscription<UserModel?>? _sub;

  UserModel? profile;
  bool loading = true;
  bool notConfigured = false;
  bool deactivated = false;

  UserProfileProvider(this._authState, {UsersRepository? usersRepository})
      : _usersRepository = usersRepository ?? UsersRepository() {
    _authState.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  void _onAuthChanged() {
    _sub?.cancel();
    final uid = _authState.user?.uid;

    if (uid == null) {
      profile = null;
      loading = false;
      notConfigured = false;
      deactivated = false;
      notifyListeners();
      return;
    }

    loading = true;
    notifyListeners();

    _sub = _usersRepository.watchByUid(uid).listen((user) {
      profile = user;
      notConfigured = user == null;
      // A deactivated account must not reach any shell. Because this is a
      // live stream, an Owner flipping `active` to false takes effect
      // immediately — the user gets kicked to the deactivated screen
      // mid-session, without needing to sign out first.
      deactivated = user != null && !user.active;
      loading = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _authState.removeListener(_onAuthChanged);
    super.dispose();
  }
}

/// PHASE 4 — which branch the Owner is currently filtering the dashboard
/// to. Every dashboard/sales/inventory page reads this instead of keeping
/// its own copy, so the AppBar dropdown drives all of them at once.
///
/// In Phase 5 the Manager shell will lock this to the manager's own branch
/// and hide the selector entirely.
class BranchScope extends ChangeNotifier {
  String _selected = kAllBranches;
  String get selected => _selected;

  /// Null when "All Branches" — repositories treat null as "don't filter".
  String? get filterOrNull => _selected == kAllBranches ? null : _selected;

  void select(String branch) {
    if (branch == _selected) return;
    _selected = branch;
    notifyListeners();
  }
}