// lib/data/datasources/local/hive_service.dart
//
// Thin wrapper over Hive (Architecture §6.2, Tier 2 of the 4-tier cache
// pyramid). Every box name is read from CacheKeys (Phase 1) rather than
// typed as a literal string here or in any repository — a typo'd box name
// would otherwise silently create a second, always-empty box instead of
// throwing, which is exactly the kind of bug that "works on Chrome" and
// then confuses everyone on a real device weeks later.
//
// ⚠️ EDIT REQUIRED to lib/main.dart (Phase 0): replace the single
// `await Hive.openBox('my_profile');` line with
// `await HiveService.initBoxes();` — see the separate main.dart update
// note in this phase's file list. Opening 'my_profile' twice under two
// different code paths would not crash, but it duplicates the
// responsibility this file now owns.

import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/constants/cache_keys.dart';
import '../../../core/errors/exceptions.dart';

class HiveService {
  /// Initializes Hive itself AND opens every box the app uses, once, at
  /// startup. Safe to call more than once — `Hive.openBox` is a no-op if
  /// the box is already open.
  ///
  /// ⚠️ ROOT CAUSE (self-caught before shipping): main.dart's Phase 0
  /// version called `Hive.initFlutter()` directly before opening its one
  /// box. When that responsibility moved here in Phase 2, the
  /// `Hive.initFlutter()` call itself was almost left behind in main.dart
  /// — which would have crashed every `Hive.openBox()` call below with
  /// "HiveError: You need to initialize Hive". Both steps now live
  /// together in this one method precisely so they can never be split
  /// across two files again.
  static Future<void> initBoxes() async {
    try {
      await Hive.initFlutter();
      await Future.wait([
        Hive.openBox(CacheKeys.myProfileBox),
        Hive.openBox(CacheKeys.alumniPublicBox),
        Hive.openBox(CacheKeys.jobsCacheBox),
        Hive.openBox(CacheKeys.newsCacheBox),
        Hive.openBox(CacheKeys.notifCacheBox),
        Hive.openBox(CacheKeys.dashboardCacheBox),
        Hive.openBox(CacheKeys.imageCacheBox),
        Hive.openBox(CacheKeys.studentProfileBox),
      ]);
    } catch (e) {
      // ⚠️ A corrupted Hive box (e.g. app was killed mid-write) must never
      // crash app startup — the app should still boot and simply behave
      // as if the cache were empty, falling back to network fetches.
      throw CacheException('Local cache failed to initialize: $e');
    }
  }

  static Box box(String boxName) => Hive.box(boxName);

  /// Synchronous read — Hive boxes are read synchronously once opened.
  /// Returns null if the key doesn't exist, never throws.
  static dynamic get(String boxName, String key) {
    try {
      return box(boxName).get(key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> put(String boxName, String key, dynamic value) async {
    try {
      await box(boxName).put(key, value);
    } catch (e) {
      throw CacheException('Failed to write to local cache: $e');
    }
  }

  static Future<void> delete(String boxName, String key) async {
    try {
      await box(boxName).delete(key);
    } catch (_) {
      // Deleting a non-existent/already-corrupt key is not worth
      // surfacing as an error to the caller.
    }
  }

  /// Wipes a single box — used on logout so the next user on a shared
  /// device never sees the previous alumnus's cached profile/directory.
  static Future<void> clearBox(String boxName) async {
    try {
      await box(boxName).clear();
    } catch (_) {
      // Best-effort — a failed clear on logout shouldn't block sign-out.
    }
  }

  /// Wipes every box this app owns — called on logout for a full reset.
  static Future<void> clearAll() async {
    await Future.wait([
      clearBox(CacheKeys.myProfileBox),
      clearBox(CacheKeys.alumniPublicBox),
      clearBox(CacheKeys.jobsCacheBox),
      clearBox(CacheKeys.newsCacheBox),
      clearBox(CacheKeys.notifCacheBox),
      clearBox(CacheKeys.dashboardCacheBox),
      // ⚠️ Deliberately NOT clearing imageCacheBox on logout — cached
      // photos are keyed by Drive fileId, not by uid, so they're still
      // valid for whoever logs in next and clearing them would just
      // waste bandwidth re-downloading the same images.
      clearBox(CacheKeys.studentProfileBox),
    ]);
  }
}
