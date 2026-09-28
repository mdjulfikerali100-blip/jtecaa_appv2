// lib/presentation/screens/auth/verification_gate_screen.dart
//
// Architecture §7.1 (Feature 3: Email Verification).
//
// ⚠️ ROOT-CAUSE BUG FIX:
//   Old code read `roleProvider(uid).valueOrNull` synchronously, which
//   ALWAYS returned null on the first frame (provider starts in
//   `AsyncValue.loading()`), so the fallback `?? SignupRole.alumni`
//   mis-routed every newly-verified Student to the Alumni shell.
//
//   `StateNotifierProvider.family` has no `.future` getter and this
//   Riverpod version's `ref.listen` has no `fireImmediately` param, so
//   we use a simple bounded polling loop over `ref.read(...)` until the
//   role resolves (or times out). Same end result, zero API surprises.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/user/role_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/role_provider.dart';
import '../home/home_screen.dart';
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
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _pollTimer =
        Timer.periodic(const Duration(seconds: 4), (_) => _checkVerified());
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVerified());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerified() async {
    if (_isChecking || _isNavigating) return;
    _isChecking = true;
    try {
      await ref.read(authControllerProvider.notifier).reloadUser();
    } catch (_) {
      // Transient reload failure — next poll retries.
    } finally {
      _isChecking = false;
    }

    if (!mounted) return;

    if (ref.read(authControllerProvider.notifier).isEmailVerified) {
      _pollTimer?.cancel();
      await _navigateToShell();
    }
  }

  /// Resolves the current user's role and navigates to the correct shell.
  ///
  /// Uses bounded polling of `ref.read(roleProvider(uid))` until the
  /// AsyncValue leaves the `loading` state (or we time out). This avoids
  /// depending on `.future` (not present on StateNotifierProvider.family)
  /// and `fireImmediately` (not present in this Riverpod version).
  Future<void> _navigateToShell() async {
    if (_isNavigating) return;
    _isNavigating = true;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      return;
    }

    SignupRole role = SignupRole.alumni;

    // Poll up to ~8 seconds for the role to resolve. Each iteration
    // reads the provider's current AsyncValue; if it has data we use
    // it, if it has an error we fall back to Alumni, and if it's still
    // loading we wait 100 ms and try again.
    const maxAttempts = 80; // 80 * 100 ms = 8 s
    for (var i = 0; i < maxAttempts; i++) {
      final async = ref.read(roleProvider(user.uid));
      if (async.hasValue && async.value != null) {
        role = async.value!;
        break;
      }
      if (async.hasError) {
        role = SignupRole.alumni;
        break;
      }
      // Still loading — wait a tick before trying again.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
    }

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => role == SignupRole.student
            ? const StudentShell()
            : const HomeScreen(),
      ),
      (route) => false,
    );
  }

  Future<void> _resend() async {
    setState(() => _isResending = true);
    try {
      await ref.read(authControllerProvider.notifier).sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Verification email sent again.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not resend: $e',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final email =
        ref.watch(authStateProvider).valueOrNull?.email ?? 'your email';

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final maxContentWidth =
                    constraints.maxWidth > 560 ? 480.0 : constraints.maxWidth;

                return Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: constraints.maxWidth > 560 ? 32 : 24,
                      vertical: 24,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: maxContentWidth,
                        minHeight: constraints.maxHeight - 48,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer
                                    .withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.mark_email_unread_outlined,
                                size: 48,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Verify Your Email',
                            textAlign: TextAlign.center,
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'We sent a verification link to',
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
                              child: Text(
                                email,
                                textAlign: TextAlign.center,
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                softWrap: true,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Please check your inbox (and spam folder) and '
                            'tap the link to continue.',
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 36),
                          Center(
                            child: SizedBox(
                              height: 32,
                              width: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.6,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Waiting for verification…',
                            textAlign: TextAlign.center,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 32),
                          OutlinedButton(
                            onPressed: _isResending ? null : _resend,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              side: BorderSide(
                                color: colorScheme.outline,
                                width: 1.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              foregroundColor: colorScheme.onSurface,
                            ),
                            child: _isResending
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: colorScheme.primary,
                                    ),
                                  )
                                : Text(
                                    'Resend Verification Email',
                                    style: textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () async {
                              final navigator = Navigator.of(context);
                              await ref
                                  .read(authControllerProvider.notifier)
                                  .signOut();
                              if (!mounted) return;
                              navigator.pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                                (route) => false,
                              );
                            },
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 44),
                              foregroundColor: colorScheme.primary,
                            ),
                            child: Text(
                              'Sign out',
                              style: textTheme.labelLarge?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            if (_isNavigating)
              Positioned.fill(
                child: Container(
                  color: colorScheme.surface.withValues(alpha: 0.85),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 36,
                        width: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.8,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Signing you in…',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
