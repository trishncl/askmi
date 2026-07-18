import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

/// PHASE 2 — minimal so far: exposes the Firebase auth stream reactively.
/// UserProfileProvider and BranchScope (role/branch lookups) get added
/// here in Phase 4, once the `users` collection and role-based shells
/// exist — there's nothing for them to connect to yet, so don't add them
/// early.
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