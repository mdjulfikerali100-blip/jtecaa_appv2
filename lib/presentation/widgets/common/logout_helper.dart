// lib/presentation/widgets/common/logout_helper.dart
//
// Extracted from home_screen.dart's original `_confirmLogout()` (Phase 4)
// so Side Drawer (Phase 10) and Settings' "Danger Zone: Logout" (Phase
// 10) can both call the exact same confirm → sign out → route-to-Splash
// flow instead of each screen growing its own slightly-different copy.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../screens/splash/splash_screen.dart';

/// Shows a themed confirmation dialog, signs the user out on confirm,
/// and routes back through SplashScreen so its "no user → LoginScreen"
/// logic runs (same pattern the original home_screen.dart used).
Future<void> confirmAndSignOut(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      final textTheme = Theme.of(ctx).textTheme;

      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.errorContainer.withValues(alpha: 0.6),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.logout_rounded,
            size: 26,
            color: scheme.onErrorContainer,
          ),
        ),
        title: Text(
          'Log out?',
          textAlign: TextAlign.center,
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        content: Text(
          'You will need to sign in again to access your account.',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          // Cancel — neutral, left-aligned
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              foregroundColor: scheme.onSurfaceVariant,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            child: const Text('Cancel'),
          ),
          // Log out — destructive, right-aligned, prominent
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.logout_rounded, size: 16),
            label: const Text('Log out'),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      );
    },
  );

  if (confirmed != true) return;

  await ref.read(authControllerProvider.notifier).signOut();
  if (!context.mounted) return;

  // Routes back through SplashScreen so its normal "no user → LoginScreen"
  // logic runs — same pattern the original home_screen.dart used.
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const SplashScreen()),
    (route) => false,
  );
}
