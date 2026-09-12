// lib/presentation/widgets/common/contact_action_buttons.dart
//
// ⚠️ SUPERSEDES the Master Prompt's plain "whatsapp_button.dart" bullet
// for Phase 5. Architecture Appendix D's own (already bug-fixed) code
// explicitly replaces a single WhatsApp-only button with this 4-button
// widget: "ContactActionButtons wraps AppLauncher (Appendix B.1) so every
// button gets the same tel:/https: scheme handling, app-then-browser
// fallback, and visible failure feedback... previously only
// _WhatsAppButton existed, so the other three [Phone/Facebook/LinkedIn]
// simply had nothing to tap." Building only a WhatsApp button now would
// reintroduce the exact gap Appendix K.4 documents as a bug.
//
// No privacy toggles anymore (Appendix E) — a plain null-check on each
// field is sufficient; a missing button just means that alumnus never
// filled in that field, not that it's hidden.

import 'package:flutter/material.dart';

import '../../../core/utils/app_launcher.dart';

class ContactActionButtons extends StatelessWidget {
  final String? phone;
  final String? whatsapp;
  final String? facebook;
  final String? linkedin;

  const ContactActionButtons({
    super.key,
    this.phone,
    this.whatsapp,
    this.facebook,
    this.linkedin,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: [
        if (phone != null && phone!.isNotEmpty)
          _ContactIconButton(
            icon: Icons.call,
            color: const Color(0xFF1A365D),
            tooltip: 'Call',
            onTap: () => AppLauncher.call(context, phone),
          ),
        if (whatsapp != null && whatsapp!.isNotEmpty)
          _ContactIconButton(
            icon: Icons.chat,
            color: const Color(0xFF25D366), // WhatsApp green
            tooltip: 'Chat on WhatsApp',
            onTap: () => AppLauncher.whatsapp(context, whatsapp),
          ),
        if (facebook != null && facebook!.isNotEmpty)
          _ContactIconButton(
            icon: Icons.facebook,
            color: const Color(0xFF1877F2), // Facebook blue
            tooltip: 'Facebook',
            onTap: () => AppLauncher.facebook(context, facebook),
          ),
        if (linkedin != null && linkedin!.isNotEmpty)
          _ContactIconButton(
            icon: Icons
                .business_center, // swap for a LinkedIn brand asset if available
            color: const Color(0xFF0A66C2), // LinkedIn blue
            tooltip: 'LinkedIn',
            onTap: () => AppLauncher.linkedin(context, linkedin),
          ),
      ],
    );
  }
}

class _ContactIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ContactIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: color),
      tooltip: tooltip,
      style:
          IconButton.styleFrom(backgroundColor: color.withValues(alpha: 0.1)),
      // ⚠️ Appendix F.11 Accessibility: keep touch target ≥ 48×48dp even
      // though the icon itself is small — IconButton's default padding
      // already satisfies this; don't shrink padding to "fit" a tight
      // Row, or you trade the overflow bug for a mis-tappable button.
    );
  }
}
