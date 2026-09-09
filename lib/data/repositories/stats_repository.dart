// lib/data/repositories/stats_repository.dart
//
// Architecture §8.3 — Total Alumni, Career Status, Departments, Active
// Batches, and Districts Covered are computed LIVE on-device via
// Firestore `.count()` aggregation queries against `users_public`. No
// `system/stats` document exists anywhere — see the CacheKeys.dart note
// on why the box is literally named `dashboard_cache` (matching this
// section's own code) rather than `stats_cache` (§6.2's prose table).

import 'dart:convert';

import '../../core/constants/app_constants.dart';
import '../../core/constants/cache_keys.dart';
import '../../core/constants/firestore_paths.dart';
import '../datasources/local/hive_service.dart';
import '../datasources/remote/firestore_service.dart';
import '../models/system/system_stats_model.dart';

class StatsRepository {
  final FirestoreService _firestoreService;

  StatsRepository(this._firestoreService);

  /// Always returns a usable DashboardStats — never throws, never null.
  /// Architecture §8.3: "the app caches the computed result locally
  /// (Hive, TTL) ... and always has a safe zero-filled fallback so the
  /// dashboard never shows 'No data yet' or a null error."
  Future<DashboardStats> getDashboardStats({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _readCache();
      if (cached != null &&
          DateTime.now().difference(cached.computedAt) <
              CacheKeys.dashboardStatsTtl) {
        return cached; // 0 Firestore reads — served from Hive
      }
    }
    try {
      final live = await _computeLive();
      await _writeCache(live);
      return live;
    } catch (_) {
      // Offline, App Check hiccup, etc. — serve stale cache rather than
      // showing an error; fall back to a zero-filled stats object only if
      // this device has never computed stats before.
      return _readCache() ?? DashboardStats.empty(AppConstants.departments);
    }
  }

  Future<DashboardStats> _computeLive() async {
    final usersPublic =
        _firestoreService.collection(FirestorePaths.usersPublic);

    // 1. Total Alumni — a single, cheap .count() query. No filter needed.
    final total = await _firestoreService.countQuery(usersPublic);

    // 2. Career Status, bucketed into 3 UI groups from the 5 raw values.
    final employed = await _firestoreService.countQuery(
      usersPublic.where('s', isEqualTo: 'Job Holder'),
    );
    final unemployed = await _firestoreService.countQuery(
      usersPublic.where('s', isEqualTo: 'Looking for a Job'),
    );
    final higherStudies = await _firestoreService.countQuery(
      usersPublic.where('s', whereIn: [
        'Higher Studies',
        'Preparing for Higher Studies',
        'Preparing for a Government Job',
      ]),
    );

    // 3. Departments — 4 known enum values (AppConstants.departments).
    final departmentCounts = <String, int>{};
    for (final dept in AppConstants.departments) {
      departmentCounts[dept] = await _firestoreService.countQuery(
        usersPublic.where('d', isEqualTo: dept),
      );
    }

    // 4. Active Batches — bounded, known list of valid batch strings.
    // ⚠️ This loop runs up to 150 .count() queries (one per possible
    // batch). Architecture §8.3 accepts this cost explicitly ("a handful
    // of billed reads per device per 12h refresh — comfortably inside the
    // Spark free tier at this app's scale") — flagged here again so it's
    // not mistaken for an oversight if Firebase Console usage looks high
    // on a device with a cold/expired cache.
    var activeBatches = 0;
    for (final batch in AppConstants.knownBatches) {
      final c = await _firestoreService
          .countQuery(usersPublic.where('b', isEqualTo: batch));
      if (c > 0) activeBatches++;
    }

    // 5. Districts Covered — Bangladesh's fixed 64-district list.
    var districtsCovered = 0;
    for (final dist in AppConstants.bdDistricts) {
      final c = await _firestoreService
          .countQuery(usersPublic.where('dist', isEqualTo: dist));
      if (c > 0) districtsCovered++;
    }

    return DashboardStats(
      totalAlumni: total,
      careerStatus: {
        'Employed': employed,
        'Unemployed': unemployed,
        'Higher Studies': higherStudies,
      },
      departments: departmentCounts,
      activeBatchCount: activeBatches,
      districtsCoveredCount: districtsCovered,
      computedAt: DateTime.now(),
    );
  }

  Future<void> _writeCache(DashboardStats stats) async {
    await HiveService.put(
      CacheKeys.dashboardCacheBox,
      CacheKeys.dashboardStatsKey,
      jsonEncode(stats.toJson()),
    );
  }

  DashboardStats? _readCache() {
    final raw = HiveService.get(
        CacheKeys.dashboardCacheBox, CacheKeys.dashboardStatsKey);
    if (raw == null) return null;
    try {
      return DashboardStats.fromJson(
          jsonDecode(raw as String) as Map<String, dynamic>);
    } catch (_) {
      return null; // corrupted/missing cache — treat as "no stats yet"
    }
  }
}
