// lib/presentation/screens/student/student_shell.dart
//
// Architecture §M.1/§M.6: "Students: Directory + News only." No Dashboard
// or Jobs route is registered anywhere in this file — not even hidden —
// so a Student can never reach them, even via a deep link that only this
// shell's Navigator would resolve. §M.6 also specifies "no side Drawer"
// for this shell — My Profile is reached via an AppBar action instead.
// ⚠️ UPDATED: a Student-only Drawer (My Profile + Logout) was added at the
// user's explicit request, deviating from that §M.6 line.
// ⚠️ UPDATED (this revision): the AppBar "My Profile" action was REMOVED
// — My Profile is now reached only via the drawer, so the icon was
// redundant clutter in the top bar.
//
// ⚠️ PHASE-ORDERING NOTE (per the Master Prompt's own instruction for
// Phase 3B): "wire the News-tab reuse only once Phase 8 exists." Both
// Phase 5 (DirectoryScreen) and Phase 8 (NewsScreen) now exist, so both
// tabs below are the real, wired-in screens — no placeholder remains in
// this shell.
//
// ⚠️ UI POLISH: modern Material 3 AppBar + NavigationBar with subtle
// outline borders, theme-tuned indicator/label colors, and rounded
// icons. Matches the visual language of the Login / Signup / Jobs /
// News screens. Zero behaviour change.

import 'package:flutter/material.dart';

import '../../widgets/common/student_drawer.dart';
import '../directory/directory_screen.dart';
import '../news/news_screen.dart';

class StudentShell extends StatefulWidget {
  const StudentShell({super.key});

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int _currentIndex = 0;

  static const List<Widget> _tabs = [
    DirectoryScreen(),
    NewsScreen(),
  ];

  void _onTabSelected(int i) {
    if (_currentIndex == i) return;
    setState(() => _currentIndex = i);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,

      // Student-only drawer. Because this Scaffold has a real `appBar:`
      // (unlike the Alumni Home's SliverAppBar), Flutter inserts the
      // hamburger button automatically — no manual `leading:` needed.
      drawer: const StudentDrawer(),

      appBar: AppBar(
        title: Text(
          'JTECAA — Student',
          style: theme.textTheme.titleLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        iconTheme: IconThemeData(color: colorScheme.onSurface, size: 24),
        // ⚠️ AppBar "My Profile" action removed — My Profile lives in the
        // drawer now, so a second entry point in the top bar was visual
        // noise. The drawer is the single source for profile access.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),

      body: IndexedStack(index: _currentIndex, children: _tabs),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: colorScheme.surface,
            indicatorColor: colorScheme.primaryContainer.withValues(alpha: 0.6),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return theme.textTheme.labelMedium?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                letterSpacing: 0.2,
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return IconThemeData(
                size: 22,
                color: selected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              );
            }),
            elevation: 0,
            height: 68,
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onTabSelected,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.people_outline_rounded),
                selectedIcon: Icon(Icons.people_rounded),
                label: 'Directory',
              ),
              NavigationDestination(
                icon: Icon(Icons.article_outlined),
                selectedIcon: Icon(Icons.article_rounded),
                label: 'News',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
