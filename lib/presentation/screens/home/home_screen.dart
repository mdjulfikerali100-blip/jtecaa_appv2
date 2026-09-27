// lib/presentation/screens/home/home_screen.dart
//
// Architecture Appendix F.6.I (Bottom Navigation) + F.7.3 (Home Dashboard)
// + §8.3 (Stats Overview + Donut Chart).
//
// ⚠️ SPEC CONTRADICTION RESOLVED: the Master Prompt's Phase 4 bullet list
// says "Bottom Navigation (Home/Directory/Jobs/News)" — 4 items — but
// Architecture Appendix F.6.I's detailed component spec explicitly lists
// only 3: "1. Home, 2. Directory, 3. Jobs", with News reached via the
// Side Drawer instead ("Menu Items: Profile, News, Settings, Logout",
// same appendix section). F.6.I is the more detailed, more specific
// spec, so this shell has 3 bottom-nav tabs; News will be reached via the
// Side Drawer once Phase 10 builds it.
//
// This screen doubles as the Alumni Shell — it's what SplashScreen and
// VerificationGateScreen (Phase 3) navigate to for the `alumni` role,
// replacing their temporary `_AlumniShellPlaceholder` widgets.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/departments_helper.dart';
import '../../../data/models/job/job_post_model.dart';
import '../../../data/models/system/system_stats_model.dart';
import '../../../data/models/user/user_public_model.dart';
import '../../providers/auth_provider.dart'; // ⚠️ NEW (Phase 6) — currentUidProvider
import '../../providers/dashboard_provider.dart';
import '../../providers/notification_provider.dart'; // ⚠️ NEW (Phase 9)
import '../../widgets/charts/career_status_donut_chart.dart';
import '../../widgets/common/job_detail_bottom_sheet.dart'; // ⚠️ NEW (Phase 7)
import '../directory/directory_screen.dart'; // ⚠️ NEW (Phase 5) — replaces the placeholder
import '../jobs/jobs_screen.dart'; // ⚠️ NEW (Phase 7) — replaces the placeholder
import '../notifications/notifications_screen.dart'; // ⚠️ NEW (Phase 9)
import '../profile/profile_detail_screen.dart'; // ⚠️ NEW (Phase 6)
import '../../widgets/common/side_drawer.dart'; // ⚠️ NEW (Phase 10) — replaces the temporary News/Logout icons

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Built fresh each frame (not a static const list) so the Dashboard
    // tab can be handed a callback that switches this State's own
    // `_currentIndex` — e.g. from the Donut Chart's segment-tap handler.
    final tabs = <Widget>[
      _DashboardTab(
        onNavigateToDirectory: () => setState(() => _currentIndex = 1),
        onNavigateToJobs: () =>
            setState(() => _currentIndex = 2), // ⚠️ NEW (Phase 7)
      ),
      const DirectoryScreen(), // ⚠️ CHANGED (Phase 5) — was `_DirectoryPlaceholderTab()`
      const JobsScreen(), // ⚠️ CHANGED (Phase 7) — was `_JobsPlaceholderTab()`
    ];

    return Scaffold(
      // ⚠️ NEW (Phase 10) — replaces the temporary News/Logout AppBar
      // icons (Phase 8/9) with the real Side Drawer (Appendix F.6.J).
      drawer: const SideDrawer(),
      body: IndexedStack(index: _currentIndex, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Directory'),
          NavigationDestination(
              icon: Icon(Icons.work_outline),
              selectedIcon: Icon(Icons.work),
              label: 'Jobs'),
        ],
      ),
    );
  }
}

/// The actual Dashboard content (Features 8–11).
class _DashboardTab extends ConsumerWidget {
  final VoidCallback onNavigateToDirectory;
  final VoidCallback onNavigateToJobs; // ⚠️ NEW (Phase 7)

  const _DashboardTab(
      {required this.onNavigateToDirectory, required this.onNavigateToJobs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        // Architecture §7.2 "Pull to Refresh": version check + delta
        // update — invalidating these providers re-triggers each
        // repository's own cache-first logic (which itself checks
        // system/config before doing a real fetch), so a refresh that
        // finds nothing changed still costs close to zero extra reads.
        ref.invalidate(dashboardStatsProvider);
        ref.invalidate(recentJobsProvider);
        ref.invalidate(recentAlumniProvider);
        ref.invalidate(myAlumniProfileProvider);
        await Future.delayed(const Duration(milliseconds: 300));
      },
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            title: const Text('JTECAA'),
            // ⚠️ CHANGED (Phase 10) — the Side Drawer (Appendix F.6.J)
            // now exists, so the menu button below opens it. This
            // `leading` slot is otherwise auto-filled by Flutter with a
            // hamburger icon whenever a `Scaffold.drawer` is set, but a
            // `SliverAppBar` inside a `CustomScrollView` doesn't get that
            // auto-wiring the way a plain `Scaffold.appBar` does, so it's
            // wired explicitly here instead.
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Menu',
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            // ⚠️ CHANGED (Phase 10) — News and Logout were temporary
            // stand-ins (Phase 8/9) for the Side Drawer that didn't exist
            // yet (Appendix F.6.J: "Menu: Profile, News, Settings,
            // Logout"). Both now live in `SideDrawer` instead. The
            // Notifications bell (Feature 28) keeps its permanent home
            // here regardless — an AppBar bell icon is the standard place
            // for it either way, Drawer or not.
            actions: [
              Consumer(
                builder: (context, ref, _) {
                  final unreadAsync =
                      ref.watch(unreadNotificationCountProvider);
                  final unreadCount = unreadAsync.maybeWhen(
                    data: (count) => count,
                    orElse: () => 0,
                  );
                  return IconButton(
                    tooltip: 'Notifications',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const NotificationsScreen()),
                    ),
                    icon: Badge(
                      isLabelVisible: unreadCount > 0,
                      label: Text('$unreadCount'),
                      child: const Icon(Icons.notifications_outlined),
                    ),
                  );
                },
              ),
            ],
          ),
          SliverToBoxAdapter(child: _buildGreetingCard(context, ref)),
          SliverToBoxAdapter(child: _buildStatsSection(context, ref)),
          SliverToBoxAdapter(child: _buildJobsSection(context, ref)),
          SliverToBoxAdapter(child: _buildRecentAlumniSection(context, ref)),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildGreetingCard(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(myAlumniProfileProvider);
    // ⚠️ NEW (Phase 6): tapping the greeting card opens the signed-in
    // Alumni's own Profile Detail — there is currently no Side Drawer
    // (Phase 10) or other nav entry point to reach "My Profile" from this
    // shell, so this card doubles as that entry point for now.
    final myUid = ref.watch(currentUidProvider);

    return GestureDetector(
      onTap: myUid == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => ProfileDetailScreen(uid: myUid)),
              ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primary.withValues(alpha: 0.85)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: profileAsync.when(
          loading: () => const SizedBox(
            height: 60,
            child:
                Center(child: CircularProgressIndicator(color: Colors.white)),
          ),
          error: (e, st) => Text(
            'Could not load your profile.',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
          ),
          data: (profile) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good day, ${profile.firstName}',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                '${profile.batch} • ${Departments.getShortLabel(profile.department)}',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.white.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  profile.careerStatus,
                  style:
                      theme.textTheme.labelSmall?.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    // ⚠️ Architecture §8.3: `.maybeWhen` keeps a zero-filled DashboardStats
    // on screen while loading or on error, instead of a spinner or a "No
    // data" message — the cards/chart simply animate from 0 → real
    // numbers once ready.
    final stats = statsAsync.maybeWhen(
      data: (s) => s,
      orElse: () => DashboardStats.empty(AppConstants.departments),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        children: [
          // ⚠️ FIX (root cause): `CrossAxisAlignment.stretch` on this Row
          // requires the Row to be given a bounded height so it can
          // stretch each `_StatCard` to match — but this Row sits inside
          // a plain `Column` fed into a `SliverToBoxAdapter` (no bounded
          // height ambient constraint), so `stretch` propagates an
          // infinite-height constraint down into each `_StatCard`'s
          // `Container`, crashing with "BoxConstraints forces an
          // infinite height". Each `_StatCard` already uses
          // `mainAxisSize: MainAxisSize.min` internally (Appendix K.3),
          // so it doesn't need external stretching to size correctly —
          // removing `crossAxisAlignment` entirely (default: center)
          // fixes this without changing the cards' visual appearance.
          Row(
            children: [
              Expanded(
                  child: _StatCard(
                      label: 'Total Alumni', value: stats.totalAlumni)),
              const SizedBox(width: 8),
              Expanded(
                  child: _StatCard(
                      label: 'Active Batches', value: stats.activeBatchCount)),
              const SizedBox(width: 8),
              Expanded(
                  child: _StatCard(
                      label: 'Districts Covered',
                      value: stats.districtsCoveredCount)),
            ],
          ),
          const SizedBox(height: 16),
          CareerStatusDonutChart(
            data: stats.careerStatus,
            onSegmentTap: (category) {
              // Appendix F.6.O steps 2–4: pre-apply filter, navigate,
              // show confirmation.
              ref.read(pendingDirectoryFilterProvider.notifier).state =
                  category;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Showing $category alumni')),
              );
              onNavigateToDirectory();
            },
            onCenterTap: onNavigateToDirectory,
          ),
        ],
      ),
    );
  }

  Widget _buildJobsSection(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final jobsAsync = ref.watch(recentJobsProvider);

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Row(
              children: [
                Expanded(
                    child:
                        Text('Recent Jobs', style: theme.textTheme.titleLarge)),
                TextButton(
                  onPressed:
                      onNavigateToJobs, // ⚠️ CHANGED (Phase 7) — was _showComingSoon
                  child: Text('See All',
                      style: TextStyle(color: theme.colorScheme.secondary)),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 160,
            child: jobsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(
                child: Text('Could not load jobs.',
                    style: theme.textTheme.bodySmall),
              ),
              data: (jobs) {
                if (jobs.isEmpty) {
                  return Center(
                    child: Text('No active jobs right now.',
                        style: theme.textTheme.bodySmall),
                  );
                }
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: jobs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => _JobPreviewCard(job: jobs[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAlumniSection(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final alumniAsync = ref.watch(recentAlumniProvider);

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Row(
              children: [
                Expanded(
                    child:
                        Text('New Alumni', style: theme.textTheme.titleLarge)),
                TextButton(
                  onPressed: onNavigateToDirectory,
                  child: const Text('See All'),
                ),
              ],
            ),
          ),
          alumniAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, st) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not load recent alumni.',
                  style: theme.textTheme.bodySmall),
            ),
            data: (alumni) {
              if (alumni.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child:
                      Text('No alumni yet.', style: theme.textTheme.bodySmall),
                );
              }
              return Column(
                children:
                    alumni.map((a) => _RecentAlumniTile(alumni: a)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Architecture §8.3's exact `_StatCard` implementation — already
/// overflow-safe (Appendix K.3: `Expanded` from the parent Row,
/// `mainAxisSize.min`, `FittedBox` on the number, `maxLines: 2` +
/// ellipsis on the label, no fixed height anywhere).
class _StatCard extends StatelessWidget {
  final String label;
  final int value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color:
            theme.cardTheme.color ?? theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value.toString(),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _JobPreviewCard extends StatelessWidget {
  final JobPostModel job;

  const _JobPreviewCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 280,
      height: 160,
      child: Card(
        child: InkWell(
          // ⚠️ CHANGED (Phase 7) — was _showComingSoon(context, 'Job details').
          // Opens the same JobDetailBottomSheet used by JobsScreen —
          // matches Architecture §7.7's "detail via bottom sheet" design.
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            builder: (_) => JobDetailBottomSheet(job: job),
          ),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.title,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  job.company,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(Icons.event_outlined,
                        size: 14, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Deadline: ${job.deadline}',
                        style: theme.textTheme.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentAlumniTile extends StatelessWidget {
  final UserPublicModel alumni;

  const _RecentAlumniTile({required this.alumni});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      // ⚠️ `alumni.photoUrl` is a Google Drive fileId, NOT a browsable
      // URL (Architecture §5.4) — rendering it requires the
      // DriveImageService + DriveImage widget from Appendix J, which is
      // deliberately deferred to Phase 6 (Profile Edit is where photo
      // upload/rendering is first wired end-to-end). Using initials here
      // instead of guessing at a broken network-image call.
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          alumni.fullName.isNotEmpty ? alumni.fullName[0] : '?',
          style: TextStyle(
              color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
        ),
      ),
      title:
          Text(alumni.fullName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${Departments.getShortLabel(alumni.department)} • ${alumni.batch ?? ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      // ⚠️ CHANGED (Phase 6) — was `_showComingSoon(context, 'Profile details')`.
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProfileDetailScreen(uid: alumni.uid)),
      ),
    );
  }
}

void _showComingSoon(BuildContext context, String feature) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$feature is coming in a later phase.')),
  );
}
