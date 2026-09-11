// lib/presentation/providers/dashboard_provider.dart
//
// Architecture §8.3 (live client-side stats aggregation) + §7.2 (Home
// Dashboard data sources: Job Circular Preview, Recent Alumni).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/job/job_post_model.dart';
import '../../data/models/system/system_stats_model.dart';
import '../../data/models/user/user_private_model.dart';
import '../../data/models/user/user_public_model.dart';
import 'auth_provider.dart';
import 'core_providers.dart';

/// Architecture §8.3 — always resolves to a usable DashboardStats, never
/// throws (the repository itself guarantees this), so the UI never has
/// to special-case null/error for the stat cards or donut chart.
final dashboardStatsProvider =
    FutureProvider.autoDispose<DashboardStats>((ref) {
  return ref.watch(statsRepositoryProvider).getDashboardStats();
});

/// Architecture §7.2 "Job Circular Preview" — top few active jobs for the
/// Home Dashboard's horizontal list. Reuses JobRepository's own 6h Hive
/// cache (Phase 2) rather than adding a second cache layer here.
final recentJobsProvider =
    FutureProvider.autoDispose<List<JobPostModel>>((ref) async {
  final jobs = await ref.watch(jobRepositoryProvider).getActiveJobs();
  return jobs.take(5).toList();
});

/// Architecture §7.2 "Recent Alumni".
final recentAlumniProvider =
    FutureProvider.autoDispose<List<UserPublicModel>>((ref) {
  return ref.watch(directoryRepositoryProvider).getRecentAlumni();
});

/// Cache-first fetch of the signed-in Alumni's own profile, for the
/// Greeting Card (name, batch, department, career status chip).
final myAlumniProfileProvider =
    FutureProvider.autoDispose<UserProfileModel>((ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) {
    throw StateError('myAlumniProfileProvider watched while signed out.');
  }
  return ref.watch(userRepositoryProvider).getMyProfile(uid);
});

/// ⚠️ Forward-looking hand-off mechanism: the Donut Chart's segment tap
/// (Appendix F.6.O step 3: "Pre-apply career status filter") needs
/// somewhere to stash the tapped category before navigating to the
/// Directory tab, since DirectoryScreen (Phase 5) doesn't exist yet to
/// read it directly. Phase 5's directory_provider.dart will read this
/// value on init and clear it after applying the filter once.
final pendingDirectoryFilterProvider = StateProvider<String?>((ref) => null);
