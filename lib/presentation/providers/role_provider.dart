// lib/presentation/providers/role_provider.dart
//
// Architecture §M.5: "Cached in Hive after first login ... so it costs
// one Firestore read per device, ever." Also wires §M.9 (FCM topic
// subscription) at the moment a role is resolved, since that's the one
// place in the app that always runs exactly once per role-resolution,
// regardless of whether the user just signed up or is returning from a
// cache hit.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/cache_keys.dart';
import '../../core/constants/firestore_paths.dart';
import '../../data/datasources/local/hive_service.dart';
import '../../data/datasources/remote/auth_service.dart';
import '../../data/datasources/remote/fcm_service.dart';
import '../../data/datasources/remote/firestore_service.dart';
import '../../data/models/user/role_model.dart';
import '../../data/repositories/student_profile_repository.dart';
import 'auth_provider.dart';
import 'core_providers.dart';

class RoleNotifier extends StateNotifier<AsyncValue<SignupRole?>> {
  final FirestoreService _firestoreService;
  final AuthService _authService;
  final StudentProfileRepository _studentProfileRepository;
  final String uid;

  RoleNotifier({
    required FirestoreService firestoreService,
    required AuthService authService,
    required StudentProfileRepository studentProfileRepository,
    required this.uid,
  })  : _firestoreService = firestoreService,
        _authService = authService,
        _studentProfileRepository = studentProfileRepository,
        super(const AsyncValue.loading()) {
    _resolve();
  }

  // ⚠️ Reuses `myProfileBox` with a compound key (`role_$uid`) rather than
  // opening a brand-new Hive box just to store one short string per user
  // — the role flag is tiny and conceptually part of "what this device
  // knows about the signed-in user", same as the cached profile itself.
  String get _cacheKey => 'role_$uid';

  Future<void> _resolve() async {
    final cachedValue = HiveService.get(CacheKeys.myProfileBox, _cacheKey);
    if (cachedValue != null) {
      final role = SignupRoleX.fromWireValue(cachedValue as String);
      state = AsyncValue.data(role);
      await FCMService.subscribeToRoleTopics(role); // §M.9
      return; // §M.5 — zero Firestore reads on a cache hit
    }

    try {
      final snap =
          await _firestoreService.getDoc('${FirestorePaths.roles}/$uid');
      SignupRole role;
      if (!snap.exists || snap.data() == null) {
        // Shouldn't normally happen — roles/{uid} is written atomically
        // at signup (UserRepository.signUpAlumni / writeStudentRole) —
        // but defaulting to Alumni here means a missing/corrupted role
        // doc degrades to the FULLER shell rather than leaving the user
        // stuck on an infinite loading spinner.
        role = SignupRole.alumni;
      } else {
        role = SignupRoleX.fromWireValue(snap.data()!['role'] as String?);
      }
      await HiveService.put(CacheKeys.myProfileBox, _cacheKey, role.wireValue);
      state = AsyncValue.data(role);
      await FCMService.subscribeToRoleTopics(role); // §M.9
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// §M.10 — "Optional cleanup: if a graduate wants their old Student row
  /// gone immediately (not waiting 7 years)". Deletes the Student's Sheet
  /// row AND their Firebase Auth account together. Does not attempt to
  /// delete `roles/{uid}` itself (Security Rules make that doc
  /// write-once, not delete-able by the client anyway, and once the Auth
  /// account is gone the uid is inert — Architecture §M.10 already
  /// accepts leaving the old role/account artifacts to age out naturally).
  Future<void> deleteStudentAccountAndData() async {
    await _studentProfileRepository.deleteMyProfile(uid);
    await _authService.deleteAccount();
    await HiveService.delete(CacheKeys.myProfileBox, _cacheKey);
  }
}

final roleProvider =
    StateNotifierProvider.family<RoleNotifier, AsyncValue<SignupRole?>, String>(
  (ref, uid) {
    return RoleNotifier(
      firestoreService: ref.watch(firestoreServiceProvider),
      authService: ref.watch(authServiceProvider),
      studentProfileRepository: ref.watch(studentProfileRepositoryProvider),
      uid: uid,
    );
  },
);

/// Convenience combinator — resolves the CURRENT signed-in user's role in
/// one watch, or `AsyncValue.data(null)` if signed out. This is what
/// SplashScreen and (later) Phase 10's root router actually watch, rather
/// than manually chaining authStateProvider + roleProvider themselves.
final myRoleProvider = Provider<AsyncValue<SignupRole?>>((ref) {
  final authState = ref.watch(authStateProvider);
  if (authState.isLoading) {
    return const AsyncValue.loading();
  }
  if (authState.hasError) {
    return AsyncValue.error(authState.error!, authState.stackTrace!);
  }
  final user = authState.value;
  if (user == null) {
    return const AsyncValue.data(null);
  }
  return ref.watch(roleProvider(user.uid));
});
