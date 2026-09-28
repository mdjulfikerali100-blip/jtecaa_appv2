/// lib/presentation/widgets/common/student_drawer.dart
///
/// Side Drawer for the Student shell only.
///
/// ⚠️ DEVIATION FROM ARCHITECTURE (explicit user request): §M.6 says the
/// Student shell has "no side Drawer" and reaches My Profile via an
/// AppBar action. A Drawer with Logout was requested afterwards, so this
/// adds one. The AppBar "My Profile" icon in student_shell.dart is left
/// in place — this drawer is an addition, not a replacement.
///
/// ⚠️ Deliberately NOT a reuse of the Alumni `SideDrawer`:
///   - SideDrawer reads the profile via `profileViewProvider`, which
///     reads `users_private` in Firestore. Students have no such
///     document (§M.4: Student PII lives in Google Sheets only), so it
///     throws "Profile not found" — the red-screen crash that was
///     reported when a Student ended up opening it.
///   - SideDrawer links to Settings, whose "Delete My Account" calls
///     `UserRepository.deleteMyProfileData()` (Alumni Firestore
///     documents). Students delete via `RoleNotifier.
///     deleteStudentAccountAndData()` instead, from My Profile.
/// So this drawer reads only the Firebase Auth user (email), which
/// exists for every role, and never touches Firestore or Sheets.
///
/// ⚠️ UI POLISH (this revision):
///   - Modern gradient header with rounded bottom corners + soft avatar
///     shadow; matches the Alumni drawer's header rhythm.
///   - Menu tiles get icon bubbles + trailing chevrons (from the same
///     design language as the Alumni SideDrawer).
///   - Section labels restyled with a leading accent bar + soft divider.
///   - SwitchListTiles restyled with color-tinted icon chips + tighter
///     copy; subtitles bounded for 200% font scale.
///   - Logout restyled as an outlined destructive tile (icon bubble +
///     label) — matches the Alumni SideDrawer.
///   - Info dialog picks up the theme's rounded shape + onSurface text.
///   - Every Text has bounded maxLines + ellipsis (safe on narrow
///     devices AND at 200% system font scale).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../screens/student/my_profile_screen.dart';
import 'logout_helper.dart';

// M3-tuned brand palette for the header — kept in one place so light/dark
// both read the same gradient.
const _kHeaderNavy = Color(0xFF1B3A5C);
const _kHeaderNavyLight = Color(0xFF2E5580);

class StudentDrawer extends ConsumerWidget {
  const StudentDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // valueOrNull, never `.value` — `.value` rethrows the stored error on
    // an AsyncError in this Riverpod version (the same mistake behind the
    // earlier SideDrawer crash).
    final email = ref.watch(authStateProvider).valueOrNull?.email ?? '';

    // Same providers the Alumni Settings screen uses, so both shells
    // always agree on the current preference (one source of truth).
    final darkModeForced = ref.watch(themeModeProvider) == ThemeMode.dark;
    final pushEnabled = ref.watch(pushNotificationsEnabledProvider);

    return Drawer(
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────
          _StudentDrawerHeader(theme: theme, email: email),

          // ── Scrollable menu ───────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              children: [
                // ── Account ───────────────────────────────────
                _DrawerSectionLabel(label: 'Account', theme: theme),
                const SizedBox(height: 4),
                _DrawerMenuTile(
                  icon: Icons.person_outline_rounded,
                  label: 'My Profile',
                  color: _kHeaderNavy,
                  theme: theme,
                  onTap: () {
                    // pop() then an immediate push() with NO await between
                    // them is safe — the context can't unmount in between.
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MyProfileScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // ── Preferences ───────────────────────────────
                _DrawerSectionLabel(label: 'Preferences', theme: theme),
                const SizedBox(height: 6),

                // Push toggle: OFF unsubscribes from every topic; ON
                // re-subscribes by role, so a Student is put back on
                // "news" ONLY, never "jobs"/"all" (§M.9) — the notifier
                // reads the role itself, nothing to pass here.
                _DrawerSwitchTile(
                  icon: Icons.notifications_outlined,
                  iconColor: const Color(0xFF0F766E),
                  title: 'Push Notifications',
                  value: pushEnabled,
                  onChanged: (v) => ref
                      .read(pushNotificationsEnabledProvider.notifier)
                      .setEnabled(v),
                  theme: theme,
                ),
                const SizedBox(height: 8),

                // ⚠️ This is "force dark", not a Light/Dark pair: ON = dark,
                // OFF = follow the device's own setting (the two-state
                // switch Appendix F.7.9 specifies). Spelled out in the
                // subtitle so OFF isn't mistaken for "force light".
                _DrawerSwitchTile(
                  icon: Icons.dark_mode_outlined,
                  iconColor: const Color(0xFFB45309),
                  title: 'Dark Mode',
                  subtitle:
                      darkModeForced ? 'Always dark' : 'Follows your device',
                  value: darkModeForced,
                  onChanged: (v) =>
                      ref.read(themeModeProvider.notifier).setDarkModeForced(v),
                  theme: theme,
                ),

                const SizedBox(height: 20),

                // ── About ─────────────────────────────────────
                _DrawerSectionLabel(label: 'About', theme: theme),
                const SizedBox(height: 4),
                _DrawerMenuTile(
                  icon: Icons.info_outline_rounded,
                  label: 'About JTECAA',
                  color: const Color(0xFF0F766E),
                  theme: theme,
                  onTap: () => _showInfoDialog(
                    context,
                    'About JTECAA',
                    'JTECAA Alumni Association — connecting textile '
                        'engineering graduates.',
                  ),
                ),
                const SizedBox(height: 4),
                _DrawerMenuTile(
                  icon: Icons.policy_outlined,
                  label: 'Privacy Policy',
                  color: const Color(0xFF1B3A5C),
                  theme: theme,
                  onTap: () => _showInfoDialog(
                    context,
                    'Privacy Policy',
                    'Privacy policy content will be finalized before Play '
                        'Store submission (Phase 13).',
                  ),
                ),
                const SizedBox(height: 4),
                _DrawerMenuTile(
                  icon: Icons.description_outlined,
                  label: 'Terms of Service',
                  color: const Color(0xFF1B3A5C),
                  theme: theme,
                  onTap: () => _showInfoDialog(
                    context,
                    'Terms of Service',
                    'Terms of service content will be finalized before '
                        'Play Store submission (Phase 13).',
                  ),
                ),
              ],
            ),
          ),

          // ── Footer: Logout ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 12),
                _LogoutTile(
                  theme: theme,
                  isDark: isDark,
                  // ⚠️ Do NOT pop the drawer first. confirmAndSignOut()
                  // awaits a dialog and then signOut(); popping first
                  // lets the drawer's close animation unmount this
                  // context mid-flow, and its `context.mounted` guard
                  // then silently skips the final navigation (sign-out
                  // happens, nothing visible follows). Same bug already
                  // fixed in the Alumni SideDrawer.
                  onTap: () => confirmAndSignOut(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Same placeholder dialog + wording as SettingsScreen (Alumni). The real
  // policy/terms text is due in Phase 13, so until then the text lives in
  // BOTH places — update both when it is finalized.
  void _showInfoDialog(BuildContext context, String title, String body) {
    showDialog(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        final dialogTheme = Theme.of(ctx);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: scheme.surfaceContainerHigh,
          surfaceTintColor: Colors.transparent,
          title: Text(
            title,
            style: dialogTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          content: SingleChildScrollView(
            child: Text(
              body,
              style: dialogTheme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                foregroundColor: scheme.primary,
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────
class _StudentDrawerHeader extends StatelessWidget {
  final ThemeData theme;
  final String email;

  const _StudentDrawerHeader({
    required this.theme,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_kHeaderNavy, _kHeaderNavyLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.only(
            bottomRight: Radius.circular(28),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'STUDENT',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.15),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.55),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.20),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.school_outlined,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Student',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (email.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              email,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.82),
                                fontWeight: FontWeight.w400,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// SECTION LABEL — accent bar + label
// ─────────────────────────────────────────────────────────────────────
class _DrawerSectionLabel extends StatelessWidget {
  final String label;
  final ThemeData theme;

  const _DrawerSectionLabel({
    required this.label,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 12,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// MENU TILE — icon bubble + label + chevron
// ─────────────────────────────────────────────────────────────────────
class _DrawerMenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final ThemeData theme;
  final VoidCallback onTap;

  const _DrawerMenuTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final visibleColor = isDark
        ? HSLColor.fromColor(color)
            .withLightness(
              (HSLColor.fromColor(color).lightness + 0.28).clamp(0.55, 0.85),
            )
            .toColor()
        : color;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest
          .withValues(alpha: isDark ? 0.45 : 0.65),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: visibleColor.withValues(alpha: isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: visibleColor.withValues(alpha: isDark ? 0.45 : 0.25),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 19, color: visibleColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// SWITCH TILE — tinted icon chip + title + optional subtitle + switch
// ─────────────────────────────────────────────────────────────────────
class _DrawerSwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final ThemeData theme;

  const _DrawerSwitchTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.onChanged,
    required this.theme,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final visibleColor = isDark
        ? HSLColor.fromColor(iconColor)
            .withLightness(
              (HSLColor.fromColor(iconColor).lightness + 0.28)
                  .clamp(0.55, 0.85),
            )
            .toColor()
        : iconColor;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest
          .withValues(alpha: isDark ? 0.45 : 0.65),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: visibleColor.withValues(alpha: isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: visibleColor.withValues(alpha: isDark ? 0.45 : 0.25),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 19, color: visibleColor),
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
              const SizedBox(width: 4),
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeColor: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// LOGOUT TILE — destructive, outlined
// ─────────────────────────────────────────────────────────────────────
class _LogoutTile extends StatelessWidget {
  final ThemeData theme;
  final bool isDark;
  final VoidCallback onTap;

  const _LogoutTile({
    required this.theme,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final errorColor = theme.colorScheme.error;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: errorColor.withValues(alpha: isDark ? 0.55 : 0.40),
              width: 1,
            ),
            color: errorColor.withValues(alpha: isDark ? 0.10 : 0.06),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: errorColor.withValues(alpha: isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.logout_rounded,
                  size: 19,
                  color: errorColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Logout',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: errorColor,
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
  }
}
