/// lib/presentation/widgets/common/side_drawer.dart
///
/// Architecture Appendix F.6.J — "Header: User avatar (64px), Name, Email
/// (gradient background, 180px). Menu: Profile, News, Settings, Logout."
/// Alumni shell only — Student shell has its own minimal top bar
/// (§M.6), no drawer.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../screens/news/news_screen.dart';
import '../../screens/profile/profile_detail_screen.dart';
import '../../screens/settings/settings_screen.dart';
import 'logout_helper.dart';

class SideDrawer extends ConsumerWidget {
  const SideDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final myUid = ref.watch(currentUidProvider);
    // profileViewProvider(uid) with uid == the signed-in user routes to the
    // richer "own profile" path (email included) — see profile_provider.dart.
    final profileAsync =
        myUid == null ? null : ref.watch(profileViewProvider(myUid));

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 180,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white24,
                    child: Text(
                      (profileAsync?.value?.fullName.isNotEmpty ?? false)
                          ? profileAsync!.value!.fullName[0]
                          : '?',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    profileAsync?.value?.fullName ?? '',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    profileAsync?.value?.email ?? '',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.white70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Profile'),
                    onTap: () {
                      Navigator.pop(context); // close drawer first
                      if (myUid == null) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => ProfileDetailScreen(uid: myUid)),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.article_outlined),
                    title: const Text('News'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const NewsScreen()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Settings'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.logout, color: theme.colorScheme.error),
              title: Text('Logout',
                  style: TextStyle(color: theme.colorScheme.error)),
              // ⚠️ BUG FIX (root cause): do NOT pop the drawer here first.
              // confirmAndSignOut() is async (awaits showDialog(), then
              // awaits signOut()) — popping this ListTile's context before
              // those awaits lets the drawer's close animation unmount it
              // mid-flow, so confirmAndSignOut()'s own `context.mounted`
              // guard silently returns before ever navigating to
              // SplashScreen (sign-out still happens, but nothing visible
              // follows it). Leaving the drawer open behind the confirm
              // dialog is harmless — the dialog barrier dims it, and a
              // successful logout's `pushAndRemoveUntil` sweeps the whole
              // stack (drawer included) away regardless.
              onTap: () => confirmAndSignOut(context, ref),
            ),
            // ⚠️ No app-version footer here — `package_info_plus` isn't in
            // the pubspec dependency list (Appendix H.2) and no confirmed
            // `AppConstants.appVersion` field was available to reference,
            // so a version string was left out rather than guessed at.
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
