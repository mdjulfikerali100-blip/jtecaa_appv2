// lib/data/repositories/directory_repository.dart
//
// Architecture §6.5 Cache Invalidation Flow + §7.3 Alumni Directory +
// §10.1 "Cursor Pagination: 95% initial load reduction (20 docs vs 5000)".
//
// Flow on directory open:
//   1. Read system/config (1 read) — compare `uv` against the last-synced
//      version stored alongside the cached list.
//   2. Version unchanged → serve the full cached list from Hive, 0 reads.
//   3. Version changed (or no cache yet) → fetch page 1 fresh from
//      Firestore, replace the Hive cache, remember the new version.
//   4. Scrolling further pages always hits Firestore directly via cursor
//      pagination — Architecture doesn't specify caching pages 2+, since
//      the whole point of the directory is browsing, not re-reading the
//      same page repeatedly (§2's "never fetch all when you can fetch 20"
//      golden rule, not "never fetch page 2 twice").

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/cache_keys.dart';
import '../../core/constants/firestore_paths.dart';
import '../datasources/local/hive_service.dart';
import '../datasources/remote/firestore_service.dart';
import '../models/user/user_public_model.dart';

class DirectoryPage {
  final List<UserPublicModel> alumni;
  final DocumentSnapshot<Map<String, dynamic>>?
      lastDocument; // cursor for next page
  final bool hasMore;

  const DirectoryPage({
    required this.alumni,
    required this.lastDocument,
    required this.hasMore,
  });
}

class DirectoryRepository {
  final FirestoreService _firestoreService;
  static const String _cacheKey = 'first_page_v1';
  static const String _cacheVersionKey = 'first_page_synced_uv';

  DirectoryRepository(this._firestoreService);

  CollectionReference<Map<String, dynamic>> get _usersPublic =>
      _firestoreService.collection(FirestorePaths.usersPublic);

  /// First page (20 alumni, Architecture §10.1). Cache-first — checks
  /// `system/config.uv` before deciding whether the Hive-cached first
  /// page is still valid.
  Future<DirectoryPage> getFirstPage(
      {bool forceRefresh = false, int pageSize = 20}) async {
    if (!forceRefresh) {
      final cached = await _tryServeFromCache();
      if (cached != null) return cached;
    }

    final config = await _firestoreService.getSystemConfig();
    final snapshot = await _firestoreService.fetchPage(
      query: _usersPublic.orderBy('n'),
      limit: pageSize,
    );

    final alumni =
        snapshot.docs.map((d) => UserPublicModel.fromMap(d.data())).toList();
    await _writeFirstPageToCache(alumni, config.usersVersion);

    return DirectoryPage(
      alumni: alumni,
      lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == pageSize,
    );
  }

  /// Subsequent pages — always a live Firestore cursor fetch (§7.3
  /// "Cursor Pagination: startAfterDocument"). Not cached; only the first
  /// page is, matching the Architecture's own cache-invalidation flow
  /// diagram in §6.5 which only mentions caching the initial list.
  Future<DirectoryPage> getNextPage({
    required DocumentSnapshot<Map<String, dynamic>> after,
    int pageSize = 20,
  }) async {
    final snapshot = await _firestoreService.fetchPage(
      query: _usersPublic.orderBy('n'),
      startAfter: after,
      limit: pageSize,
    );
    final alumni =
        snapshot.docs.map((d) => UserPublicModel.fromMap(d.data())).toList();
    return DirectoryPage(
      alumni: alumni,
      lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == pageSize,
    );
  }

  /// Composite-query filter (Architecture §7.3): department + batch, or
  /// career status, or district — matches the composite indexes listed in
  /// §7.3 ("Composite Indexes Required"). Not cached — filtered results
  /// are inherently query-specific and change too often to be worth a
  /// dedicated cache slot.
  Future<List<UserPublicModel>> filterAlumni({
    String? department,
    String? batch,
    String? district,
    String? careerStatus,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> query = _usersPublic;
    if (department != null) query = query.where('d', isEqualTo: department);
    if (batch != null) query = query.where('b', isEqualTo: batch);
    if (district != null) query = query.where('dist', isEqualTo: district);
    if (careerStatus != null) query = query.where('s', isEqualTo: careerStatus);

    final snapshot =
        await _firestoreService.fetchPage(query: query, limit: limit);
    return snapshot.docs.map((d) => UserPublicModel.fromMap(d.data())).toList();
  }

  Future<DirectoryPage?> _tryServeFromCache() async {
    final rawList = HiveService.get(CacheKeys.alumniPublicBox, _cacheKey);
    final rawVersion =
        HiveService.get(CacheKeys.alumniPublicBox, _cacheVersionKey);
    if (rawList == null || rawVersion == null) return null;

    try {
      final config = await _firestoreService.getSystemConfig();
      if (config.usersVersion != (rawVersion as int)) {
        return null; // version changed — cache is stale, force a real fetch
      }

      final decoded = (jsonDecode(rawList as String) as List)
          .map((e) => UserPublicModel.fromMap(e as Map<String, dynamic>))
          .toList();
      // ⚠️ No cursor is cached (Firestore DocumentSnapshot isn't
      // JSON-serializable), so "load more" after a cache hit re-fetches
      // page 1 live to obtain a real cursor — an acceptable one-time cost
      // per Architecture §2, since this only happens on the very first
      // scroll past a cache-served page.
      return DirectoryPage(
          alumni: decoded, lastDocument: null, hasMore: decoded.length >= 20);
    } catch (_) {
      return null; // corrupted cache — fall through to a live fetch
    }
  }

  Future<void> _writeFirstPageToCache(
      List<UserPublicModel> alumni, int version) async {
    final serializable = alumni
        .map((a) => {
              'uid': a.uid,
              'n': a.fullName,
              'd': a.department,
              'b': a.batch,
              'bg': a.bloodGroup,
              'dist': a.district,
              'cl': a.currentLocation,
              'co': a.company,
              'des': a.designation,
              's': a.careerStatus,
              'purl': a.photoUrl,
              'wa': a.whatsapp,
              'ph': a.phone,
              'fb': a.facebook,
              'li': a.linkedin,
              'ct': a.companyType,
              'gco': a.groupOfCompanies,
              'jd': a.jobDepartment,
              'wx': a.workExperience.map((w) => w.toMap()).toList(),
              'lu': a.lastUpdated,
            })
        .toList();
    await HiveService.put(
        CacheKeys.alumniPublicBox, _cacheKey, jsonEncode(serializable));
    await HiveService.put(CacheKeys.alumniPublicBox, _cacheVersionKey, version);
  }
}
