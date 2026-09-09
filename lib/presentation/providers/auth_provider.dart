// lib/presentation/providers/auth_provider.dart
//
// Architecture §7.1 (Auth flow) + Master Prompt Phase 3 item 6: "must
// expose the resolved role... so the router can pick the correct shell."
// The role itself is resolved in role_provider.dart (Phase 3B) — this
// file owns only the Firebase-Auth-specific state (signed-in user, email
// verification, sign in/up/out actions).

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/remote/auth_service.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(firebaseAuthProvider));
});

/// Live stream of the signed-in user (or null). Splash (Phase 3) and the
/// eventual root router (Phase 10) both watch this to decide whether to
/// show Login or a home shell.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Convenience derived provider — the current uid, or null if signed out.
final currentUidProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.uid;
});

class AuthController extends StateNotifier<AsyncValue<void>> {
  final AuthService _authService;

  AuthController(this._authService) : super(const AsyncValue.data(null));

  /// Step 1 of signup (Architecture §7.1): create the Firebase Auth
  /// account only. Returns the new uid on success, or null on failure
  /// (check `state.hasError` / `state.error` for the message). Splitting
  /// this out from the Firestore/Sheets profile write lets the calling
  /// screen (Signup, Phase 3) decide what to do if the SECOND step fails
  /// — namely, roll back this Auth account via `rollbackAccount()` so the
  /// same email can be retried cleanly.
  Future<String?> createAccount(
      {required String email, required String password}) async {
    state = const AsyncValue.loading();
    try {
      final credential =
          await _authService.signUp(email: email, password: password);
      state = const AsyncValue.data(null);
      return credential.user?.uid;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// ⚠️ Best-effort rollback: if the profile-creation step (Firestore
  /// WriteBatch for Alumni, or Sheets createStudent for Student) fails
  /// AFTER the Auth account was already created, delete the now-orphaned
  /// Auth account so the same email doesn't permanently hit
  /// "email-already-in-use" with no matching profile anywhere. Not
  /// specified anywhere in the Architecture doc — added because leaving
  /// a half-created account behind with no recovery path would be worse
  /// than the small risk of this delete itself failing.
  Future<void> rollbackAccount() async {
    try {
      await _authService.deleteAccount();
    } catch (_) {
      // Best-effort — nothing more can be safely done automatically here.
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    state = const AsyncValue.loading();
    try {
      await _authService.signIn(email: email, password: password);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    state = const AsyncValue.loading();
    try {
      await _authService.sendPasswordResetEmail(email);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> sendEmailVerification() => _authService.sendEmailVerification();

  Future<void> reloadUser() => _authService.reloadUser();

  bool get isEmailVerified => _authService.isEmailVerified;

  Future<void> signOut() => _authService.signOut();
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(ref.watch(authServiceProvider));
});
