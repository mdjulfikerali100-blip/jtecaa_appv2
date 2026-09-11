// lib/presentation/screens/splash/splash_screen.dart
//
// Architecture Appendix F.7.1 — 5s forced display, scale+fade animation,
// then navigates based on auth state AND role (§M.5/§M.6): this is where
// the two async streams (authStateProvider, myRoleProvider) converge
// before any navigation decision is made.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/user/role_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/role_provider.dart';
import '../auth/login_screen.dart';
import '../auth/verification_gate_screen.dart';
import '../home/home_screen.dart'; // ⚠️ NEW (Phase 4) — replaces the placeholder
import '../student/student_shell.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  bool _minDurationElapsed = false;
  bool _hasNavigated = false;
  // ⚠️ NEW — see _maybeNavigate()'s fix note below for why this exists.
  Object? _roleError;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _scale = Tween<double>(begin: 0.8, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();

    // Architecture Appendix F.7.1: "Duration: 5 seconds (forced)" — the
    // splash stays up for at least this long regardless of how fast auth
    // resolves, so the brand moment isn't an instant flash on a fast
    // connection.
    Timer(AppConstants.splashDuration, () {
      if (mounted) setState(() => _minDurationElapsed = true);
      _maybeNavigate();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Re-check navigation readiness whenever either async source changes
    // state — e.g. auth resolves before the 5s timer fires, or the role
    // read completes slightly after auth does.
    ref.listen(authStateProvider, (_, __) => _maybeNavigate());
    ref.listen(myRoleProvider, (_, __) => _maybeNavigate());

    // ⚠️ NEW — see _maybeNavigate()'s fix note. Shows the real error
    // (e.g. a missing Firestore Database) instead of an infinite spinner.
    if (_roleError != null) {
      return _buildErrorScreen(context);
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.school, size: 120, color: Colors.white),
                const SizedBox(height: 24),
                Text(
                  'JTECAA',
                  style: Theme.of(context)
                      .textTheme
                      .displayMedium
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'Alumni Association',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 40),
                Text(
                  AppConstants.appTagline,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ⚠️ NEW — the actual fix. Shown whenever role resolution
  /// (roles/{uid} read, §M.5) fails for any reason — most commonly a
  /// Firestore Database that was never created in the Firebase Console,
  /// or Security Rules that haven't been deployed yet (both leave every
  /// Firestore call throwing). The raw error is displayed on purpose
  /// during development so the real cause is visible instead of hidden
  /// behind a silent, infinite spinner.
  Widget _buildErrorScreen(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_outlined,
                    size: 56, color: theme.colorScheme.error),
                const SizedBox(height: 16),
                Text('Could not connect', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  '$_roleError',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    final uid = ref.read(authStateProvider).valueOrNull?.uid;
                    setState(() => _roleError = null);
                    if (uid != null) {
                      ref.invalidate(roleProvider(uid));
                    }
                    _maybeNavigate();
                  },
                  child: const Text('Retry'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    await ref.read(authControllerProvider.notifier).signOut();
                    if (!mounted) {
                      return;
                    }
                    setState(() => _roleError = null);
                  },
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _maybeNavigate() {
    if (!_minDurationElapsed || _hasNavigated || !mounted) {
      return;
    }

    final authAsync = ref.read(authStateProvider);
    if (authAsync.isLoading) {
      return;
    } // wait for the auth stream's first event

    final user = authAsync.valueOrNull;
    if (user == null) {
      _navigateOnce(const LoginScreen());
      return;
    }
    if (!user.emailVerified) {
      _navigateOnce(const VerificationGateScreen());
      return;
    }

    final roleAsync = ref.read(myRoleProvider);
    if (roleAsync.isLoading) {
      return; // wait for roles/{uid} to resolve
    }
    // ⚠️ THE ACTUAL FIX (root cause of "stuck on Splash after login"):
    // the previous version only checked `roleAsync.valueOrNull == null`,
    // which is ALSO true when roleAsync is in an ERROR state (no value
    // was ever produced) — so an error was silently treated exactly like
    // "still resolving" and the app waited forever with zero feedback.
    // Any Firestore failure (most commonly: the Firestore Database was
    // never created in the Firebase Console, or Security Rules reject
    // the read) now surfaces here explicitly instead of hanging.
    if (roleAsync.hasError) {
      setState(() => _roleError = roleAsync.error);
      return;
    }
    final role = roleAsync.valueOrNull;
    if (role == null) {
      return; // genuinely still resolving — keep waiting
    }

    if (role == SignupRole.student) {
      _navigateOnce(const StudentShell());
    } else {
      // ⚠️ CHANGED (Phase 4) — was `const _AlumniShellPlaceholder()`.
      _navigateOnce(const HomeScreen());
    }
  }

  void _navigateOnce(Widget screen) {
    if (_hasNavigated || !mounted) {
      return;
    }
    _hasNavigated = true;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => screen),
      (route) => false,
    );
  }
}
