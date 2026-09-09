// lib/main.dart
//
// Entry point. Architecture §2 philosophy: "Firestore is the last resort" —
// so the very first thing we do after Firebase is spin up Hive (Tier 2 of
// the 4-tier cache pyramid, §6) BEFORE the app widget tree is even built.
//
// ⚠️ CHANGED in Phase 3: `home:` now points to the real `SplashScreen`
// (Phase 3) instead of the temporary Phase 0/2 placeholder widget, which
// has been deleted from this file entirely.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'data/datasources/local/hive_service.dart';
import 'firebase_options.dart';
import 'presentation/screens/splash/splash_screen.dart'; // ⚠️ NEW import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await HiveService.initBoxes();

  runApp(
    const ProviderScope(
      child: JTECAAApp(),
    ),
  );
}

class JTECAAApp extends StatelessWidget {
  const JTECAAApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JTECAA',
      debugShowCheckedModeBanner: false,
      theme: buildJTECAATheme(),
      darkTheme: buildJTECAADarkTheme(),
      themeMode: ThemeMode.system,
      // ⚠️ CHANGED — was `const _Phase0PlaceholderHome()`. That private
      // placeholder widget is deleted entirely now that SplashScreen
      // (Phase 3) exists and owns the real "wait for auth + role, then
      // navigate" logic.
      home: const SplashScreen(),
    );
  }
}
