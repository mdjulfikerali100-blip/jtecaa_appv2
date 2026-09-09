// lib/core/constants/cache_keys.dart
//
// Centralized Hive box names + cache TTLs (Architecture §6.2's 4-Tier
// Cache Pyramid table, plus the concrete box names actually used in the
// runnable code samples of §8.3, Appendix J.1, and §M.7).
//
// ⚠️ SPEC INCONSISTENCY RESOLVED: Architecture §6.2's prose table lists a
// box named "stats_cache" (TTL 12h), but §8.3's actual runnable
// StatsRepository code hardcodes `_boxName = 'dashboard_cache'`. This file
// follows the concrete code (`dashboard_cache`) as the source of truth,
// since that's what Phase 2's StatsRepository will actually execute — the
// prose table name was evidently not updated after the code was written.

class CacheKeys {
  // ---- Hive box names ----
  static const String myProfileBox =
      'my_profile'; // opened in main.dart, Phase 0
  static const String alumniPublicBox = 'alumni_public';
  static const String jobsCacheBox = 'jobs_cache';
  static const String newsCacheBox = 'news_cache';
  static const String notifCacheBox = 'notif_cache';
  static const String dashboardCacheBox =
      'dashboard_cache'; // §8.3 concrete name
  static const String imageCacheBox = 'image_cache'; // Appendix J.1
  static const String studentProfileBox = 'student_profile_box'; // §M.7

  // ---- Cache keys within boxes ----
  static const String dashboardStatsKey = 'dashboard_stats_v1'; // §8.3

  // ---- TTLs (Architecture §6.2 table + §8.3 + Appendix J.1 + §M.7) ----
  static const Duration alumniPublicTtl = Duration(hours: 24);
  static const Duration myProfileTtl = Duration(hours: 1);
  static const Duration jobsNewsTtl = Duration(hours: 6);
  static const Duration dashboardStatsTtl = Duration(hours: 12);
  static const Duration notificationsTtl = Duration(days: 7);
  static const Duration imageCacheTtl = Duration(days: 30); // Appendix J.1
  static const Duration studentProfileTtl = Duration(hours: 12); // §M.7
}
