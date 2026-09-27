/// lib/data/datasources/remote/fcm_service.dart
///
/// ⚠️ PHASE 9 EDIT — ADDS methods to the Phase 3B version of this file;
/// `subscribeToRoleTopics()` below is byte-for-byte the same method that
/// file shipped with (same signature, same kIsWeb guard, same §M.9
/// logic) — Phase 3B's own header comment promised this file would only
/// ever gain methods, never have that one changed, and that promise is
/// kept here.
///
/// ⚠️ SPEC CONTRADICTION (documented, not silently patched): Architecture
/// §4.2.H defines a `notification_log/{id}` Firestore collection for
/// Notification History, but §9.2's Security Rules make it
/// `allow write: if false` for every client — and this app has ZERO
/// Cloud Functions (§2, §8.1) and no Admin SDK anywhere, so nothing in
/// this architecture can ever legally write to that collection. It's
/// unusable as specified. Notification History is implemented here
/// entirely LOCALLY in Hive box `notif_cache` instead — §6.2's own TTL
/// table already lists "notifications: 7 days" for that box, which only
/// makes sense for local storage in the first place.
/// `FirestorePaths.notificationLog` is left untouched but nothing in this
/// app ever reads or writes it.
///
/// ⚠️ KNOWN LIMITATION (stated, not hidden): a message that arrives while
/// the app is backgrounded/terminated AND the user never taps it will
/// NOT appear in in-app History — only messages received in the
/// FOREGROUND (`onMessage`) or actually tapped
/// (`getInitialMessage`/`onMessageOpenedApp`) get logged. Capturing every
/// background delivery needs `FirebaseMessaging.onBackgroundMessage()`
/// with a top-level function that re-initializes Hive in a separate
/// isolate — a real feature, deliberately out of scope for this pass
/// rather than silently under-delivering on it without saying so.
library;

import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../models/job/job_post_model.dart';
import '../../models/notification/notification_model.dart';
import '../../models/user/role_model.dart';
import '../external/google_sheets_proxy.dart';
import '../../../presentation/screens/news/news_screen.dart';
import '../../../presentation/widgets/common/job_detail_bottom_sheet.dart';

class FCMService {
  /// Wired into `MaterialApp(navigatorKey: FCMService.navigatorKey)`
  /// (main.dart, Phase 9 edit) so this static service can push routes /
  /// open bottom sheets without a BuildContext passed in from wherever a
  /// message happens to arrive.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const String _boxName = 'notif_cache';
  static const String _cacheKey = 'notifications_v1';
  static const Duration _historyTtl = Duration(days: 7); // §6.2

  // -----------------------------------------------------------------
  // §M.9 — UNCHANGED from Phase 3B.
  // -----------------------------------------------------------------
  static Future<void> subscribeToRoleTopics(SignupRole role) async {
    if (kIsWeb) {
      return;
    }
    final messaging = FirebaseMessaging.instance;
    if (role == SignupRole.student) {
      await messaging.subscribeToTopic('news');
      await messaging.unsubscribeFromTopic('jobs');
      await messaging.unsubscribeFromTopic('all');
    } else {
      await messaging.subscribeToTopic('all');
      await messaging.subscribeToTopic('jobs');
      await messaging.subscribeToTopic('news');
    }
  }

  /// ⚠️ NEW (Phase 10) — Settings' "Push Notifications" toggle, OFF state
  /// (settings_provider.dart). Unsubscribes from every topic regardless
  /// of role, the mirror image of `subscribeToRoleTopics()` above.
  static Future<void> unsubscribeAllTopics() async {
    if (kIsWeb) {
      return;
    }
    final messaging = FirebaseMessaging.instance;
    await messaging.unsubscribeFromTopic('all');
    await messaging.unsubscribeFromTopic('jobs');
    await messaging.unsubscribeFromTopic('news');
  }

  // -----------------------------------------------------------------
  // Phase 9 — notification-tap handling (Appendix L.2.2)
  // -----------------------------------------------------------------

  /// Call once from main(), before runApp(). Registers all three cases
  /// Appendix L.2.2 lists: terminated, background, foreground.
  static Future<void> init() async {
    // Case 1: app was fully terminated, opened by tapping a notification.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      await _logNotification(initialMessage, read: true);
      // Splash forces a 5s display (Architecture Phase 3) before routing
      // is decided, so the Navigator may not be mounted the instant this
      // runs — poll briefly instead of firing into a null NavigatorState.
      _waitForNavigatorThenHandle(initialMessage);
    }

    // Case 2: app was backgrounded, brought to foreground by the tap.
    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      await _logNotification(message, read: true);
      _handleNotificationTap(message);
    });

    // Case 3: app was in foreground when the message arrived — log it
    // (unread) and show an in-app banner. Deliberately does NOT
    // auto-navigate here: yanking the user off whatever they're doing on
    // mere receipt would be worse than a tap-triggered navigation.
    FirebaseMessaging.onMessage.listen((message) async {
      await _logNotification(message, read: false);
      final ctx = navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(message.notification?.title ?? 'New update'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () => _handleNotificationTap(message),
          ),
        ),
      );
    });
  }

  static void _waitForNavigatorThenHandle(
    RemoteMessage message, {
    int attemptsLeft = 20, // ~8s total at 400ms/attempt
  }) {
    if (navigatorKey.currentState != null) {
      _handleNotificationTap(message);
      return;
    }
    if (attemptsLeft <= 0) return; // give up quietly — known limitation
    Future.delayed(const Duration(milliseconds: 400), () {
      _waitForNavigatorThenHandle(message, attemptsLeft: attemptsLeft - 1);
    });
  }

  /// ⚠️ THE ACTUAL FIX (Appendix L.2.2's documented root cause): reads
  /// `type`/`id` from the message's `data` map and opens the SPECIFIC
  /// post — never just the bare list.
  static Future<void> _handleNotificationTap(RemoteMessage message) async {
    await openNotificationTarget(
      type: message.data['type'] as String?,
      refId: message.data['id'] as String?,
    );
  }

  /// Public so `notifications_screen.dart` (Phase 9) can reuse the exact
  /// same "open the right detail" logic for a tap on an in-app History
  /// row, instead of duplicating the job-fetch/bottom-sheet code there.
  static Future<void> openNotificationTarget({
    required String? type,
    required String? refId,
  }) async {
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    if (type == 'job' && refId != null) {
      await _openJobDetail(context, refId);
    } else if (type == 'news') {
      // ⚠️ Addendum §6: News detail is inline-only on NewsScreen itself —
      // no per-item News route/bottom sheet exists yet, so opening the
      // News list is the most precise thing possible today (same
      // documented-gap pattern Architecture §7.7 originally used for
      // Jobs, before Jobs got its own bottom-sheet detail).
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const NewsScreen()),
      );
    }
    // Unknown/malformed type/id — no-op rather than guessing a fallback.
  }

  static Future<void> _openJobDetail(BuildContext context, String jobId) async {
    try {
      // One-off fetch — GoogleSheetsProxy holds no state of its own
      // (confirmed from the real file: `_baseUrl` is a compile-time
      // constant, nothing else), so a fresh instance here behaves
      // identically to going through `googleSheetsProxyProvider`, without
      // this static service needing to carry a Riverpod Ref around.
      final data = await GoogleSheetsProxy().getJobById(jobId);
      if (data == null) {
        _showSnack(context, 'This job post is no longer available.');
        return;
      }
      final job = JobPostModel.fromMap(data);
      if (!context.mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => JobDetailBottomSheet(job: job),
      );
    } catch (_) {
      if (context.mounted) {
        _showSnack(context, 'Could not open this job right now.');
      }
    }
  }

  static void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // -----------------------------------------------------------------
  // Local Notification History (Hive `notif_cache`, §6.2, 7-day TTL).
  // See this file's header for why this replaces the unusable Firestore
  // `notification_log` collection.
  // -----------------------------------------------------------------

  static Future<void> _logNotification(RemoteMessage message,
      {required bool read}) async {
    try {
      final box = await Hive.openBox(_boxName);
      final existing = await _readAll(box);

      final record = NotificationRecord(
        id: message.messageId ??
            'local_${DateTime.now().microsecondsSinceEpoch}',
        title: message.notification?.title ??
            (message.data['title'] as String?) ??
            'Update',
        body: message.notification?.body ??
            (message.data['body'] as String?) ??
            '',
        type: (message.data['type'] as String?) ?? 'other',
        refId: message.data['id'] as String?,
        receivedAt: DateTime.now(),
        read: read,
      );

      // De-dupe by id — a foreground onMessage followed later by a tap on
      // that same notification would otherwise create two history rows.
      final updated = [record, ...existing.where((n) => n.id != record.id)];
      await _writeAll(box, updated);
    } catch (_) {
      // History logging must never crash notification delivery/tap
      // handling — best-effort only.
    }
  }

  static Future<List<NotificationRecord>> getHistory() async {
    final box = await Hive.openBox(_boxName);
    return _readAll(box);
  }

  static Future<void> markAsRead(String id) async {
    final box = await Hive.openBox(_boxName);
    final existing = await _readAll(box);
    final updated =
        existing.map((n) => n.id == id ? n.copyWith(read: true) : n).toList();
    await _writeAll(box, updated);
  }

  static Future<void> markAllAsRead() async {
    final box = await Hive.openBox(_boxName);
    final existing = await _readAll(box);
    final updated = existing.map((n) => n.copyWith(read: true)).toList();
    await _writeAll(box, updated);
  }

  static Future<List<NotificationRecord>> _readAll(Box box) async {
    final raw = box.get(_cacheKey);
    if (raw == null) return [];
    try {
      final list = (jsonDecode(raw as String) as List)
          .map((m) =>
              NotificationRecord.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList();

      // §6.2 TTL — prune anything older than 7 days on every read.
      final now = DateTime.now();
      final fresh = list
          .where((n) => now.difference(n.receivedAt) < _historyTtl)
          .toList()
        ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
      if (fresh.length != list.length) {
        await _writeAll(box, fresh); // persist the pruning
      }
      return fresh;
    } catch (_) {
      return [];
    }
  }

  static Future<void> _writeAll(Box box, List<NotificationRecord> list) async {
    await box.put(_cacheKey, jsonEncode(list.map((n) => n.toMap()).toList()));
  }
}
