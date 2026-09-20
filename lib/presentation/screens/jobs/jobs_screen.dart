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
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => JobDetailBottomSheet(job: job),
    );
  }

  Future<void> _confirmDelete(JobPostModel job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this job post?'),
        content: Text(job.title),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not delete: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Board'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Active Jobs'), Tab(text: 'My Posts')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildJobList(activeJobsProvider,
              emptyMessage: 'No active jobs',
              emptySubtitle: 'Be the first to post!'),
          _buildMyPostsList(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PostJobScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Post Job'),
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
      error: (e, st) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Could not load jobs: $e', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                  onPressed: () => ref.invalidate(provider),
                  child: const Text('Retry')),
            ],
          ),
        ),
      ),
      data: (jobs) {
        if (jobs.isEmpty) {
          return _buildEmptyState(emptyMessage, emptySubtitle);
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(activeJobsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
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
                      builder: (_) => PostJobScreen(existingJob: job)),
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
      error: (e, st) => Center(child: Text('Could not load your posts: $e')),
      data: (jobs) {
        if (jobs.isEmpty) {
          return _buildEmptyState("You haven't posted any jobs yet",
              'Tap "Post Job" to create one');
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
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
                    builder: (_) => PostJobScreen(existingJob: job)),
              ),
              onDelete: () => _confirmDelete(job),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String message, String subtitle) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.work_off,
                size: 64, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(message,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
