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

  /// Optional semantic tint. When provided, the button renders in that
  /// color's container instead of `primaryContainer`. Useful for
  /// distinguishing WhatsApp/LinkedIn/Facebook at a glance, without
  /// breaking the current default look.
  final Color? tint;

  const QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // Resolve the palette — default is primaryContainer + primary icon.
    final Color bg = tint != null
        ? tint!.withValues(alpha: 0.14)
        : colorScheme.primaryContainer;
    final Color fg = tint ?? colorScheme.primary;

    return Semantics(
      button: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Material(
              color: bg,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                customBorder: const CircleBorder(),
                // Ripple color respects the tint in dark mode.
                splashColor: fg.withValues(alpha: 0.18),
                highlightColor: fg.withValues(alpha: 0.08),
                child: Icon(icon, color: fg, size: 24),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Overflow-proof label — never spills even at 200% text scale
          // or with long localized strings.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              textAlign: TextAlign.center,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                height: 1.2,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
