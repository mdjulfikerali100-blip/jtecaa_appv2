// lib/presentation/screens/student/student_shell.dart
//
// Architecture §M.1/§M.6: "Students: Directory + News only." No Dashboard
// or Jobs route is registered anywhere in this file — not even hidden —
// so a Student can never reach them, even via a deep link that only this
// shell's Navigator would resolve. §M.6 also specifies "no side Drawer"
// for this shell — My Profile is reached via an AppBar action instead.
//
// ⚠️ PHASE-ORDERING NOTE (per the Master Prompt's own instruction for
// Phase 3B): "wire the News-tab reuse only once Phase 8 exists." Phase 5
// (DirectoryScreen) and Phase 8 (NewsScreen) don't exist yet, so the two
// tabs below render complete, runnable placeholder content —
// stubs — so this shell compiles and its navigation/bottom-nav behavior
// is fully testable today. When Phase 5/8 land, swapping in the real
// screens is a two-line change (import + replace the placeholder widget
// in `_tabs`) — nothing else in this file needs to move.

import 'package:flutter/material.dart';

import '../directory/directory_screen.dart'; // ⚠️ NEW (Phase 5) — replaces the placeholder
import 'my_profile_screen.dart';

class StudentShell extends StatefulWidget {
  const StudentShell({super.key});

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int _currentIndex = 0;

  // ⚠️ CHANGED (Phase 5) — Directory tab is now the real DirectoryScreen
  // (§M.6: "Reused as-is... no separate Student version needed"). News
  // tab remains a placeholder until Phase 8.
  static const List<Widget> _tabs = [
    DirectoryScreen(),
    _StudentPlaceholderTab(
      icon: Icons.article_outlined,
      label: 'News & Updates',
      note: 'NewsScreen (Phase 8) will render here, with the "+ Post News" '
          'FAB hidden for Students — view-only access (§M.1).',
    ),
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

class _StudentPlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final String note;

  const _StudentPlaceholderTab({
    required this.icon,
    required this.label,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(label, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              note,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
