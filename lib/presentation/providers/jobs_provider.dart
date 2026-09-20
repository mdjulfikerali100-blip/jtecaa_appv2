// lib/presentation/providers/jobs_provider.dart
//
// Architecture §7.5 (Job Board) — wraps JobRepository (Phase 2, 6h Hive
// cache) for the two tabs: Active Jobs and My Posts.
//
// ⚠️ "My Posts" is a client-side filter over the SAME already-fetched
// active-jobs list, not a separate fetch — Architecture never specifies
// a way to retrieve a user's own EXPIRED posts (both the Apps Script
// `getJobs()` and this app's own `JobRepository.getActiveJobs()` filter
// expired jobs out before the data ever reaches this provider), so "My
// Posts" can only ever show the signed-in Alumni's own currently-active
// posts — a documented consequence of how Architecture designed
// expiry (server-side filtering, not a soft-delete flag).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/job/job_post_model.dart';
import 'auth_provider.dart';
import 'core_providers.dart';

final activeJobsProvider =
    FutureProvider.autoDispose<List<JobPostModel>>((ref) {
  return ref.watch(jobRepositoryProvider).getActiveJobs();
});

final myJobsProvider =
    Provider.autoDispose<AsyncValue<List<JobPostModel>>>((ref) {
  final uid = ref.watch(currentUidProvider);
  final jobsAsync = ref.watch(activeJobsProvider);
  return jobsAsync.whenData(
    (jobs) => uid == null
        ? const []
        : jobs.where((j) => j.postedByUid == uid).toList(),
  );
});
