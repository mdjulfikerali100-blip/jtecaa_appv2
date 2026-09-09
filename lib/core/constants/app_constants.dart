// lib/core/constants/app_constants.dart
//
// App-wide constants (Architecture §3 file tree: core/constants/app_constants.dart).
//
// ⚠️ Deliberately does NOT duplicate the department/batch/district lists —
// it re-exports them from the single source of truth in
// lib/core/utils/{departments_helper, batch_helper, districts}.dart.
// StatsRepository (Phase 2, Architecture §8.3) iterates
// `AppConstants.departments`, `AppConstants.knownBatches`, and
// `AppConstants.bdDistricts` when running its `.count()` aggregation
// queries — having those three lists diverge from what the Signup/Profile
// Edit dropdowns actually offer would silently under/over-count the
// dashboard stats, so this file must never hardcode its own copy.

import '../utils/batch_helper.dart';
import '../utils/departments_helper.dart';
import '../utils/districts.dart';

class AppConstants {
  static const String appName = 'JTECAA';
  static const String appFullName = 'JTECAA Alumni Association';
  static const String appTagline = 'Connecting Textile Engineers';

  /// Raw department codes (e.g. "YARN_ENGINEERING") — used wherever a
  /// bounded, known list of departments is needed (DashboardStats.empty(),
  /// StatsRepository's per-department .count() loop, Phase 2).
  static List<String> get departments => Departments.all;

  /// Full batch label strings ("1st Batch" .. "150th Batch") — used by
  /// StatsRepository's Active Batches .count() loop (Architecture §8.3).
  static List<String> get knownBatches => BatchHelper.generateBatchOptions();

  /// All 64 Bangladesh districts — used by StatsRepository's Districts
  /// Covered .count() loop (Architecture §8.3).
  static List<String> get bdDistricts => Districts.all;

  /// Splash screen forced display duration (Architecture Appendix F.7.1).
  static const Duration splashDuration = Duration(seconds: 5);

  /// Directory pagination page size (Architecture §7.3 / §10.1).
  static const int directoryPageSize = 20;

  /// Max profile photo size after compression, in bytes (Architecture §5.4).
  static const int maxPhotoBytes = 300 * 1024;
}
