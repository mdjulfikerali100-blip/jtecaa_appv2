// lib/data/models/system/system_stats_model.dart
//
// ⚠️ There is NO `system/stats` Firestore document in this architecture
// (Architecture §4.2.F — deliberately removed). Total Alumni, Career
// Status, Departments, Active Batches, and Districts Covered are computed
// live on-device via Firestore `.count()` aggregation queries against
// `users_public` (see StatsRepository, Phase 2), then cached here in Hive
// with a 12h TTL. This model is that cached/computed result — never
// written back to Firestore.

class DashboardStats {
  final int totalAlumni;
  final Map<String, int>
      careerStatus; // {'Employed': x, 'Unemployed': y, 'Higher Studies': z}
  final Map<String, int> departments; // {'YARN_ENGINEERING': x, ...}
  final int activeBatchCount; // distinct batches with ≥1 alumni
  final int districtsCoveredCount; // distinct districts with ≥1 alumni
  final DateTime computedAt;

  const DashboardStats({
    required this.totalAlumni,
    required this.careerStatus,
    required this.departments,
    required this.activeBatchCount,
    required this.districtsCoveredCount,
    required this.computedAt,
  });

  /// Safe zero-filled placeholder — the UI renders this while the first
  /// live computation is in flight, so cards show "0" instead of null, a
  /// spinner, or a "No data yet" error state (Architecture §8.3).
  ///
  /// ⚠️ `departments` here is filled from a fixed list of raw department
  /// codes so the map's *keys* always match what `.count()` queries will
  /// later populate — the actual list lives in `Departments.all`
  /// (lib/core/utils/departments_helper.dart) and is passed in by the
  /// caller rather than hardcoded here, so this model file has no
  /// dependency on the utils layer.
  factory DashboardStats.empty(List<String> departmentCodes) => DashboardStats(
        totalAlumni: 0,
        careerStatus: const {
          'Employed': 0,
          'Unemployed': 0,
          'Higher Studies': 0
        },
        departments: {for (final d in departmentCodes) d: 0},
        activeBatchCount: 0,
        districtsCoveredCount: 0,
        computedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  factory DashboardStats.fromJson(Map<String, dynamic> j) => DashboardStats(
        totalAlumni: j['totalAlumni'] as int? ?? 0,
        careerStatus: Map<String, int>.from(j['careerStatus'] as Map? ?? {}),
        departments: Map<String, int>.from(j['departments'] as Map? ?? {}),
        activeBatchCount: j['activeBatchCount'] as int? ?? 0,
        districtsCoveredCount: j['districtsCoveredCount'] as int? ?? 0,
        computedAt:
            DateTime.fromMillisecondsSinceEpoch(j['computedAt'] as int? ?? 0),
      );

  Map<String, dynamic> toJson() => {
        'totalAlumni': totalAlumni,
        'careerStatus': careerStatus,
        'departments': departments,
        'activeBatchCount': activeBatchCount,
        'districtsCoveredCount': districtsCoveredCount,
        'computedAt': computedAt.millisecondsSinceEpoch,
      };
}
