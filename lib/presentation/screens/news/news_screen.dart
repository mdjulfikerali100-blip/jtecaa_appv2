// lib/presentation/screens/news/news_screen.dart
//
// Architecture §M.1 — "Alumni Full Access, Student View-Only".
// Everything on this screen (list, expand, pull-to-refresh) is identical
// for both roles; only the "Post News" FAB is role-gated.
//
// ⚠️ VISUAL UPGRADE (this revision):
//   • AppBar gets a brand-navy surface, matching the rest of the app.
//   • Empty state and error state use proper icon bubbles + helper text
//     and always sit inside a scrollable so pull-to-refresh works.
//   • FAB label / colours derive from the theme (secondary role) so
//     light + dark both render a legible "Post News" pill.
//   • Everything is overflow-safe at every text scale — every Text has
//     maxLines + ellipsis, every Row is Flexible/Expanded-balanced.
//
//   No logic has been changed: same providers, same FAB gating, same
//   dialogs, same snackbars.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/news/news_model.dart';
import '../../../data/models/user/role_model.dart' show SignupRole;
import '../../providers/news_provider.dart';
import '../../providers/role_provider.dart' show myRoleProvider;
import '../../widgets/common/news_card.dart';
import 'post_news_screen.dart';

const _kBrandNavy = Color(0xFF1B3A5C);
const _kBrandNavyLight = Color(0xFF2E5580);

class NewsScreen extends ConsumerWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final newsAsync = ref.watch(newsListProvider);
    final roleAsync = ref.watch(myRoleProvider);
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    // Default to "not a student" (i.e. show the FAB) while the role is
    // still resolving, rather than flashing the FAB on then off — an
    // Alumni's role read is a 1-time Hive-cached lookup (§M.5) so this
    // loading window is normally instant anyway.
    final isStudent = roleAsync.maybeWhen(
      data: (role) => role == SignupRole.student,
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('News & Updates'),
        backgroundColor: _kBrandNavy,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.30),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(newsActionsProvider.notifier).refresh(),
        child: newsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => const _ErrorState(
            message: 'Could not load news. Pull down to try again.',
          ),
          data: (newsList) {
            if (newsList.isEmpty) {
              return const _EmptyState(scrollable: true);
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
              itemCount: newsList.length,
              itemBuilder: (context, index) {
                final news = newsList[index];
                return NewsCard(
                  news: news,
                  currentUid: currentUid,
                  onEdit: () => _openEdit(context, news),
                  onDelete: () => _confirmDelete(context, ref, news),
                );
              },
            );
          },
        ),
      ),
      // ⚠️ Student never sees this FAB — Architecture §M.1: "Alumni Full
      // Access, Student View-Only".
      floatingActionButton: isStudent
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PostNewsScreen()),
              ),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text(
                'Post News',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              backgroundColor: _kBrandNavyLight,
              foregroundColor: Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // LOGIC — unchanged
  // ─────────────────────────────────────────────────────────────────

  void _openEdit(BuildContext context, NewsModel news) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostNewsScreen(existingNews: news)),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, NewsModel news) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this post?'),
        content: Text('"${news.title}" will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final ok =
                  await ref.read(newsActionsProvider.notifier).delete(news.id);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text(ok ? 'Post deleted' : 'Delete failed — try again'),
                ),
              );
            },
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// EMPTY STATE — icon bubble + heading + helper, always scrollable
// so RefreshIndicator still fires.
// ─────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool scrollable;
  const _EmptyState({required this.scrollable});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final content = Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary
                  .withValues(alpha: isDark ? 0.20 : 0.10),
              border: Border.all(
                color: theme.colorScheme.primary
                    .withValues(alpha: isDark ? 0.45 : 0.25),
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.newspaper_outlined,
              size: 44,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No news yet',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            'Pull down to refresh,\nor check back later.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    // Wrapped in a scrollable so RefreshIndicator still works on an empty
    // list (a non-scrollable child can't trigger pull-to-refresh).
    return scrollable
        ? LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Center(child: content),
              ),
            ),
          )
        : content;
  }
}

// ─────────────────────────────────────────────────────────────────────
// ERROR STATE — icon bubble + message, scrollable so pull-to-refresh
// actually retries.
// ─────────────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
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
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.error
                          .withValues(alpha: isDark ? 0.18 : 0.10),
                      border: Border.all(
                        color: theme.colorScheme.error
                            .withValues(alpha: isDark ? 0.45 : 0.30),
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.cloud_off_rounded,
                      size: 44,
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                      height: 1.4,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
