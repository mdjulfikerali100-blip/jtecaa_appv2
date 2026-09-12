// lib/data/datasources/remote/fcm_service.dart
//
// ⚠️ MINIMAL VERSION — Phase 3B needs `subscribeToRoleTopics()` (§M.9)
// wired into role resolution immediately, but the full notification-tap
// handling (`getInitialMessage`/`onMessageOpenedApp`/`onMessage` +
// `_handleNotificationTap`, Architecture Appendix L.2.2) is scheduled for
// Phase 9 in the Master Prompt. Rather than invent that logic early or
// leave role_provider.dart with nothing to call, this file ships now with
// ONLY the topic-subscription method — Phase 9 will ADD methods to this
// same file (not replace it), so this method's signature never changes.
//
// ⚠️ FIX (root cause): `FirebaseMessaging.subscribeToTopic()` /
// `unsubscribeFromTopic()` are NOT implemented on Firebase Messaging's
// Web SDK — topic (un)subscription on Web can only be done server-side
// via the Admin SDK, since the browser has no equivalent native FCM
// topic API. Calling either method while running on Flutter Web throws
// (commonly surfaces as an `UnimplementedError` / "not supported on
// web"). Since this project targets android+ios+web (Phase 0), every
// call site must be guarded with `kIsWeb` — web sessions simply skip
// topic (un)subscription rather than crashing role resolution.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../models/user/role_model.dart';

class FCMService {
  /// Architecture §M.9 — Student devices subscribe to "news" ONLY and are
  /// explicitly unsubscribed from "jobs"/"all", so a Student can never
  /// receive a Job Circular push notification. Alumni subscribe to all
  /// three. Called once per role-resolution (role_provider.dart) — safe
  /// to call repeatedly, since (un)subscribeToTopic is idempotent.
  static Future<void> subscribeToRoleTopics(SignupRole role) async {
    // ⚠️ Web has no topic (un)subscription API on the client SDK — skip
    // entirely rather than letting role resolution throw on web sessions.
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
}
