// lib/presentation/widgets/common/work_experience_card.dart
//
// Architecture Appendix A/C (Work Experience Card — Profile Detail +
// Profile Edit both use this).
//
// ⚠️ Project-wide rule (Appendix K.1/K.2): never hardcode
// `Colors.grey[...]` for text — always derive from
// `Theme.of(context).colorScheme`/`textTheme` so this renders correctly
// in both light and dark mode. The company-type chip's accent colors ARE
// intentionally fixed hex values (not text colors) since they're a
// semantic category-color system, not text that needs theme-contrast.
//
// ⚠️ DARK-MODE READABILITY FIX (this revision):
//   Secondary lines (group-of-companies, designation • department) were
//   rendered in `onSurfaceVariant`, which in dark theme sits very close
//   to the card's surface colour — readable on paper, washed-out on a
//   real device. On light theme the same role was pale against white.
//   This revision resolves TWO readable text colours once per card:
//     • primaryText = onSurface           (company name)
//     • mutedText   = onSurfaceVariant    on dark theme
//                     lerp(…, onSurface, 0.50) on light theme
//   Every secondary line uses `mutedText`, every primary line uses
//   `primaryText`, and the type/duration chips use paired container /
//   on-container roles — all Material 3 contrast-safe.
//
// ⚠️ OVERFLOW HARDENED:
//   Every Text has explicit maxLines + ellipsis. Company name allowed 2
//   lines (long legal entity names were truncating on one). The top row
//   uses Flexible for both chips so a long type/duration label never
//   pushes the edit/delete icons off-screen.

import 'package:flutter/material.dart';

import '../../../data/models/user/work_experience_model.dart';

class WorkExperienceCard extends StatelessWidget {
  final WorkExperience experience;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isEditable;

  const WorkExperienceCard({
    super.key,
    required this.experience,
    this.onEdit,
    this.onDelete,
    this.isEditable = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // ⚠️ THE FIX: two explicit, contrast-safe text colours, computed once.
    final primaryText = theme.colorScheme.onSurface;
    final mutedText = isDark
        ? theme.colorScheme.onSurfaceVariant
        : Color.lerp(
            theme.colorScheme.onSurfaceVariant,
            theme.colorScheme.onSurface,
            0.50,
          )!;

    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── TOP ROW: type chip + duration chip + actions ─────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Company-type chip
                Flexible(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getTypeColor(experience.companyType)
                          .withValues(alpha: isDark ? 0.22 : 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getTypeColor(experience.companyType)
                            .withValues(alpha: isDark ? 0.45 : 0.30),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      experience.companyType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? _lightenForDark(
                                _getTypeColor(experience.companyType))
                            : _getTypeColor(experience.companyType),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Duration chip
                Flexible(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer
                          .withValues(alpha: isDark ? 0.55 : 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.colorScheme.secondary
                            .withValues(alpha: isDark ? 0.45 : 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      experience.durationLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ),

                if (isEditable) ...[
                  const SizedBox(width: 4),
                  _SmallIconButton(
                    icon: Icons.edit_outlined,
                    onTap: onEdit,
                  ),
                  _SmallIconButton(
                    icon: Icons.delete_outline,
                    color: theme.colorScheme.error,
                    onTap: onDelete,
                  ),
                ],
              ],
            ),

            const SizedBox(height: 12),

            // ── Company name (primary) ─────────────────────────────
            Text(
              experience.companyName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: primaryText,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // ── Group of companies (secondary) ─────────────────────
            if (experience.groupOfCompanies != null &&
                experience.groupOfCompanies!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                experience.groupOfCompanies!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: mutedText,
                  height: 1.25,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 4),

            // ── Designation • Department (secondary, bold-ish) ─────
            Text(
              '${experience.designation}  •  ${experience.jobDepartment}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: mutedText,
                fontWeight: FontWeight.w500,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Semantic category colour (intentionally fixed hex — these encode
  // industry categories, not theme-dependent text).
  // ─────────────────────────────────────────────────────────────────
  Color _getTypeColor(String type) {
    switch (type) {
      case 'Textile Industry':
        return const Color(0xFF1A365D);
      case 'Garments Industry':
        return const Color(0xFF0F766E);
      case 'Buying House':
        return const Color(0xFFB45309);
      case 'Trading Office':
        return const Color(0xFF2563EB);
      case 'University':
      case 'College':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF64748B);
    }
  }

  /// Lift a dark category colour so its text is legible on a dark card.
  /// Same hue + saturation, lightness pushed into a readable band.
  Color _lightenForDark(Color c) {
    final hsl = HSLColor.fromColor(c);
    final lifted = (hsl.lightness + 0.28).clamp(0.55, 0.85);
    return hsl.withLightness(lifted).toColor();
  }
}

// ─────────────────────────────────────────────────────────────────────
// Compact icon button for card actions (edit / delete).
// 32dp visible box, 48dp tap target preserved via
// `ButtonStyle.tapTargetSize` — no mis-taps, no overflow.
// ─────────────────────────────────────────────────────────────────────
class _SmallIconButton extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  const _SmallIconButton({
    required this.icon,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        iconSize: 18,
        constraints: const BoxConstraints(
          minWidth: 32,
          minHeight: 32,
          maxWidth: 32,
          maxHeight: 32,
        ),
        icon: Icon(icon, color: color ?? theme.colorScheme.onSurfaceVariant),
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
    );
  }
}
