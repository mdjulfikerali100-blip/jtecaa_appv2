// lib/presentation/screens/auth/verification_gate_screen.dart
//
// Architecture §7.1 (Feature 3: Email Verification) — checks
// email_verified, offers a resend button, and once verified routes to
// the correct shell based on role (§M.6).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/user/role_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/role_provider.dart';
import '../student/student_shell.dart';
import 'login_screen.dart';

class VerificationGateScreen extends ConsumerStatefulWidget {
  const VerificationGateScreen({super.key});

  @override
  ConsumerState<VerificationGateScreen> createState() =>
      _VerificationGateScreenState();
}

class _VerificationGateScreenState
    extends ConsumerState<VerificationGateScreen> {
  Timer? _pollTimer;
  bool _isResending = false;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    // Poll every 4s for the user tapping the verification link in their
    // inbox — Firebase Auth's local `emailVerified` flag only updates
    // after an explicit `reload()`, it doesn't push automatically.
    _pollTimer =
        Timer.periodic(const Duration(seconds: 4), (_) => _checkVerified());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerified() async {
    if (_isChecking) {
      return;
    }
    _isChecking = true;
    await ref.read(authControllerProvider.notifier).reloadUser();
    _isChecking = false;
    if (!mounted) {
      return;
    }

    if (ref.read(authControllerProvider.notifier).isEmailVerified) {
      _pollTimer?.cancel();
      _navigateToShell();
    }
  }

  void _navigateToShell() {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      return;
    }
    final roleAsync = ref.read(roleProvider(user.uid));
    final role = roleAsync.valueOrNull ?? SignupRole.alumni;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => role == SignupRole.student
            ? const StudentShell()
            : const _AlumniShellPlaceholder(),
      ),
      (route) => false,
    );
  }

  Future<void> _resend() async {
    setState(() => _isResending = true);
    try {
      await ref.read(authControllerProvider.notifier).sendEmailVerification();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification email sent again.')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not resend: $e')),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email =
        ref.watch(authStateProvider).valueOrNull?.email ?? 'your email';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mark_email_unread_outlined,
                    size: 72, color: theme.colorScheme.primary),
                const SizedBox(height: 24),
                Text('Verify Your Email', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'We sent a verification link to $email. Please check your inbox '
                  '(spam folder) and tap the link to continue.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 32),
                const CircularProgressIndicator(),
                const SizedBox(height: 8),
                Text('Waiting for verification...',
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: _isResending ? null : _resend,
                  child: _isResending
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Resend Verification Email'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    // ⚠️ FIX (use_build_context_synchronously): capture
                    // the Navigator BEFORE the `await`, not after — the
                    // `mounted` check alone doesn't satisfy this lint
                    // because it can't statically prove `context` itself
                    // is still valid at the point of use, only that the
                    // State object hasn't been disposed. Grabbing
                    // `Navigator.of(context)` while `context` is
                    // definitely fresh (before any await) avoids the
                    // warning without changing behavior.
                    final navigator = Navigator.of(context);
                    await ref.read(authControllerProvider.notifier).signOut();
                    if (!mounted) {
                      return;
                    }
                    navigator.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
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
}

/// ⚠️ TEMPORARY — see splash_screen.dart's identical placeholder for the
/// full explanation. HomeScreen (Phase 4) will replace this.
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
