/// lib/presentation/providers/notification_provider.dart
///
/// Riverpod wiring for the local Notification History (see
/// fcm_service.dart's header for why this is Hive-backed, not Firestore).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/remote/fcm_service.dart';
import '../../data/models/notification/notification_model.dart';

final notificationHistoryProvider =
    FutureProvider.autoDispose<List<NotificationRecord>>((ref) async {
  return FCMService.getHistory();
});

/// Convenience provider for the AppBar bell badge — Feature 28's "unread
/// badge" — derived from the same history list rather than tracked
/// separately, so there's exactly one source of truth for read/unread
/// state.
final unreadNotificationCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final history = await ref.watch(notificationHistoryProvider.future);
  return history.where((n) => !n.read).length;
});

class NotificationActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  NotificationActionsNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> markAsRead(String id) async {
    await FCMService.markAsRead(id);
    _ref.invalidate(notificationHistoryProvider);
  }

  Future<void> markAllAsRead() async {
    await FCMService.markAllAsRead();
    _ref.invalidate(notificationHistoryProvider);
  }

  Future<void> refresh() async {
    _ref.invalidate(notificationHistoryProvider);
  }
}

final notificationActionsProvider =
    StateNotifierProvider<NotificationActionsNotifier, AsyncValue<void>>(
        (ref) => NotificationActionsNotifier(ref));
