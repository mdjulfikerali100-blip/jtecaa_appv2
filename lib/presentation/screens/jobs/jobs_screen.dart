// lib/presentation/screens/jobs/jobs_screen.dart
//
// Architecture §7.5 (Job Board) — TabBar: Active Jobs | My Posts.
//
// ⚠️ Students never see this screen or route at all (§M.1, §M.6) — this
// file is only ever reached from the Alumni shell (home_screen.dart).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/job/job_post_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/jobs_provider.dart';
import '../../widgets/common/job_card.dart';
import '../../widgets/common/job_detail_bottom_sheet.dart';
import 'post_job_screen.dart';

class JobsScreen extends ConsumerStatefulWidget {
  const JobsScreen({super.key});

  @override
  ConsumerState<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends ConsumerState<JobsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openDetail(JobPostModel job) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => JobDetailBottomSheet(job: job),
    );
  }

  Future<void> _confirmDelete(JobPostModel job) async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Delete this job post?',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        content: Text(
          job.title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await ref.read(jobRepositoryProvider).deleteJob(job.id);
      ref.invalidate(activeJobsProvider);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not delete: $e',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Job Board',
          style: theme.textTheme.titleLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        iconTheme: IconThemeData(
          color: colorScheme.onSurface,
          size: 24,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TabBar(
              controller: _tabController,
              isScrollable: false,
              labelColor: colorScheme.primary,
              unselectedLabelColor: colorScheme.onSurfaceVariant,
              labelStyle: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
              unselectedLabelStyle: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              indicatorColor: colorScheme.primary,
              indicatorWeight: 2.5,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: colorScheme.outlineVariant.withValues(alpha: 0.4),
              tabs: const [
                Tab(
                  height: 48,
                  child: Text(
                    'Active Jobs',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Tab(
                  height: 48,
                  child: Text(
                    'My Posts',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildJobList(
            activeJobsProvider,
            emptyMessage: 'No active jobs',
            emptySubtitle: 'Be the first to post!',
          ),
          _buildMyPostsList(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PostJobScreen()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Post Job',
          style: theme.textTheme.labelLarge?.copyWith(
            color: colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: 2,
      ),
    );
  }

  Widget _buildJobList(
    // ⚠️ FIX: `activeJobsProvider` is declared with `.autoDispose`
    // (jobs_provider.dart), which produces an
    // `AutoDisposeFutureProvider<T>` — a different, more specific type
    // than the plain `FutureProvider<T>` this parameter was typed as.
    // Matching the exact provider type here (rather than the generic
    // base) is what the analyzer needs to accept the argument.
    AutoDisposeFutureProvider<List<JobPostModel>> provider, {
    required String emptyMessage,
    required String emptySubtitle,
  }) {
    final jobsAsync = ref.watch(provider);
    final myUid = ref.watch(currentUidProvider);

    return jobsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => _buildErrorState(
        message: 'Could not load jobs',
        error: e,
        onRetry: () => ref.invalidate(provider),
      ),
      data: (jobs) {
        if (jobs.isEmpty) {
          return _buildEmptyState(emptyMessage, emptySubtitle);
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(activeJobsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 96), // FAB clearance
            itemCount: jobs.length,
            itemBuilder: (context, i) {
              final job = jobs[i];
              final isOwner = myUid != null && job.postedByUid == myUid;
              return JobCard(
                job: job,
                isOwner: isOwner,
                onTap: () => _openDetail(job),
                onEdit: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PostJobScreen(existingJob: job),
                  ),
                ),
                onDelete: () => _confirmDelete(job),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMyPostsList() {
    final jobsAsync = ref.watch(myJobsProvider);
    final myUid = ref.watch(currentUidProvider);

    return jobsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => _buildErrorState(
        message: 'Could not load your posts',
        error: e,
        onRetry: () => ref.invalidate(myJobsProvider),
      ),
      data: (jobs) {
        if (jobs.isEmpty) {
          return _buildEmptyState(
            "You haven't posted any jobs yet",
            'Tap "Post Job" to create one',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myJobsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 96), // FAB clearance
            itemCount: jobs.length,
            itemBuilder: (context, i) {
              final job = jobs[i];
              final isOwner = myUid != null && job.postedByUid == myUid;
              return JobCard(
                job: job,
                isOwner: isOwner,
                onTap: () => _openDetail(job),
                onEdit: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PostJobScreen(existingJob: job),
                  ),
                ),
                onDelete: () => _confirmDelete(job),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message, String subtitle) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.work_off_outlined,
                        size: 40,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      message,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState({
    required String message,
    required Object error,
    required VoidCallback onRetry,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color:
                            colorScheme.errorContainer.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.error_outline_rounded,
                        size: 40,
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      message,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      error.toString(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(120, 44),
                        side: BorderSide(
                          color: colorScheme.outline,
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        foregroundColor: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
