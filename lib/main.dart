// lib/main.dart
//
// Entry point. Architecture §2 philosophy: "Firestore is the last resort" —
// so the very first thing we do after Firebase is spin up Hive (Tier 2 of
// the 4-tier cache pyramid, §6) BEFORE the app widget tree is even built.
//
// ⚠️ CHANGED in Phase 3: `home:` now points to the real `SplashScreen`
// (Phase 3) instead of the temporary Phase 0/2 placeholder widget, which
// has been deleted from this file entirely.
//
// ⚠️ APPENDIX K.6 FIX: `builder:` clamps the system text-scale factor to
// [0.85, 1.3]. Without this, a user whose device font-size setting is at
// 200%+ (common on budget Android phones) causes text to overflow cards
// and produce the "BOTTOM OVERFLOWED BY N PIXELS" error Appendix K.3
// documents — even after every individual card is made overflow-safe,
// because no card was ever designed for a 2x font scale. Clamping here
// caps the worst case globally instead of patching every card again.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'data/datasources/local/hive_service.dart';
import 'data/datasources/remote/fcm_service.dart'; // ⚠️ NEW (Phase 9)
import 'firebase_options.dart';
import 'presentation/providers/settings_provider.dart'; // ⚠️ NEW (Phase 10)
import 'presentation/screens/splash/splash_screen.dart'; // ⚠️ NEW import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await HiveService.initBoxes();

  // ⚠️ NEW (Phase 9, Appendix L.2.2): registers getInitialMessage /
  // onMessageOpenedApp / onMessage BEFORE runApp() so a cold-start tap
  // (app was fully terminated) is caught by getInitialMessage() here,
  // not missed because the listener was registered too late.
  await FCMService.init();

  runApp(
    const ProviderScope(
      child: JTECAAApp(),
    ),
  );
}

class JTECAAApp extends ConsumerWidget {
  const JTECAAApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ⚠️ CHANGED (Phase 10) — was `StatelessWidget` + hardcoded
    // `ThemeMode.system`. Settings' "Dark Mode" switch
    // (settings_provider.dart) needs somewhere to actually take effect;
    // watching it here is that one place.
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'JTECAA',
      debugShowCheckedModeBanner: false,
      // ⚠️ NEW (Phase 9) — lets FCMService navigate / open bottom sheets
      // from a notification tap without a BuildContext passed in from
      // wherever the message happened to arrive.
      navigatorKey: FCMService.navigatorKey,
      theme: buildJTECAATheme(),
      darkTheme: buildJTECAADarkTheme(),
      themeMode: themeMode,
      // ⚠️ FIX (Appendix K.6): clamp text scale factor to prevent
      // overflow when the user's device font-size is set very large.
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final clampedScaler = mediaQuery.textScaler.clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.3,
        );
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: clampedScaler),
          child: child!,
        );
      },
      // ⚠️ CHANGED — was `const _Phase0PlaceholderHome()`. That private
      // placeholder widget is deleted entirely now that SplashScreen
      // (Phase 3) exists and owns the real "wait for auth + role, then
      // navigate" logic.
      home: const SplashScreen(),
    );
  }
}
//gonitoprojuktirpathshala@gmail.com
