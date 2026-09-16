// lib/presentation/widgets/common/quick_action_button.dart
//
// Architecture Appendix F.7.5 — Profile Detail's "Quick Actions Row":
// "Phone | WhatsApp | LinkedIn | Facebook, Icon buttons, 56px, circular,
// primaryContainer". Distinct visual style from Directory's compact
// ContactActionButtons row, but wired through the same AppLauncher
// (Appendix B.1) so it inherits the exact same tel:/https: scheme
// handling and failure feedback — never a second, divergent
// implementation of "how do I open a link".

import 'package:flutter/material.dart';

class QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: Material(
            color: theme.colorScheme.primaryContainer,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Icon(icon, color: theme.colorScheme.primary),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}
