// lib/presentation/screens/student/student_shell.dart
//
// Architecture §M.1/§M.6: "Students: Directory + News only." No Dashboard
// or Jobs route is registered anywhere in this file — not even hidden —
// so a Student can never reach them, even via a deep link that only this
// shell's Navigator would resolve. §M.6 also specifies "no side Drawer"
// for this shell — My Profile is reached via an AppBar action instead.
//
// ⚠️ PHASE-ORDERING NOTE (per the Master Prompt's own instruction for
// Phase 3B): "wire the News-tab reuse only once Phase 8 exists." Both
// Phase 5 (DirectoryScreen) and Phase 8 (NewsScreen) now exist, so both
// tabs below are the real, wired-in screens — no placeholder remains in
// this shell.

import 'package:flutter/material.dart';

import '../directory/directory_screen.dart'; // ⚠️ NEW (Phase 5) — replaces the placeholder
import '../news/news_screen.dart'; // ⚠️ NEW (Phase 8) — replaces the placeholder
import 'my_profile_screen.dart';

class StudentShell extends StatefulWidget {
  const StudentShell({super.key});

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int _currentIndex = 0;

  // ⚠️ CHANGED (Phase 5) — Directory tab is now the real DirectoryScreen
  // (§M.6: "Reused as-is... no separate Student version needed").
  // ⚠️ CHANGED (Phase 8) — News tab is now the real NewsScreen. Role
  // awareness lives INSIDE NewsScreen itself via `myRoleProvider`
  // (Addendum §6 design decision — not a constructor flag here), so the
  // "+ Post News" FAB is already hidden for Students with zero extra
  // wiring needed at this call site.
  static const List<Widget> _tabs = [
    DirectoryScreen(),
    NewsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('JTECAA — Student'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'My Profile',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyProfileScreen()),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Directory',
          ),
          NavigationDestination(
            icon: Icon(Icons.article_outlined),
            selectedIcon: Icon(Icons.article),
            label: 'News',
          ),
        ],
      ),
    );
  }
}
