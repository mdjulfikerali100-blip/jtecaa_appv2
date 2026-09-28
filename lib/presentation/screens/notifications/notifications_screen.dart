// lib/presentation/screens/notifications/notifications_screen.dart
//
// Notification history — list of past notifications with per-item and
// bulk "mark as read" actions. Tapping an item marks it read and opens
// the corresponding target via FCMService.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/datasources/remote/fcm_service.dart';
import '../../../data/models/notification/notification_model.dart';
import '../../providers/notification_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final historyAsync = ref.watch(notificationHistoryProvider);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Notifications',
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
        actions: [
          // ✅ Theme-safe label — was `Colors.white` (invisible in light mode).
          TextButton.icon(
            onPressed: () =>
                ref.read(notificationActionsProvider.notifier).markAllAsRead(),
            icon: const Icon(Icons.done_all_rounded, size: 18),
            label: Text(
              'Mark all read',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(notificationActionsProvider.notifier).refresh(),
        child: historyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(
            onRetry: () =>
                ref.read(notificationActionsProvider.notifier).refresh(),
            colorScheme: colorScheme,
            textTheme: theme.textTheme,
          ),
          data: (items) {
            if (items.isEmpty) {
              return _EmptyState(
                colorScheme: colorScheme,
                textTheme: theme.textTheme,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: items.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 72,
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              itemBuilder: (context, i) => _NotificationTile(
                record: items[i],
                colorScheme: colorScheme,
                textTheme: theme.textTheme,
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Empty / error states — scrollable so RefreshIndicator always works.
// ─────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.colorScheme, required this.textTheme});

  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
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
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications_none_rounded,
                        size: 44,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No notifications yet',
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "You'll see job posts, articles, and announcements "
                      'here as soon as they arrive.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
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
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.onRetry,
    required this.colorScheme,
    required this.textTheme,
  });

  final VoidCallback onRetry;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
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
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color:
                            colorScheme.errorContainer.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.error_outline_rounded,
                        size: 44,
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Could not load notifications',
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Please check your connection and try again.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                      maxLines: 3,
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

// ─────────────────────────────────────────────────────────────────────────
// Notification item.
// ─────────────────────────────────────────────────────────────────────────

class _NotificationTile extends ConsumerWidget {
  final NotificationRecord record;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _NotificationTile({
    required this.record,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUnread = !record.read;

    return Material(
      // Unread items get a very subtle tint so they pop without shouting.
      color: isUnread
          ? colorScheme.primaryContainer.withValues(alpha: 0.14)
          : Colors.transparent,
      child: InkWell(
        onTap: () async {
          await ref
              .read(notificationActionsProvider.notifier)
              .markAsRead(record.id);
          await FCMService.openNotificationTarget(
            type: record.type,
            refId: record.refId,
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Icon badge ─────────────────────────────────────
              _TypeIconBadge(
                type: record.type,
                unread: isUnread,
                colorScheme: colorScheme,
              ),
              const SizedBox(width: 14),

              // ── Text content ───────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title,
                      style: textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight:
                            isUnread ? FontWeight.w800 : FontWeight.w500,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (record.body.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        record.body,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // ── Unread dot ─────────────────────────────────────
              if (isUnread) ...[
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.4),
                          blurRadius: 6,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded-square icon badge — colored by type and read state.
class _TypeIconBadge extends StatelessWidget {
  const _TypeIconBadge({
    required this.type,
    required this.unread,
    required this.colorScheme,
  });

  final String type;
  final bool unread;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final isJob = type == 'job';
    final IconData icon =
        isJob ? Icons.work_outline_rounded : Icons.article_outlined;

    // Unread: strong primary tone. Read: muted surface tone.
    final Color bg = unread
        ? colorScheme.primaryContainer.withValues(alpha: 0.85)
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);
    final Color fg =
        unread ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant;

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 20, color: fg),
    );
  }
}
