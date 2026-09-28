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
//
// ⚠️ SMART DRAWER REDESIGN (this revision):
//   Previously rendered up to 4 brand-coloured icon buttons inline
//   inside every directory card, consuming ~88dp and forcing a cramped
//   2×2 grid on narrow screens. This revision collapses them into a
//   single top-right "Contact" pill that opens a themed bottom sheet
//   with one labelled row per action.
//
// ⚠️ LABEL-ONLY DRAWER:
//   The sheet shows only action labels (Call / WhatsApp / Facebook /
//   LinkedIn). Raw phone numbers and shared Facebook / LinkedIn URLs
//   are deliberately hidden — they were getting ellipsized mid-URL and
//   looked broken.
//
//   The public API is unchanged: `ContactActionButtons` still takes the
//   same 4 optional fields + an optional `contactName`.

import 'package:flutter/material.dart';

import '../../../core/utils/app_launcher.dart';

class ContactActionButtons extends StatelessWidget {
  final String? phone;
  final String? whatsapp;
  final String? facebook;
  final String? linkedin;

  /// Display name shown in the drawer title. Optional — when omitted the
  /// sheet header reads just "Contact".
  final String? contactName;

  const ContactActionButtons({
    super.key,
    this.phone,
    this.whatsapp,
    this.facebook,
    this.linkedin,
    this.contactName,
  });

  bool get _hasAnyContact =>
      (phone != null && phone!.isNotEmpty) ||
      (whatsapp != null && whatsapp!.isNotEmpty) ||
      (facebook != null && facebook!.isNotEmpty) ||
      (linkedin != null && linkedin!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    if (!_hasAnyContact) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // ⚠️ Small pill-shaped "Contact" button anchored to the top-right
    // of the card. Replaces the bare "…" icon so the action is
    // self-evident. Sized to fit the name row without overlapping it
    // even at largest text scale.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openActionsSheet(context),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(
              alpha: isDark ? 0.55 : 0.85,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_add_alt_1_rounded,
                size: 14,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 4),
              Text(
                'Contact',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openActionsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ContactActionsSheet(
        contactName: contactName,
        phone: phone,
        whatsapp: whatsapp,
        facebook: facebook,
        linkedin: linkedin,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Bottom sheet — list of every available contact action (label only)
// ─────────────────────────────────────────────────────────────────────
class _ContactActionsSheet extends StatelessWidget {
  final String? contactName;
  final String? phone;
  final String? whatsapp;
  final String? facebook;
  final String? linkedin;

  const _ContactActionsSheet({
    this.contactName,
    this.phone,
    this.whatsapp,
    this.facebook,
    this.linkedin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              contactName != null && contactName!.trim().isNotEmpty
                  ? 'Contact ${contactName!.trim()}'
                  : 'Contact',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Choose how you want to reach out',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 8),

            // Actions — label only, raw URL / phone number deliberately
            // hidden (see file header note).
            if (phone != null && phone!.isNotEmpty)
              _ActionTile(
                icon: Icons.call,
                label: 'Call',
                brandColor: const Color(0xFF1A365D),
                isDark: isDark,
                onTap: () {
                  Navigator.of(context).pop();
                  AppLauncher.call(context, phone);
                },
              ),

            if (whatsapp != null && whatsapp!.isNotEmpty)
              _ActionTile(
                icon: Icons.chat,
                label: 'WhatsApp',
                brandColor: const Color(0xFF25D366),
                isDark: isDark,
                onTap: () {
                  Navigator.of(context).pop();
                  AppLauncher.whatsapp(context, whatsapp);
                },
              ),

            if (facebook != null && facebook!.isNotEmpty)
              _ActionTile(
                icon: Icons.facebook,
                label: 'Facebook',
                brandColor: const Color(0xFF1877F2),
                isDark: isDark,
                onTap: () {
                  Navigator.of(context).pop();
                  AppLauncher.facebook(context, facebook);
                },
              ),

            if (linkedin != null && linkedin!.isNotEmpty)
              _ActionTile(
                icon: Icons.business_center,
                label: 'LinkedIn',
                brandColor: const Color(0xFF0A66C2),
                isDark: isDark,
                onTap: () {
                  Navigator.of(context).pop();
                  AppLauncher.linkedin(context, linkedin);
                },
              ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Single action row inside the bottom sheet — label only, no raw URL
// or phone number shown.
// ─────────────────────────────────────────────────────────────────────
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color brandColor;
  final bool isDark;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.brandColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Theme-aware brand colour: lighten on dark theme so the icon stays
    // legible against the dark sheet surface.
    final Color visibleBrand;
    if (isDark) {
      final hsl = HSLColor.fromColor(brandColor);
      final lifted = (hsl.lightness + 0.30).clamp(0.55, 0.85);
      visibleBrand = hsl.withLightness(lifted).toColor();
    } else {
      visibleBrand = brandColor;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              children: [
                // Icon bubble
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: visibleBrand.withValues(alpha: isDark ? 0.22 : 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          visibleBrand.withValues(alpha: isDark ? 0.45 : 0.25),
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: visibleBrand, size: 22),
                ),
                const SizedBox(width: 14),

                // Label only — no subtitle
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color:
                      theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
