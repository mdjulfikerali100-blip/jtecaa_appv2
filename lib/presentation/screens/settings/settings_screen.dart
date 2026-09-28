// lib/presentation/screens/settings/settings_screen.dart
//
// Architecture Appendix F.7.9 — Preferences / Account / About / Danger
// sections. "Change Password" has no dedicated in-app change-password
// screen anywhere in the spec so far, so it's implemented the same way
// Forgot Password (Phase 3) already works: send a reset link to the
// signed-in user's own email via Firebase Auth, rather than inventing an
// unspec'd in-app old/new-password form.
//
// ⚠️ VISUAL UPGRADE (this revision):
//   • Cards instead of bare rows — each section (Preferences / Account
//     / About / Danger Zone) sits in its own rounded card with a header
//     eyebrow, so the whole screen reads as a proper settings page.
//   • Switch tiles have tinted icon bubbles (the "on" state shows the
//     accent colour), so toggling produces a visible response.
//   • Action tiles get coloured icon bubbles + chevrons — every row
//     reads as tappable at a glance.
//   • Danger Zone card is outlined in the error colour so destructive
//     actions are visually separate from everything else.
//   • All colours derive from Material 3 roles → legible in both
//     light and dark. No hardcoded greys anywhere.
//
//   No logic has been changed. Every onTap / onChanged / dialog / SnackBar
//   is byte-for-byte the same as before.

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
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // ═══════════════ PREFERENCES ═══════════════
          _SectionCard(
            title: 'Preferences',
            theme: theme,
            children: [
              _SwitchTile(
                theme: theme,
                icon: Icons.notifications_outlined,
                iconColor: const Color(0xFF0F766E),
                title: 'Push Notifications',
                subtitle: 'Receive job alerts and news',
                value: pushEnabled,
                onChanged: (v) => ref
                    .read(pushNotificationsEnabledProvider.notifier)
                    .setEnabled(v),
              ),
              _CardDivider(theme: theme),
              _SwitchTile(
                theme: theme,
                icon: Icons.dark_mode_outlined,
                iconColor: const Color(0xFF7C3AED),
                title: 'Dark Mode',
                subtitle: 'Force dark theme for the app',
                value: darkModeForced,
                onChanged: (v) =>
                    ref.read(themeModeProvider.notifier).setDarkModeForced(v),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ═══════════════ ACCOUNT ═══════════════
          _SectionCard(
            title: 'Account',
            theme: theme,
            children: [
              _ActionTile(
                theme: theme,
                icon: Icons.password_outlined,
                iconColor: const Color(0xFF2563EB),
                title: 'Change Password',
                subtitle: 'Send a reset link to your email',
                onTap: () => _changePassword(context, ref),
              ),
              _CardDivider(theme: theme),
              _ActionTile(
                theme: theme,
                icon: Icons.delete_forever_outlined,
                iconColor: theme.colorScheme.error,
                title: 'Delete My Account',
                subtitle: 'Permanently remove your data',
                isDestructive: true,
                onTap: () => _confirmDeleteAccount(context, ref),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ═══════════════ ABOUT ═══════════════
          _SectionCard(
            title: 'About',
            theme: theme,
            children: [
              _ActionTile(
                theme: theme,
                icon: Icons.info_outline,
                iconColor: const Color(0xFF1B3A5C),
                title: 'About JTECAA',
                onTap: () => _showInfoDialog(
                  context,
                  'About JTECAA',
                  'JTECAA Alumni Association — connecting textile engineering graduates.',
                ),
              ),
              _CardDivider(theme: theme),
              _ActionTile(
                theme: theme,
                icon: Icons.policy_outlined,
                iconColor: const Color(0xFF0F766E),
                title: 'Privacy Policy',
                onTap: () => _showInfoDialog(
                  context,
                  'Privacy Policy',
                  'Privacy policy content will be finalized before Play Store submission (Phase 13).',
                ),
              ),
              _CardDivider(theme: theme),
              _ActionTile(
                theme: theme,
                icon: Icons.description_outlined,
                iconColor: const Color(0xFFB45309),
                title: 'Terms of Service',
                onTap: () => _showInfoDialog(
                  context,
                  'Terms of Service',
                  'Terms of service content will be finalized before Play Store submission (Phase 13).',
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ═══════════════ DANGER ZONE ═══════════════
          _DangerCard(
            theme: theme,
            onLogout: () => confirmAndSignOut(context, ref),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // LOGIC — unchanged
  // ─────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────
// SECTION CARD — rounded container with a section title above it
// ─────────────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final ThemeData theme;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.theme,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: isDark ? 0.45 : 0.65),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// DANGER CARD — same shape but outlined in the error colour
// ─────────────────────────────────────────────────────────────────────
class _DangerCard extends StatelessWidget {
  final ThemeData theme;
  final VoidCallback onLogout;

  const _DangerCard({
    required this.theme,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final err = theme.colorScheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            'DANGER ZONE',
            style: theme.textTheme.labelSmall?.copyWith(
              color: err,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: err.withValues(alpha: isDark ? 0.08 : 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: err.withValues(alpha: isDark ? 0.45 : 0.30),
              width: 1,
            ),
          ),
          child: _ActionTile(
            theme: theme,
            icon: Icons.logout_rounded,
            iconColor: err,
            title: 'Logout',
            subtitle: 'Sign out of this device',
            isDestructive: true,
            onTap: onLogout,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// SWITCH TILE — icon bubble + label + subtitle + switch
// ─────────────────────────────────────────────────────────────────────
class _SwitchTile extends StatelessWidget {
  final ThemeData theme;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.theme,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final visibleColor = isDark
        ? HSLColor.fromColor(iconColor)
            .withLightness((HSLColor.fromColor(iconColor).lightness + 0.28)
                .clamp(0.55, 0.85))
            .toColor()
        : iconColor;

    // When the switch is on, the bubble gets a tinted background so the
    // change is visible in the row itself (not just the switch thumb).
    final bubbleBg = value
        ? visibleColor.withValues(alpha: isDark ? 0.22 : 0.12)
        : theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: isDark ? 0.6 : 0.9);
    final bubbleBorder = value
        ? visibleColor.withValues(alpha: isDark ? 0.5 : 0.3)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.5);

    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bubbleBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: bubbleBorder, width: 1),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 20,
                color:
                    value ? visibleColor : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// ACTION TILE — icon bubble + label + optional subtitle + chevron
// ─────────────────────────────────────────────────────────────────────
class _ActionTile extends StatelessWidget {
  final ThemeData theme;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final bool isDestructive;
  final VoidCallback onTap;

  const _ActionTile({
    required this.theme,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final visibleColor = isDark
        ? HSLColor.fromColor(iconColor)
            .withLightness((HSLColor.fromColor(iconColor).lightness + 0.28)
                .clamp(0.55, 0.85))
            .toColor()
        : iconColor;

    final textColor =
        isDestructive ? theme.colorScheme.error : theme.colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: visibleColor.withValues(alpha: isDark ? 0.20 : 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: visibleColor.withValues(alpha: isDark ? 0.45 : 0.25),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 20, color: visibleColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDestructive
                            ? theme.colorScheme.error.withValues(alpha: 0.75)
                            : theme.colorScheme.onSurfaceVariant,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDestructive
                  ? theme.colorScheme.error.withValues(alpha: 0.6)
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// THIN DIVIDER between tiles inside a card
// ─────────────────────────────────────────────────────────────────────
class _CardDivider extends StatelessWidget {
  final ThemeData theme;

  const _CardDivider({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 66, right: 14),
      child: Divider(
        height: 1,
        thickness: 1,
        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
      ),
    );
  }
}
