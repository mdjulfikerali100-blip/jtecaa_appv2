// lib/data/models/system/system_config_model.dart
//
// system/config — Sync Control Center (Architecture §4.2.E).
// Read once per app open (1 Firestore read) to decide whether the Hive
// cache is still valid (§6.5 Cache Invalidation Flow) — this is the
// entire reason the app can stay near-zero reads at 10,000 users.

class SystemConfigModel {
  final int usersVersion; // uv
  final int usersUpdatedAt; // uua — unix seconds
  final int jobsVersion; // jv
  final int jobsUpdatedAt; // jua
  final int newsVersion; // nv
  final int newsUpdatedAt; // nua
  final bool forceRefresh; // fr
  final int maxCacheEntries; // mc
  final int cacheTtlSeconds; // ttl

  const SystemConfigModel({
    required this.usersVersion,
    required this.usersUpdatedAt,
    required this.jobsVersion,
    required this.jobsUpdatedAt,
    required this.newsVersion,
    required this.newsUpdatedAt,
    required this.forceRefresh,
    required this.maxCacheEntries,
    required this.cacheTtlSeconds,
  });

  /// Safe all-zero fallback for a first-ever app run before this device has
  /// ever successfully read `system/config` (e.g. opened once offline).
  /// Zero versions guarantee the very next successful read is treated as
  /// "changed" and triggers a real fetch, rather than silently trusting an
  /// empty cache forever.
  factory SystemConfigModel.empty() => const SystemConfigModel(
        usersVersion: 0,
        usersUpdatedAt: 0,
        jobsVersion: 0,
        jobsUpdatedAt: 0,
        newsVersion: 0,
        newsUpdatedAt: 0,
        forceRefresh: false,
        maxCacheEntries: 10000,
        cacheTtlSeconds: 86400,
      );

  factory SystemConfigModel.fromMap(Map<String, dynamic> map) {
    return SystemConfigModel(
      usersVersion: map['uv'] as int? ?? 0,
      usersUpdatedAt: map['uua'] as int? ?? 0,
      jobsVersion: map['jv'] as int? ?? 0,
      jobsUpdatedAt: map['jua'] as int? ?? 0,
      newsVersion: map['nv'] as int? ?? 0,
      newsUpdatedAt: map['nua'] as int? ?? 0,
      forceRefresh: map['fr'] as bool? ?? false,
      maxCacheEntries: map['mc'] as int? ?? 10000,
      cacheTtlSeconds: map['ttl'] as int? ?? 86400,
    );
  }

  Map<String, dynamic> toMap() => {
        'uv': usersVersion,
        'uua': usersUpdatedAt,
        'jv': jobsVersion,
        'jua': jobsUpdatedAt,
        'nv': newsVersion,
        'nua': newsUpdatedAt,
        'fr': forceRefresh,
        'mc': maxCacheEntries,
        'ttl': cacheTtlSeconds,
      };
}
