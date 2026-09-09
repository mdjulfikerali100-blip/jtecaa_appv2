// lib/data/datasources/remote/auth_service.dart
//
// Firebase Auth wrapper shared by BOTH roles (Architecture §M.1: "Firebase
// Auth | Email + Password + email verification (same mechanism)").
//
// ⚠️ Re-exports (does not redefine) AlumniIdValidator/StudentIdValidator —
// see the organizational note at the top of alumni_id_validator.dart for
// why they're implemented as standalone offline files rather than methods
// on this class. Importing this file gives callers access to both the
// Firebase-backed auth flow AND the offline ID validators from one place,
// matching the Master Prompt's mental model of "auth_service.dart handles
// ID verification" without forcing Signup's ID-validation step to load
// Firebase.

import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/errors/exceptions.dart';
//import '../../../core/utils/alumni_id_validator.dart';
//import '../../../core/utils/student_id_validator.dart';

export '../../../core/utils/alumni_id_validator.dart';
export '../../../core/utils/student_id_validator.dart';

class AuthService {
  final FirebaseAuth _auth;

  AuthService(this._auth);

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    }
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    }
  }

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException('No signed-in user to verify.');
    }
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    }
  }

  /// Re-fetches the current user's data from Firebase (needed to pick up
  /// a fresh `emailVerified` value after the user taps the verification
  /// link in their inbox — Architecture §7.1 Verification Gate screen).
  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    }
  }

  Future<void> signOut() => _auth.signOut();

  /// ⚠️ Needed for §M.10's graduation flow — a graduate can delete their
  /// old Student Firebase Auth account (freeing up the email) before or
  /// after signing up fresh as Alumni, and it's also the general
  /// "Delete My Account" action in Settings (Phase 10).
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException('No signed-in user to delete.');
    }
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      // 'requires-recent-login' is the most common real-world case here —
      // Firebase requires a fresh sign-in before allowing account deletion
      // as a security measure. Surface this specific case with a clearer
      // message than Firebase's own wording.
      if (e.code == 'requires-recent-login') {
        throw const AuthException(
          'Please sign in again before deleting your account.',
        );
      }
      throw AuthException(_mapFirebaseAuthError(e));
    }
  }

  String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
