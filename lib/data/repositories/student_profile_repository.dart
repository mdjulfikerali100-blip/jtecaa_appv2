// lib/data/repositories/student_profile_repository.dart
//
// Architecture §M.7 — Student profile data lives in Google Sheets, which
// has no automatic offline-persistence tier the way the Firestore SDK
// does (§6.3). This repository adds its OWN lightweight 2-tier cache
// (Memory via the caller's Riverpod provider, Hive on disk) so a Student
// still gets instant, cache-first profile reads with the same
// "instant UI" philosophy (§2) as the Alumni side.
//
// ⚠️ CHANGED: now depends on StudentSheetsProxy (its own, completely
// separate Google Sheet + Apps Script deployment), not the original
// combined GoogleSheetsProxy — per explicit user decision to keep
// Students in an entirely independent spreadsheet from Jobs+News.

import 'dart:convert';

import '../../core/constants/cache_keys.dart';
import '../../core/errors/exceptions.dart';
import '../datasources/external/student_sheets_proxy.dart';
import '../datasources/local/hive_service.dart';
import '../models/user/student_profile_model.dart';

class StudentProfileRepository {
  final StudentSheetsProxy _proxy;

  StudentProfileRepository(this._proxy);

  /// §M.4 `createStudent` — called once, at signup, right after the
  /// Firebase Auth account and `roles/{uid}` write have already
  /// succeeded (see UserRepository.writeStudentRole). Not present in the
  /// original Phase 2 delivery — added now because the Student signup
  /// flow (Phase 3) has nowhere else to create the initial Sheet row.
  Future<void> createProfile(StudentProfileModel profile) async {
    await _proxy.createStudent(profile.toCreateBody());
    await _writeToCache(profile);
  }

  /// Tier 2 (Hive, 12h TTL) → Tier 3 (Sheets network) on miss/stale.
  Future<StudentProfileModel> getMyProfile(String uid,
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _readFromCache(uid);
      if (cached != null) return cached;
    }

    final data = await _proxy.getStudentByUid(uid);
    if (data == null) {
      throw const NetworkException('Student profile not found.');
    }
    final profile = StudentProfileModel.fromMap(data);
    await _writeToCache(profile);
    return profile;
  }

  /// §M.7: "Called right after a successful updateStudent POST — updates
  /// the Hive cache immediately so the UI never shows stale data after an
  /// edit, without waiting for the next 12h refresh window." No
  /// restriction on when/how often a Student may call this (§M.1).
  Future<void> updateMyProfile(
      String uid, Map<String, dynamic> changedFields) async {
    await _proxy.updateStudent(uid, changedFields);

    final cached = _readRawFromCache(uid) ?? {};
    final merged = {
      ...cached,
      ...changedFields,
      'updated_at': DateTime.now().toIso8601String(),
    };
    await HiveService.put(
      CacheKeys.studentProfileBox,
      uid,
      jsonEncode({
        'data': merged,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  /// §M.4/§M.10 — used only by the "delete my old Student row now instead
  /// of waiting 7 years" cleanup action, not part of normal usage.
  Future<void> deleteMyProfile(String uid) async {
    await _proxy.deleteStudent(uid);
    await HiveService.delete(CacheKeys.studentProfileBox, uid);
  }

  StudentProfileModel? _readFromCache(String uid) {
    final raw = _readRawFromCache(uid);
    if (raw == null) return null;
    return StudentProfileModel.fromMap(raw);
  }

  Map<String, dynamic>? _readRawFromCache(String uid) {
    final raw = HiveService.get(CacheKeys.studentProfileBox, uid);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw as String) as Map<String, dynamic>;
      final cachedAt = decoded['cachedAt'] as int? ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - cachedAt;
      if (age > CacheKeys.studentProfileTtl.inMilliseconds) return null;
      return decoded['data'] as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeToCache(StudentProfileModel profile) async {
    await HiveService.put(
      CacheKeys.studentProfileBox,
      profile.uid,
      jsonEncode({
        'data': {
          'uid': profile.uid,
          'full_name': profile.fullName,
          'phone': profile.phone,
          'batch': profile.batch,
          'blood_group': profile.bloodGroup,
          'district': profile.district,
          'current_location': profile.currentLocation,
          'email': profile.email,
          'created_at': profile.createdAt.toIso8601String(),
          'updated_at': profile.updatedAt.toIso8601String(),
        },
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }
}
