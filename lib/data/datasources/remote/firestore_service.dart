// lib/data/datasources/remote/firestore_service.dart
//
// Thin wrapper around cloud_firestore — cursor pagination (§7.3, §10.1),
// version checking against system/config (§6.5's cache-invalidation
// flow), and WriteBatch access for the client-side sync pattern (§8.2).
// Repositories depend on this instead of importing FirebaseFirestore
// directly, so a future swap (e.g. adding App Check-aware retry logic)
// touches one file, not every repository.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/errors/exceptions.dart';
import '../../models/system/system_config_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService(this._firestore);

  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _firestore.collection(path);

  DocumentReference<Map<String, dynamic>> doc(String path) =>
      _firestore.doc(path);

  WriteBatch batch() => _firestore.batch();

  /// Reads `system/config` (Architecture §4.2.E) — the 1-read-per-app-open
  /// version document that drives whether Hive-cached lists are still
  /// valid (§6.5). Never throws: a missing/unreachable config doc falls
  /// back to `SystemConfigModel.empty()`, which has all-zero versions —
  /// guaranteeing the very next successful read is treated as "changed"
  /// rather than the app trusting a stale cache forever.
  Future<SystemConfigModel> getSystemConfig() async {
    try {
      final snap = await doc(FirestorePaths.systemConfig).get();
      if (!snap.exists || snap.data() == null) {
        return SystemConfigModel.empty();
      }
      return SystemConfigModel.fromMap(snap.data()!);
    } catch (_) {
      return SystemConfigModel.empty();
    }
  }

  /// Generic cursor-paginated fetch (Architecture §7.3 "Cursor
  /// Pagination", §10.1 cost table: "20 docs vs 5000").
  Future<QuerySnapshot<Map<String, dynamic>>> fetchPage({
    required Query<Map<String, dynamic>> query,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 20,
  }) async {
    try {
      var q = query.limit(limit);
      if (startAfter != null) {
        q = q.startAfterDocument(startAfter);
      }
      return await q.get();
    } on FirebaseException catch (e) {
      throw NetworkException(_mapFirestoreError(e));
    }
  }

  /// Single-document read with a friendly error on failure — used by
  /// repositories that don't need pagination (e.g. reading one profile).
  Future<DocumentSnapshot<Map<String, dynamic>>> getDoc(String path) async {
    try {
      return await doc(path).get();
    } on FirebaseException catch (e) {
      throw NetworkException(_mapFirestoreError(e));
    }
  }

  /// `.count()` aggregation query (Architecture §8.3) — billed at roughly
  /// 1 read per 1,000 index entries scanned, not per matched document,
  /// which is what keeps StatsRepository cheap even against 10,000 docs.
  Future<int> countQuery(Query<Map<String, dynamic>> query) async {
    try {
      final snap = await query.count().get();
      return snap.count ?? 0;
    } on FirebaseException catch (e) {
      throw NetworkException(_mapFirestoreError(e));
    }
  }

  String _mapFirestoreError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'You don\'t have permission to do that.';
      case 'unavailable':
        return 'Service temporarily unavailable. Check your connection.';
      case 'not-found':
        return 'The requested data could not be found.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}
