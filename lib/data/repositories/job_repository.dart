// lib/data/repositories/job_repository.dart
//
// Architecture §5.3 (Sheets proxy + Hive cache) + §7.5 (Job Board) +
// Appendix L.2.1 ("Posted by" fields). Jobs live entirely in Google
// Sheets — this repository never touches Firestore.

import 'dart:convert';

import '../../core/constants/cache_keys.dart';
import '../datasources/external/google_sheets_proxy.dart';
import '../datasources/local/hive_service.dart';
import '../models/job/job_post_model.dart';

class JobRepository {
  final GoogleSheetsProxy _proxy;
  static const String _cacheKey = 'jobs_list_v1';

  JobRepository(this._proxy);

  /// Cache-first (§6.2 TTL table: jobs/news = 6h, `CacheKeys.jobsNewsTtl`).
  /// Falls back to a live Sheets fetch on cache miss/stale/forced refresh,
  /// then writes through.
  Future<List<JobPostModel>> getActiveJobs({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _readFromCache();
      if (cached != null) return cached;
    }

    final raw = await _proxy.getJobs();
    final jobs = raw
        .map((j) => JobPostModel.fromMap(j as Map<String, dynamic>))
        // ⚠️ Belt-and-suspenders: the Apps Script side (Appendix I.1
        // getJobs()) already filters out jobs past deadline+5h, but
        // filtering again client-side means a stale cache entry never
        // shows an expired job even if it hasn't been re-fetched since
        // it expired.
        .where((j) => !j.isExpired)
        .toList();

    await _writeToCache(jobs);
    return jobs;
  }

  Future<Map<String, dynamic>> postJob(Map<String, dynamic> jobData) async {
    final result = await _proxy.postJob(jobData);
    // Invalidate the cache so the poster's own new listing shows up
    // immediately on their next Jobs screen visit, rather than waiting up
    // to 6h for the TTL to naturally expire.
    await _invalidateCache();
    return result;
  }

  Future<Map<String, dynamic>> editJob(Map<String, dynamic> jobData) async {
    final result = await _proxy.editJob(jobData);
    await _invalidateCache();
    return result;
  }

  Future<Map<String, dynamic>> deleteJob(String id) async {
    final result = await _proxy.deleteJob(id);
    await _invalidateCache();
    return result;
  }

  List<JobPostModel>? _readFromCache() {
    final raw = HiveService.get(CacheKeys.jobsCacheBox, _cacheKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw as String) as Map<String, dynamic>;
      final cachedAt = decoded['cachedAt'] as int? ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - cachedAt;
      if (age > CacheKeys.jobsNewsTtl.inMilliseconds) return null;
      return (decoded['data'] as List)
          .map((j) => JobPostModel.fromMap(j as Map<String, dynamic>))
          .where((j) => !j.isExpired)
          .toList();
    } catch (_) {
      return null; // corrupted cache entry — treat as a miss, not a crash
    }
  }

  Future<void> _writeToCache(List<JobPostModel> jobs) async {
    final serializable = jobs
        .map((j) => {
              'id': j.id,
              'title': j.title,
              'company': j.company,
              'description': j.description,
              'deadline': j.deadline,
              'apply_link': j.applyLink,
              'apply_email': j.applyEmail,
              'apply_phone': j.applyPhone,
              'apply_whatsapp': j.applyWhatsapp,
              'posted_by': j.postedByUid,
              'posted_by_name': j.postedByName,
              'posted_by_batch': j.postedByBatch,
              'posted_at': j.postedAt.toIso8601String(),
              'auto_delete_days': j.autoDeleteDays,
            })
        .toList();
    await HiveService.put(
      CacheKeys.jobsCacheBox,
      _cacheKey,
      jsonEncode({
        'data': serializable,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  Future<void> _invalidateCache() async {
    await HiveService.delete(CacheKeys.jobsCacheBox, _cacheKey);
  }
}
