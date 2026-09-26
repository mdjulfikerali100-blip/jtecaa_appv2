import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/news/news_model.dart';
import '../../../data/models/user/role_model.dart' show SignupRole;
import '../../providers/news_provider.dart';
import '../../providers/role_provider.dart' show myRoleProvider;
import '../../widgets/common/news_card.dart';
import 'post_news_screen.dart';

class NewsScreen extends ConsumerWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      appBar: AppBar(title: const Text('News & Updates')),
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
              padding: const EdgeInsets.symmetric(vertical: 8),
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
      // Access, Student View-Only". Everything else on this screen
      // (list, expand, pull-to-refresh) is identical for both roles.
      floatingActionButton: isStudent
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PostNewsScreen()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Post News'),
              backgroundColor: Theme.of(context).colorScheme.secondary,
            ),
    );
  }

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

class _EmptyState extends StatelessWidget {
  final bool scrollable;
  const _EmptyState({required this.scrollable});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.newspaper_outlined,
              size: 64, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text('No news yet', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Pull down to refresh',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
    // Wrapped in a scrollable so RefreshIndicator still works on an empty
    // list (a non-scrollable child can't trigger pull-to-refresh).
    return scrollable ? ListView(children: [content]) : content;
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 64, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }
}
