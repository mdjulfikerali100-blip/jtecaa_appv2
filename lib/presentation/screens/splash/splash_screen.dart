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

  void _maybeNavigate() {
    if (!_minDurationElapsed || _hasNavigated || !mounted) return;

    final authAsync = ref.read(authStateProvider);
    if (authAsync.isLoading) return; // wait for the auth stream's first event

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
    if (roleAsync.isLoading) return; // wait for roles/{uid} to resolve
    final role = roleAsync.valueOrNull;
    if (role == null)
      return; // still resolving or an error state — stay on splash

    if (role == SignupRole.student) {
      _navigateOnce(const StudentShell());
    } else {
      _navigateOnce(const _AlumniShellPlaceholder());
    }
  }

  void _navigateOnce(Widget screen) {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => screen),
      (route) => false,
    );
  }
}

/// ⚠️ TEMPORARY — HomeScreen (Phase 4) doesn't exist yet. This is a
/// complete, runnable placeholder so Splash's navigation logic is fully
/// testable today; Phase 4 will replace `_AlumniShellPlaceholder()` above
/// with `const HomeScreen()` — a one-line change, nothing else in this
/// file needs to move.
class _AlumniShellPlaceholder extends StatelessWidget {
  const _AlumniShellPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('JTECAA')),
      body:
          const Center(child: Text('Alumni Home (Phase 4) will render here.')),
    );
  }
}
