import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/remote/fcm_service.dart';
import '../../../data/models/notification/notification_model.dart';
import '../../providers/notification_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(notificationHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () =>
                ref.read(notificationActionsProvider.notifier).markAllAsRead(),
            child: const Text('Mark all read',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(notificationActionsProvider.notifier).refresh(),
        child: historyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: const [
              Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('Could not load notifications.')),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.notifications_none,
                            size: 64,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(height: 12),
                        Text('No notifications yet',
                            style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) => _NotificationTile(record: items[i]),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final NotificationRecord record;
  const _NotificationTile({required this.record});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(
        record.type == 'job' ? Icons.work_outline : Icons.article_outlined,
        color: theme.colorScheme.primary,
      ),
      title: Text(
        record.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: record.read ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Text(record.body, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: record.read
          ? null
          : Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                shape: BoxShape.circle,
              ),
            ),
      onTap: () async {
        await ref
            .read(notificationActionsProvider.notifier)
            .markAsRead(record.id);
        await FCMService.openNotificationTarget(
          type: record.type,
          refId: record.refId,
        );
      },
    );
  }
}
