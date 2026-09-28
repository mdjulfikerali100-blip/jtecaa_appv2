// lib/presentation/providers/role_provider.dart
//
// Architecture §M.5: "Cached in Hive after first login ... so it costs
// one Firestore read per device, ever." Also wires §M.9 (FCM topic
// subscription) at the moment a role is resolved.
//
// ⚠️ FIX LOG (this revision):
//   1. `roleProvider` family now `.autoDispose` — previously every
//      `roleProvider(uid)` ever created stayed alive forever.
//   2. `_resolve()` is now idempotent (`_didResolve` flag) — prevents
//      double-resolution race on hot-reload.
//   3. Hive cache read/write wrapped in try/catch — a corrupted box no
//      longer takes down the whole provider.
//   4. `subscribeToRoleTopics` is now `unawaited` — never blocks the
//      role resolution or navigation on FCM network I/O.

import 'dart:async';

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

  bool _didResolve = false;

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

  String get _cacheKey => 'role_$uid';

  Future<void> _resolve() async {
    if (_didResolve) return;
    _didResolve = true;

    // ── Cache lookup (best-effort) ──────────────────────────────
    try {
      final cachedValue = HiveService.get(CacheKeys.myProfileBox, _cacheKey);
      if (cachedValue != null) {
        final role = SignupRoleX.fromWireValue(cachedValue as String);
        if (!mounted) return;
        state = AsyncValue.data(role);
        unawaited(FCMService.subscribeToRoleTopics(role));
        return;
      }
    } catch (_) {
      // Corrupted cache — fall through to Firestore.
    }

    // ── Firestore lookup ────────────────────────────────────────
    try {
      final snap =
          await _firestoreService.getDoc('${FirestorePaths.roles}/$uid');
      SignupRole role;
      if (!snap.exists || snap.data() == null) {
        role = SignupRole.alumni;
      } else {
        role = SignupRoleX.fromWireValue(snap.data()!['role'] as String?);
      }

      try {
        await HiveService.put(
          CacheKeys.myProfileBox,
          _cacheKey,
          role.wireValue,
        );
      } catch (_) {/* cache optional */}

      if (!mounted) return;
      state = AsyncValue.data(role);
      unawaited(FCMService.subscribeToRoleTopics(role));
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteStudentAccountAndData() async {
    await _studentProfileRepository.deleteMyProfile(uid);
    await _authService.deleteAccount();
    try {
      await HiveService.delete(CacheKeys.myProfileBox, _cacheKey);
    } catch (_) {/* ignore */}
  }
}

final roleProvider = StateNotifierProvider.autoDispose
    .family<RoleNotifier, AsyncValue<SignupRole?>, String>(
  (ref, uid) {
    return RoleNotifier(
      firestoreService: ref.watch(firestoreServiceProvider),
      authService: ref.watch(authServiceProvider),
      studentProfileRepository: ref.watch(studentProfileRepositoryProvider),
      uid: uid,
    );
  },
);

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
