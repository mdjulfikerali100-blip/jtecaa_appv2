//lib/presentation/providers/settings_provider.dart
//
// Local device preferences for the Settings screen (Master Prompt
//Phase 10, "Preferences: Push Notifications toggle, Dark Mode toggle").
// Stored in a small dedicated Hive box (`settings_box`, opened ad hoc
// here — same pattern already used for `notif_cache`/`news_cache` in
//earlier phases) rather than `shared_preferences`, since that package
// isn't in the pubspec dependency list (Appendix H.2) and this app
// already leans on Hive for every other piece of local state.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/datasources/remote/fcm_service.dart';
import 'role_provider.dart';

const String _settingsBoxName = 'settings_box';

/// ⚠️ Simplified to a single Switch, matching Architecture Appendix F.7.9's
/// "Dark Mode | Trailing: Switch" (a two-state control, not a three-way
/// System/Light/Dark picker). OFF = ThemeMode.system (the app's original
/// default, main.dart Phase 0); ON = force ThemeMode.dark. There is
/// deliberately no way to force Light-only from this switch — "system"
/// already covers a device set to light mode.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  static const _key = 'themeMode';

  Future<void> _load() async {
    final box = await Hive.openBox(_settingsBoxName);
    final raw = box.get(_key) as String?;
    state = raw == 'dark' ? ThemeMode.dark : ThemeMode.system;
  }

  Future<void> setDarkModeForced(bool forced) async {
    state = forced ? ThemeMode.dark : ThemeMode.system;
    final box = await Hive.openBox(_settingsBoxName);
    await box.put(_key, forced ? 'dark' : 'system');
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

/// Push Notifications toggle — OFF unsubscribes from every FCM topic
/// (Architecture §M.9's three topics: all/jobs/news), ON re-subscribes
/// according to the signed-in user's role (same rule §M.9 already
/// enforces for Students vs Alumni).
class PushNotificationsNotifier extends StateNotifier<bool> {
  final Ref _ref;
  PushNotificationsNotifier(this._ref) : super(true) {
    _load();
  }

  static const _key = 'pushEnabled';

  Future<void> _load() async {
    final box = await Hive.openBox(_settingsBoxName);
    state = box.get(_key) as bool? ?? true; // default ON
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final box = await Hive.openBox(_settingsBoxName);
    await box.put(_key, enabled);

    if (enabled) {
      final role = _ref.read(myRoleProvider).valueOrNull;
      if (role != null) {
        await FCMService.subscribeToRoleTopics(role);
      }
    } else {
      await FCMService.unsubscribeAllTopics();
    }
  }
}

final pushNotificationsEnabledProvider =
    StateNotifierProvider<PushNotificationsNotifier, bool>((ref) {
  return PushNotificationsNotifier(ref);
});
