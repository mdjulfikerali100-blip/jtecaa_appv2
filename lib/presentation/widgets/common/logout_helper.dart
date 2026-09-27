/// lib/presentation/widgets/common/logout_helper.dart
///
/// Extracted from home_screen.dart's original `_confirmLogout()` (Phase 4)
/// so Side Drawer (Phase 10) and Settings' "Danger Zone: Logout" (Phase
/// 10) can both call the exact same confirm → sign out → route-to-Splash
/// flow instead of each screen growing its own slightly-different copy.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../screens/splash/splash_screen.dart';

Future<void> confirmAndSignOut(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Log out?'),
      content:
          const Text('You will need to sign in again to access your account.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out')),
      ],
    ),
  );
  if (confirmed != true) return;

  await ref.read(authControllerProvider.notifier).signOut();
  if (!context.mounted) return;

  // Routes back through SplashScreen so its normal "no user -> LoginScreen"
  // logic runs — same pattern the original home_screen.dart used.
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const SplashScreen()),
    (route) => false,
  );
}
