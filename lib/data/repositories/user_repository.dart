// lib/data/repositories/user_repository.dart
//
// Architecture §8: "This architecture uses zero Firebase Cloud Functions
// for user data sync. Every place a Cloud Function would normally rebuild
// or aggregate Firestore data, the Flutter app does it itself with a
// single atomic WriteBatch."
//
// This repository owns:
//   1. Alumni signup — one atomic WriteBatch: users_private + users_public
//      + system/config.uv increment + roles/{uid} (§7.1, §8.2, §M.5).
//   2. syncUserPublic() — the exact client-side rebuild of users_public
//      from users_private, called on signup AND every profile save
//      (§8.2). No privacy filtering anywhere (Appendix E).
//   3. Cache-first reads of the signed-in user's own profile (Hive
//      Tier 2, 1h TTL per §6.2).
//   4. uploadProfilePhoto() (Appendix J.4, Phase 6) — Drive photo upload
//      + purl update, with the old-photo cleanup fix.

import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/cache_keys.dart';
import '../../core/constants/firestore_paths.dart';
import '../../core/errors/exceptions.dart';
import '../datasources/external/drive_image_service.dart';
import '../datasources/local/hive_service.dart';
import '../datasources/remote/firestore_service.dart';
import '../models/user/role_model.dart';
import '../models/user/user_private_model.dart';
import '../models/user/work_experience_model.dart'; // ⚠️ NEW (Phase 6)

class UserRepository {
  final FirestoreService _firestoreService;
  final DriveImageService _driveImageService;

  UserRepository(this._firestoreService, this._driveImageService);

  /// Architecture §7.1 flow:
  /// "Sign Up → Verify Alumni ID offline → Create Auth Account → Client
  /// builds WriteBatch: create users_private + users_public (all fields,
  /// no privacy filtering) → Commit batch → Send verification email"
  ///
  /// The Auth account itself and the offline ID check happen in the
  /// calling code (Signup screen, Phase 3) — this method is called AFTER
  /// both of those succeed, and handles only the Firestore side: three
  /// documents (users_private, users_public, roles/{uid}) plus one field
  /// update (system/config.uv) committed together, atomically.
  Future<void> signUpAlumni({required UserProfileModel profile}) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final batch = _firestoreService.batch();

    // 1. users_private — the full private document, exactly as filled in
    //    the signup form.
    batch.set(
      _firestoreService
          .collection(FirestorePaths.usersPrivate)
          .doc(profile.uid),
      profile.toMap(),
    );

    // 2. users_public — built inline here (not via profile.toMap()) so
    //    the "no privacy filtering, every field copied unconditionally"
    //    rule (Appendix E) is visibly enforced at the one place this
    //    document is ever constructed. See syncUserPublic() below for the
    //    identical logic reused on every subsequent profile edit.
    batch.set(
      _firestoreService.collection(FirestorePaths.usersPublic).doc(profile.uid),
      _buildPublicMap(uid: profile.uid, privateData: profile.toMap(), now: now),
    );

    // 3. system/config.uv — version bump so every other device's next
    //    cache-check (§6.5) notices a new alumnus joined.
    // ⚠️ FIX (root cause): `batch.update()` requires the target document
    // to already exist — on a brand-new Firestore database, `system/config`
    // has never been written yet, so `update()` throws "No document to
    // update". `set(..., SetOptions(merge: true))` self-heals this: it
    // CREATES the doc on the very first write, and MERGES on every write
    // after that (leaving jv/jua/nv/nua/fr/mc/ttl — the fields this app
    // never touches — untouched). FieldValue.increment(1) is correct in
    // both cases: Firestore treats a missing numeric field as 0 before
    // incrementing.
    batch.set(
      _firestoreService.doc(FirestorePaths.systemConfig),
      {
        'uv': FieldValue.increment(1),
        'uua': now,
      },
      SetOptions(merge: true),
    );

    // 4. roles/{uid} — write-once role flag (§M.5). Written in the SAME
    //    atomic batch as the profile documents so a half-finished signup
    //    (e.g. app killed mid-commit) can never leave a role flag without
    //    a matching profile, or vice versa.
    final role =
        RoleModel(uid: profile.uid, role: SignupRole.alumni, createdAt: now);
    batch.set(
      _firestoreService.collection(FirestorePaths.roles).doc(profile.uid),
      role.toMap(),
    );

    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      throw NetworkException('Failed to create your profile: ${e.message}');
    }

    // Prime the Hive cache immediately so the very next screen (e.g.
    // Profile Detail right after signup) renders instantly instead of
    // waiting on a fresh Firestore read (§2 "instant UI" philosophy).
    await _writeProfileToCache(profile);
  }

  /// §M.5 — writes ONLY the role flag, for the Student signup path (which
  /// has no users_private/users_public documents at all — Student PII
  /// lives in Google Sheets, §M.4, handled by StudentProfileRepository).
  Future<void> writeStudentRole(String uid) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final role = RoleModel(uid: uid, role: SignupRole.student, createdAt: now);
    try {
      await _firestoreService
          .collection(FirestorePaths.roles)
          .doc(uid)
          .set(role.toMap());
    } on FirebaseException catch (e) {
      throw NetworkException('Failed to finish signup: ${e.message}');
    }
  }

  /// Architecture §8.2 `syncUserPublic()` — runs on every profile edit
  /// (not just signup). Rebuilds `users_public` fully from the freshly
  /// saved `users_private` data and commits both, plus the version bump,
  /// in one atomic WriteBatch. No `privacy` parameter — Appendix E
  /// removed that concept entirely.
  Future<void> syncUserPublic({
    required String uid,
    required Map<String, dynamic> privateData,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final batch = _firestoreService.batch();

    batch.set(
      _firestoreService.collection(FirestorePaths.usersPrivate).doc(uid),
      {...privateData, 'ua': now},
      SetOptions(merge: true),
    );
    batch.set(
      _firestoreService.collection(FirestorePaths.usersPublic).doc(uid),
      _buildPublicMap(uid: uid, privateData: privateData, now: now),
    );
    // ⚠️ FIX — same self-healing rationale as signUpAlumni() above.
    batch.set(
      _firestoreService.doc(FirestorePaths.systemConfig),
      {
        'uv': FieldValue.increment(1),
        'uua': now,
      },
      SetOptions(merge: true),
    );

    try {
      await batch.commit(); // atomic — either all writes land, or none do
    } on FirebaseException catch (e) {
      throw NetworkException('Failed to save your profile: ${e.message}');
    }

    // ⚠️ FIX (root cause of "edited profile still shows old data"):
    // this method previously committed to Firestore correctly but never
    // touched the local Hive `my_profile` cache (1h TTL, §6.2). Since
    // `getMyProfile()` is cache-first, the very next read — even right
    // after a successful save — could still return stale pre-edit data
    // for up to an hour. Invalidating a Riverpod provider (as the
    // calling screens already do) only forces that provider to re-run;
    // it does NOT clear the underlying Hive entry, so the re-run just
    // read the same stale cache again. Writing the fresh data straight
    // into the cache here closes that gap immediately.
    await _writeProfileToCache(
      UserProfileModel.fromMap({...privateData, 'uid': uid, 'ua': now}),
    );
  }

  /// Every field copied unconditionally — Appendix E: "no toggles, no
  /// filtering logic left in this function". Includes the Appendix
  /// L.1.5 additions (ct/gco/jd/wx) needed for Directory search/filter.
  Map<String, dynamic> _buildPublicMap({
    required String uid,
    required Map<String, dynamic> privateData,
    required int now,
  }) {
    return {
      'uid': uid,
      'n': privateData['n'],
      'lu': now,
      's': privateData['cs'], // Career Status
      'purl': privateData['purl'],
      'd': privateData['d'],
      'b': privateData['b'],
      'bg': privateData['bg'],
      'cl': privateData['cl'],
      'dist': privateData['dist'],
      'co': privateData['co'],
      'des': privateData['des'],
      'ct': privateData['ct'],
      'gco': privateData['gco'],
      'jd': privateData['jd'],
      'exp': privateData['exp'],
      'wx': privateData['wx'],
      'sk': privateData['sk'],
      'bio': privateData['bio'],
      'ph': privateData['ph'],
      'wa': privateData['wa'],
      'li': privateData['li'],
      'fb': privateData['fb'],
    };
  }

  /// Cache-first read of the signed-in user's own profile (§6.2: Hive
  /// TTL 1h for `my_profile`). Falls back to Firestore on a cache miss or
  /// stale cache, then writes through to Hive.
  Future<UserProfileModel> getMyProfile(String uid,
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _readProfileFromCache(uid);
      if (cached != null) return cached;
    }

    final snap =
        await _firestoreService.getDoc('${FirestorePaths.usersPrivate}/$uid');
    if (!snap.exists || snap.data() == null) {
      throw const NetworkException('Profile not found.');
    }
    final profile = UserProfileModel.fromMap(snap.data()!);
    await _writeProfileToCache(profile);
    return profile;
  }

  Future<void> _writeProfileToCache(UserProfileModel profile) async {
    await HiveService.put(
      CacheKeys.myProfileBox,
      profile.uid,
      jsonEncode({
        'data': profile.toMap(),
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  UserProfileModel? _readProfileFromCache(String uid) {
    final raw = HiveService.get(CacheKeys.myProfileBox, uid);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw as String) as Map<String, dynamic>;
      final cachedAt = decoded['cachedAt'] as int? ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - cachedAt;
      if (age > CacheKeys.myProfileTtl.inMilliseconds) return null; // stale
      return UserProfileModel.fromMap(decoded['data'] as Map<String, dynamic>);
    } catch (_) {
      return null; // corrupted cache entry — treat as a miss, not a crash
    }
  }

  /// Architecture Appendix J.4 — pick→compress→upload→update `purl` flow
  /// (compression itself happens in the calling screen, Phase 6, via
  /// `flutter_image_compress`; this method receives already-compressed
  /// bytes so the repository stays free of UI-adjacent image-processing
  /// concerns).
  ///
  /// ⚠️ FIX (promised earlier when the Sheets-structure question came up,
  /// implemented now): Appendix J.4's original code mints a brand-new
  /// timestamped filename on every upload and NEVER deletes the previous
  /// photo's Drive file — silently accumulating orphaned files forever.
  /// This version accepts the caller's current `oldFileId` and deletes it
  /// AFTER the new photo is safely referenced everywhere (users_private +
  /// users_public), so a failure partway through this method never leaves
  /// the profile pointing at an already-deleted fileId.
  Future<String> uploadProfilePhoto({
    required String uid,
    required Uint8List compressedBytes,
    String? oldFileId,
  }) async {
    if (compressedBytes.length > AppConstants.maxPhotoBytes) {
      throw const ValidationException(
          'Image is still too large after compression.');
    }

    final newFileId = await _driveImageService.uploadImage(
      bytes: compressedBytes,
      filename: 'profile_${uid}_${DateTime.now().millisecondsSinceEpoch}',
      mimeType: 'image/jpeg',
    );

    final privateSnap =
        await _firestoreService.getDoc('${FirestorePaths.usersPrivate}/$uid');
    final privateData = privateSnap.data();
    if (privateData == null) {
      throw const NetworkException('Profile not found while updating photo.');
    }
    await syncUserPublic(
        uid: uid, privateData: {...privateData, 'purl': newFileId});

    if (oldFileId != null && oldFileId.isNotEmpty && oldFileId != newFileId) {
      await _driveImageService.deleteImage(oldFileId);
    }

    return newFileId;
  }

  /// Used by Profile Detail's "+ Add Work Experience" (own profile only,
  /// Architecture Appendix F.7.5) — persists immediately rather than
  /// waiting for a full Profile Edit save, since Detail lets an alumnus
  /// add one entry on the spot without navigating to the Edit screen.
  Future<void> updateWorkExperience(
      String uid, List<WorkExperience> workExperience) async {
    final snap =
        await _firestoreService.getDoc('${FirestorePaths.usersPrivate}/$uid');
    final privateData = snap.data();
    if (privateData == null) {
      throw const NetworkException(
          'Profile not found while updating work experience.');
    }
    await syncUserPublic(
      uid: uid,
      privateData: {
        ...privateData,
        'wx': workExperience.map((w) => w.toMap()).toList(),
      },
    );
  }
}
