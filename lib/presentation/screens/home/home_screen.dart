// lib/presentation/screens/home/home_screen.dart
//
// Architecture Appendix F.6.I (Bottom Navigation) + F.7.3 (Home Dashboard)
// + §8.3 (Stats Overview + Donut Chart).
//
// ⚠️ CLEANER APPBAR (this revision):
//   The previous appbar stacked three circular buttons (menu, brand-logo,
//   bell) + a two-line title — visually crowded, especially on narrow
//   phones. Now:
//     • The redundant brand-logo circle is gone; "JTECAA" alone carries
//       the brand mark (its letterspacing + weight do the job).
//     • Title uses a two-weight lockup: "JTECAA" bold, the greeting
//       line sits beneath it in a lighter weight, so the eye reads the
//       brand first and the name second.
//     • Menu + bell sit in a single shared visual "chip" language —
//       same 40dp circular hit-target, same translucent white — but
//       now with symmetric left/right margin so nothing looks pushed
//       into a corner.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/departments_helper.dart';
import '../../../data/models/job/job_post_model.dart';
import '../../../data/models/system/system_stats_model.dart';
import '../../../data/models/user/user_public_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/charts/career_status_donut_chart.dart';
import '../../widgets/common/drive_image.dart';
import '../../widgets/common/job_detail_bottom_sheet.dart';
import '../../widgets/common/side_drawer.dart';
import '../directory/directory_screen.dart';
import '../jobs/jobs_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_detail_screen.dart';

const _kBrandNavy = Color(0xFF1B3A5C);
const _kBrandNavyLight = Color(0xFF2E5580);

String normaliseBatch(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.toLowerCase().endsWith('batch')) return trimmed;
  return '$trimmed Batch';
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final tabs = <Widget>[
      _DashboardTab(
        onNavigateToDirectory: () => setState(() => _currentIndex = 1),
        onNavigateToJobs: () => setState(() => _currentIndex = 2),
      ),
      const DirectoryScreen(),
      const JobsScreen(),
    ];

    return Scaffold(
      drawer: const SideDrawer(),
      body: IndexedStack(index: _currentIndex, children: tabs),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            indicatorColor: theme.colorScheme.primary
                .withValues(alpha: isDark ? 0.28 : 0.14),
            height: 68,
            elevation: 0,
            backgroundColor: theme.colorScheme.surface,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: 0.2,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return IconThemeData(
                size: 24,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.85),
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) {
              HapticFeedback.selectionClick();
              setState(() => _currentIndex = i);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.people_outline_rounded),
                selectedIcon: Icon(Icons.people_rounded),
                label: 'Directory',
              ),
              NavigationDestination(
                icon: Icon(Icons.work_outline_rounded),
                selectedIcon: Icon(Icons.work_rounded),
                label: 'Jobs',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// DASHBOARD TAB
// ─────────────────────────────────────────────────────────────────────
class _DashboardTab extends ConsumerStatefulWidget {
  final VoidCallback onNavigateToDirectory;
  final VoidCallback onNavigateToJobs;

  const _DashboardTab(
      {required this.onNavigateToDirectory, required this.onNavigateToJobs});

  @override
  ConsumerState<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends ConsumerState<_DashboardTab> {
  // ── Auto-scroll state ───────────────────────────────────────────────
  final _jobsScrollController = ScrollController();
  Timer? _autoScrollTimer;
  bool _userInteracting = false;
  bool _autoScrollStarted = false;

  // ⚠️ INCREASED SCROLL SPEED: was 22 dp/s — too slow. 45 dp/s keeps
  // the motion clearly perceptible without ever feeling frantic.
  static const _autoScrollSpeedDps = 45.0; // dp per second
  static const _resumeDelay = Duration(seconds: 3);

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _jobsScrollController.dispose();
    super.dispose();
  }

  void _startAutoScrollIfNeeded() {
    if (_autoScrollStarted) return;
    if (!_jobsScrollController.hasClients) return;
    if (_jobsScrollController.position.maxScrollExtent <= 0) return;
    _autoScrollStarted = true;
    _autoScrollTimer =
        Timer.periodic(const Duration(milliseconds: 16), _autoScrollTick);
  }

  void _autoScrollTick(Timer t) {
    if (!mounted) return;
    if (!_jobsScrollController.hasClients) return;
    if (_userInteracting) return;

    final pos = _jobsScrollController.position;
    final max = pos.maxScrollExtent;
    if (max <= 0) return;

    final delta = _autoScrollSpeedDps * (16 / 1000.0);
    final next = pos.pixels + delta;

    if (next >= max) {
      _jobsScrollController.jumpTo(0);
    } else {
      _jobsScrollController.jumpTo(next);
    }
  }

  void _onPointerDown(PointerDownEvent _) {
    _userInteracting = true;
  }

  void _onScrollStart() {
    _userInteracting = true;
  }

  void _onScrollEnd() {
    Future.delayed(_resumeDelay, () {
      if (mounted) _userInteracting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final ts = media.textScaler.scale(1.0).clamp(0.85, 1.35);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardStatsProvider);
        ref.invalidate(recentJobsProvider);
        ref.invalidate(recentAlumniProvider);
        ref.invalidate(myAlumniProfileProvider);
        await Future.delayed(const Duration(milliseconds: 300));
      },
      child: CustomScrollView(
        slivers: [
          // ── Cleaner AppBar ──────────────────────────────────
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: _kBrandNavy,
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 4,
            shadowColor: Colors.black.withValues(alpha: 0.30),
            toolbarHeight: kToolbarHeight * (ts < 1.05 ? 1.15 : 1.40),
            titleSpacing: 0,
            title: _buildAppBarTitle(context, ref, theme),
            leadingWidth: 60,
            leading: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Builder(
                builder: (context) => _AppBarIconButton(
                  icon: Icons.menu_rounded,
                  tooltip: 'Open menu',
                  onTap: () => Scaffold.of(context).openDrawer(),
                ),
              ),
            ),
            actions: [
              Consumer(
                builder: (context, ref, _) {
                  final unreadAsync =
                      ref.watch(unreadNotificationCountProvider);
                  final unreadCount = unreadAsync.maybeWhen(
                    data: (count) => count,
                    orElse: () => 0,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _AppBarIconButton(
                      tooltip: 'Notifications',
                      icon: Icons.notifications_none_rounded,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const NotificationsScreen()),
                      ),
                      badgeCount: unreadCount,
                      badgeColor: theme.colorScheme.error,
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
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  // ── Cleaner AppBar title — no brand-logo circle, tighter lockup ────
  Widget _buildAppBarTitle(
      BuildContext context, WidgetRef ref, ThemeData theme) {
    final profileAsync = ref.watch(myAlumniProfileProvider);
    final firstName = profileAsync.maybeWhen(
      data: (p) => p.firstName,
      orElse: () => null,
    );

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Brand — the only bold element
          Text(
            'JTECAA',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 3.0,
              height: 1.0,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (firstName != null && firstName.isNotEmpty) ...[
            const SizedBox(height: 2),
            // Greeting — lighter weight so it reads as secondary
            Text(
              'Hi, $firstName',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.75),
                fontWeight: FontWeight.w400,
                letterSpacing: 0.2,
                height: 1.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGreetingCard(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(myAlumniProfileProvider);
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
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_kBrandNavy, _kBrandNavyLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: profileAsync.when(
          loading: () => const SizedBox(
            height: 72,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
            ),
          ),
          error: (e, st) => Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white70),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Could not load your profile.',
                  style:
                      theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          data: (profile) => Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.45),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child:
                      (profile.photoUrl != null && profile.photoUrl!.isNotEmpty)
                          ? DriveImage(
                              fileId: profile.photoUrl!,
                              width: 56,
                              height: 56,
                            )
                          : Center(
                              child: Text(
                                profile.firstName.isNotEmpty
                                    ? profile.firstName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 22,
                                ),
                              ),
                            ),
                ),
              ),
              const SizedBox(width: 14),
              Flexible(
                fit: FlexFit.tight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Good day, ${profile.firstName}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${normaliseBatch(profile.batch)}  •  ${Departments.getShortLabel(profile.department)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            profile.careerStatus,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.75),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final stats = statsAsync.maybeWhen(
      data: (s) => s,
      orElse: () => DashboardStats.empty(AppConstants.departments),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final ts = MediaQuery.of(context).textScaler.scale(1.0);
              final perCard = (108.0 * ts).clamp(108.0, 156.0);
              final fits = constraints.maxWidth >= (perCard * 3) + 16;

              final cards = <Widget>[
                _StatCard(
                  icon: Icons.people_alt_rounded,
                  label: 'Total Alumni',
                  value: stats.totalAlumni,
                  accent: _kBrandNavy,
                ),
                _StatCard(
                  icon: Icons.school_rounded,
                  label: 'Active Batches',
                  value: stats.activeBatchCount,
                  accent: const Color(0xFF0F766E),
                ),
                _StatCard(
                  icon: Icons.location_on_rounded,
                  label: 'Districts',
                  value: stats.districtsCoveredCount,
                  accent: const Color(0xFFB45309),
                ),
              ];

              if (fits) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 8),
                    Expanded(child: cards[1]),
                    const SizedBox(width: 8),
                    Expanded(child: cards[2]),
                  ],
                );
              }

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: (constraints.maxWidth - 8) / 2,
                    child: cards[0],
                  ),
                  SizedBox(
                    width: (constraints.maxWidth - 8) / 2,
                    child: cards[1],
                  ),
                  SizedBox(
                    width: (constraints.maxWidth - 8) / 2,
                    child: cards[2],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          CareerStatusDonutChart(
            data: stats.careerStatus,
            onSegmentTap: (category) {
              ref.read(pendingDirectoryFilterProvider.notifier).state =
                  category;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Showing $category alumni')),
              );
              widget.onNavigateToDirectory();
            },
            onCenterTap: widget.onNavigateToDirectory,
          ),
        ],
      ),
    );
  }

  Widget _buildJobsSection(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final jobsAsync = ref.watch(recentJobsProvider);
    final ts = MediaQuery.of(context).textScaler.scale(1.0).clamp(0.85, 1.35);
    final stripHeight = 176.0 * ts;

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Recent Jobs',
            actionLabel: 'See All',
            onAction: widget.onNavigateToJobs,
            theme: theme,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: stripHeight,
            child: jobsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Could not load jobs.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
              data: (jobs) {
                if (jobs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'No active jobs right now.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }

                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _startAutoScrollIfNeeded());

                return Listener(
                  onPointerDown: _onPointerDown,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n is ScrollStartNotification) {
                        _onScrollStart();
                      } else if (n is ScrollEndNotification) {
                        _onScrollEnd();
                      }
                      return false;
                    },
                    child: ListView.separated(
                      controller: _jobsScrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.only(left: 16, right: 24),
                      itemCount: jobs.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) =>
                          _JobPreviewCard(job: jobs[i]),
                    ),
                  ),
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
          _SectionHeader(
            title: 'New Alumni',
            actionLabel: 'See All',
            onAction: widget.onNavigateToDirectory,
            theme: theme,
          ),
          const SizedBox(height: 12),
          alumniAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, st) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load recent alumni.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ),
            data: (alumni) {
              if (alumni.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No alumni yet.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: alumni
                      .map((a) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _RecentAlumniTile(alumni: a),
                          ))
                      .toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Circular AppBar icon button — same visual language as before but a
// slightly tighter 40dp hit target so a two-line title still has room.
// ─────────────────────────────────────────────────────────────────────
class _AppBarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int badgeCount;
  final Color? badgeColor;

  const _AppBarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badgeCount = 0,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.14),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 21, color: Colors.white),
                if (badgeCount > 0)
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      decoration: BoxDecoration(
                        color:
                            badgeColor ?? Theme.of(context).colorScheme.error,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _kBrandNavy, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback? onAction;
  final ThemeData theme;

  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.theme,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onAction != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        actionLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Stat card
// ─────────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color accent;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final visibleAccent = isDark
        ? HSLColor.fromColor(accent)
            .withLightness(
                (HSLColor.fromColor(accent).lightness + 0.28).clamp(0.55, 0.85))
            .toColor()
        : accent;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: visibleAccent.withValues(alpha: isDark ? 0.22 : 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 17, color: visibleAccent),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value.toString(),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Job preview card
// ─────────────────────────────────────────────────────────────────────
class _JobPreviewCard extends StatelessWidget {
  final JobPostModel job;

  const _JobPreviewCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      width: 260,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0.5,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            builder: (_) => JobDetailBottomSheet(job: job),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.max,
              children: [
                Text(
                  job.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  job.company,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer
                          .withValues(alpha: isDark ? 0.75 : 0.95),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.secondary
                            .withValues(alpha: isDark ? 0.60 : 0.40),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_outlined,
                          size: 13,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            _formatDeadline(job.deadline),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDeadline(dynamic raw) {
    if (raw == null) return 'Deadline: pending';

    final s = raw.toString().trim();
    if (s.isEmpty) return 'Deadline: pending';

    DateTime? dt;
    try {
      dt = DateTime.tryParse(s);
    } catch (_) {
      dt = null;
    }
    if (dt == null) {
      return s.length <= 22 ? 'Deadline: $s' : 'Deadline: pending';
    }

    final local = dt.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final now = DateTime.now();
    final day = local.day;
    final month = months[local.month - 1];
    final year = local.year;
    final label = (year == now.year) ? '$day $month' : '$day $month $year';
    return 'Deadline: $label';
  }
}

// ─────────────────────────────────────────────────────────────────────
// Recent alumni tile
// ─────────────────────────────────────────────────────────────────────
class _RecentAlumniTile extends StatelessWidget {
  final UserPublicModel alumni;

  const _RecentAlumniTile({required this.alumni});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasPhoto =
        alumni.photoUrl != null && alumni.photoUrl!.trim().isNotEmpty;

    final subtitleColor = isDark
        ? theme.colorScheme.onSurfaceVariant
        : Color.lerp(
            theme.colorScheme.onSurfaceVariant,
            theme.colorScheme.onSurface,
            0.55,
          )!;

    final deptLabel = Departments.getShortLabel(alumni.department);
    final batchLabel = normaliseBatch(alumni.batch ?? '');
    final subtitle = [
      if (deptLabel.isNotEmpty) deptLabel,
      if (batchLabel.isNotEmpty) batchLabel,
    ].join('  •  ');

    return Material(
      color: theme.colorScheme.surfaceContainerHighest
          .withValues(alpha: isDark ? 0.45 : 0.75),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => ProfileDetailScreen(uid: alumni.uid)),
        ),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primaryContainer,
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.20),
                    width: 1.5,
                  ),
                ),
                child: ClipOval(
                  child: hasPhoto
                      ? DriveImage(
                          fileId: alumni.photoUrl!,
                          width: 52,
                          height: 52,
                        )
                      : Center(
                          child: Text(
                            alumni.fullName.isNotEmpty
                                ? alumni.fullName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      alumni.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: subtitleColor,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary
                      .withValues(alpha: isDark ? 0.20 : 0.10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
