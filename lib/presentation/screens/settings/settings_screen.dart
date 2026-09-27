// lib/presentation/screens/settings/settings_screen.dart

// Architecture Appendix F.7.9 — Preferences / Account / About / Danger
// sections. "Change Password" has no dedicated in-app change-password
// screen anywhere in the spec so far, so it's implemented the same way
// Forgot Password (Phase 3) already works: send a reset link to the
// signed-in user's own email via Firebase Auth, rather than inventing an
// unspec'd in-app old/new-password form.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/common/logout_helper.dart';
import '../splash/splash_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pushEnabled = ref.watch(pushNotificationsEnabledProvider);
    final darkModeForced = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _SectionHeader('Preferences', theme),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Push Notifications'),
            value: pushEnabled,
            onChanged: (v) => ref
                .read(pushNotificationsEnabledProvider.notifier)
                .setEnabled(v),
          ),
          const Divider(height: 1, indent: 56),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('Dark Mode'),
            value: darkModeForced,
            onChanged: (v) =>
                ref.read(themeModeProvider.notifier).setDarkModeForced(v),
          ),
          _SectionHeader('Account', theme),
          ListTile(
            leading: const Icon(Icons.password_outlined),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _changePassword(context, ref),
          ),
          ListTile(
            leading: Icon(Icons.delete_forever_outlined,
                color: theme.colorScheme.error),
            title: Text('Delete My Account',
                style: TextStyle(color: theme.colorScheme.error)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _confirmDeleteAccount(context, ref),
          ),
          _SectionHeader('About', theme),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About JTECAA'),
            onTap: () => _showInfoDialog(context, 'About JTECAA',
                'JTECAA Alumni Association — connecting textile engineering graduates.'),
          ),
          ListTile(
            leading: const Icon(Icons.policy_outlined),
            title: const Text('Privacy Policy'),
            onTap: () => _showInfoDialog(context, 'Privacy Policy',
                'Privacy policy content will be finalized before Play Store submission (Phase 13).'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Service'),
            onTap: () => _showInfoDialog(context, 'Terms of Service',
                'Terms of service content will be finalized before Play Store submission (Phase 13).'),
          ),
          _SectionHeader('Danger Zone', theme),
          ListTile(
            leading: Icon(Icons.logout, color: theme.colorScheme.error),
            title: Text('Logout',
                style: TextStyle(color: theme.colorScheme.error)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => confirmAndSignOut(context, ref),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String body) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final email = ref.read(authStateProvider).valueOrNull?.email;
    if (email == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: Text('Send a password reset link to $email?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Send Link')),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await ref
        .read(authControllerProvider.notifier)
        .sendPasswordReset(email);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              ok ? 'Reset link sent to $email' : 'Could not send reset link')),
    );
  }

  /// ⚠️ Deletes `users_private`/`users_public` (via
  /// `UserRepository.deleteMyProfileData()`, Phase 10 addition) then the
  /// Firebase Auth account itself. Deliberately does NOT delete
  /// `roles/{uid}` — that document's write-once Security Rule
  /// (`!exists(...)`) makes any delete permission-denied by construction,
  /// the same reasoning `role_provider.dart`'s
  /// `deleteStudentAccountAndData()` already documents for Students.
  ///
  /// ⚠️ WILL FAIL UNTIL PHASE 11 ADDS `allow delete` RULES for
  /// users_private/users_public — see `deleteMyProfileData()`'s own
  /// doc comment in user_repository.dart for the full explanation.
  Future<void> _confirmDeleteAccount(
      BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
            'This permanently deletes your profile and directory listing. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: TextStyle(color: theme.colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    try {
      await ref.read(userRepositoryProvider).deleteMyProfileData(uid);
      await ref.read(authServiceProvider).deleteAccount();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final ThemeData theme;
  const _SectionHeader(this.title, this.theme);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
