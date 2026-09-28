// lib/presentation/widgets/common/side_drawer.dart
//
// Architecture Appendix F.6.J — "Header: User avatar (64px), Name, Email
// (gradient background, 180px). Menu: Profile, News, Settings, Logout."
// Alumni shell only — Student shell has its own minimal top bar (§M.6).
//
// ⚠️ ROOT-CAUSE BUG FIX:
//   Old code called `profileAsync.value` which THROWS when the provider
//   is in `AsyncError` state. When a user without an alumni profile
//   landed on the Alumni shell, `profileViewProvider` threw
//   `NetworkException: Profile not found`, crashing the drawer.
//   Fixed: use `.valueOrNull` + fall back to auth user + inline retry.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../screens/news/news_screen.dart';
import '../../screens/profile/profile_detail_screen.dart';
import '../../screens/settings/settings_screen.dart';
import 'drive_image.dart';
import 'logout_helper.dart';

const _kBrandNavy = Color(0xFF1B3A5C);
const _kBrandNavyLight = Color(0xFF2E5580);

class SideDrawer extends ConsumerWidget {
  const SideDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final myUid = ref.watch(currentUidProvider);

    final profileAsync =
        myUid == null ? null : ref.watch(profileViewProvider(myUid));
    final profile = profileAsync?.valueOrNull;

    final authUser = ref.watch(authStateProvider).valueOrNull;
    final hasPhoto =
        profile?.photoUrl != null && profile!.photoUrl!.trim().isNotEmpty;
    final fullName = (profile?.fullName ?? authUser?.displayName ?? '').trim();
    final email = (profile?.email ?? authUser?.email ?? '').trim();
    final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

    final profileErrored = profileAsync?.hasError == true;

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
          _DrawerHeader(
            theme: theme,
            colorScheme: colorScheme,
            hasPhoto: hasPhoto,
            photoFileId: profile?.photoUrl,
            initial: initial,
            fullName: fullName,
            email: email,
            onTap: myUid == null
                ? null
                : () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProfileDetailScreen(uid: myUid),
                      ),
                    );
                  },
          ),
          if (profileErrored && myUid != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: _ProfileLoadNotice(
                theme: theme,
                onRetry: () => ref.invalidate(profileViewProvider(myUid)),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              children: [
                _DrawerSectionLabel(label: 'Account', theme: theme),
                const SizedBox(height: 4),
                _DrawerMenuTile(
                  icon: Icons.person_outline_rounded,
                  label: 'Profile',
                  color: _kBrandNavy,
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    if (myUid == null) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProfileDetailScreen(uid: myUid),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                _DrawerMenuTile(
                  icon: Icons.article_outlined,
                  label: 'News',
                  color: const Color(0xFF0F766E),
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const NewsScreen()),
                    );
                  },
                ),
                const SizedBox(height: 4),
                _DrawerMenuTile(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  color: const Color(0xFFB45309),
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
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
                  onTap: () => confirmAndSignOut(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────
class _DrawerHeader extends StatelessWidget {
  final ThemeData theme;
  final ColorScheme colorScheme;
  final bool hasPhoto;
  final String? photoFileId;
  final String initial;
  final String fullName;
  final String email;
  final VoidCallback? onTap;

  const _DrawerHeader({
    required this.theme,
    required this.colorScheme,
    required this.hasPhoto,
    required this.photoFileId,
    required this.initial,
    required this.fullName,
    required this.email,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_kBrandNavy, _kBrandNavyLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
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
                  Row(
                    children: [
                      Text(
                        'MENU',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.4,
                        ),
                      ),
                    ],
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
                        child: ClipOval(
                          child: hasPhoto && photoFileId != null
                              ? DriveImage(
                                  fileId: photoFileId!,
                                  width: 64,
                                  height: 64,
                                )
                              : Center(
                                  child: Text(
                                    initial,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
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
                              fullName.isNotEmpty ? fullName : 'Guest',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                height: 1.15,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (email.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.80),
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
                  if (onTap != null) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'View profile',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// PROFILE LOAD NOTICE
// ─────────────────────────────────────────────────────────────────────
class _ProfileLoadNotice extends StatelessWidget {
  final ThemeData theme;
  final VoidCallback onRetry;

  const _ProfileLoadNotice({
    required this.theme,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.errorContainer.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: scheme.onErrorContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Couldn't load your profile.",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: scheme.onErrorContainer,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// SECTION LABEL
// ─────────────────────────────────────────────────────────────────────
class _DrawerSectionLabel extends StatelessWidget {
  final String label;
  final ThemeData theme;

  const _DrawerSectionLabel({required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.6,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// MENU TILE
// ─────────────────────────────────────────────────────────────────────
class _DrawerMenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _DrawerMenuTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final visibleColor = isDark
        ? HSLColor.fromColor(color)
            .withLightness(
                (HSLColor.fromColor(color).lightness + 0.28).clamp(0.55, 0.85))
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
// LOGOUT TILE
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
