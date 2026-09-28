// lib/presentation/widgets/common/alumni_directory_card.dart
//
// Architecture Appendix D (Directory Card) + Appendix L.1.5 (Total Work
// Experience badge alongside Blood Group).
//
// ⚠️ BATCH DUPLICATION FIX:
//   A local `_normaliseBatch()` helper is used for every batch display so
//   "7th", "7th Batch", and "7th batch" all render as "7th Batch" exactly
//   once. This file defines its own copy of the helper (rather than
//   importing from home_screen.dart) so the widget stays self-contained
//   and doesn't create a circular import.

import 'package:flutter/material.dart';

import '../../../core/utils/career_status_categories.dart';
import '../../../core/utils/departments_helper.dart';
import '../../../data/models/user/user_public_model.dart';
import '../../../data/models/user/work_experience_model.dart';
import 'blood_group_badge.dart';
import 'contact_action_buttons.dart';
import 'drive_image.dart';

// Idempotent "Batch" suffix helper.
//   "7th Batch" → "7th Batch"
//   "7th"       → "7th Batch"
//   "7th batch" → "7th batch"
String _normaliseBatch(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.toLowerCase().endsWith('batch')) return trimmed;
  return '$trimmed Batch';
}

class AlumniDirectoryCard extends StatelessWidget {
  final UserPublicModel alumni;
  final VoidCallback? onTap;

  const AlumniDirectoryCard({super.key, required this.alumni, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final mutedColor = isDark
        ? theme.colorScheme.onSurfaceVariant
        : Color.lerp(
            theme.colorScheme.onSurfaceVariant,
            theme.colorScheme.onSurface,
            0.55,
          )!;

    final deptLabel = Departments.getShortLabel(alumni.department);
    final batchLabel = _normaliseBatch(alumni.batch ?? '');
    final infoLine = [
      if (deptLabel.isNotEmpty) deptLabel,
      if (batchLabel.isNotEmpty) batchLabel,
    ].join('  •  ');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 0.5,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── HEADER ROW: avatar + name + chip + Contact pill ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Avatar(
                    name: alumni.fullName,
                    photoUrl: alumni.photoUrl,
                    theme: theme,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          alumni.fullName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (alumni.careerStatus.isNotEmpty)
                          _CareerStatusChip(status: alumni.careerStatus),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  ContactActionButtons(
                    contactName: alumni.fullName,
                    phone: alumni.phone,
                    whatsapp: alumni.whatsapp,
                    facebook: alumni.facebook,
                    linkedin: alumni.linkedin,
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ── BADGES ─────────────────────────────────────────
              if (_hasAnyBadge(alumni)) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (alumni.bloodGroup != null &&
                        alumni.bloodGroup!.isNotEmpty)
                      BloodGroupBadge(bloodGroup: alumni.bloodGroup!),
                    if (alumni.workExperience.isNotEmpty)
                      _WorkExperienceBadge(experiences: alumni.workExperience),
                  ],
                ),
                const SizedBox(height: 10),
              ],

              // ── INFO ROWS ──────────────────────────────────────
              _InfoRow(
                icon: Icons.engineering_outlined,
                text: infoLine,
                color: mutedColor,
                weight: FontWeight.w600,
              ),

              if (alumni.company != null && alumni.company!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: _InfoRow(
                    icon: Icons.work_outline,
                    text: '${alumni.designation ?? ''} at ${alumni.company}'
                        '${alumni.companyType != null ? '  •  ${alumni.companyType}' : ''}',
                    color: mutedColor,
                  ),
                ),

              if (alumni.district != null && alumni.district!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: _InfoRow(
                    icon: Icons.location_on_outlined,
                    text: alumni.district!,
                    color: mutedColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool _hasAnyBadge(UserPublicModel a) {
    final hasBlood = a.bloodGroup != null && a.bloodGroup!.isNotEmpty;
    final hasExp = a.workExperience.isNotEmpty;
    return hasBlood || hasExp;
  }
}

// ─────────────────────────────────────────────────────────────────────
// Info row
// ─────────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final FontWeight? weight;

  const _InfoRow({
    required this.icon,
    required this.text,
    required this.color,
    this.weight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              height: 1.25,
              fontWeight: weight ?? FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Avatar — real Drive photo when available, initials fallback otherwise
// ─────────────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final ThemeData theme;

  const _Avatar({
    required this.name,
    required this.theme,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.trim().isNotEmpty;

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.primaryContainer,
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: hasPhoto
            ? DriveImage(
                fileId: photoUrl!,
                width: 52,
                height: 52,
              )
            : _InitialFallback(name: name, theme: theme),
      ),
    );
  }
}

class _InitialFallback extends StatelessWidget {
  final String name;
  final ThemeData theme;

  const _InitialFallback({required this.name, required this.theme});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    return Container(
      color: theme.colorScheme.primaryContainer,
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            initial,
            style: TextStyle(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Work-experience badge
// ─────────────────────────────────────────────────────────────────────
class _WorkExperienceBadge extends StatelessWidget {
  final List<WorkExperience> experiences;

  const _WorkExperienceBadge({required this.experiences});

  @override
  Widget build(BuildContext context) {
    if (experiences.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timelapse,
            size: 12,
            color: theme.colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            WorkExperienceCalculator.totalExperienceLabel(experiences),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onTertiaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Career status chip — light/dark safe (HSL contrast adjustment)
// ─────────────────────────────────────────────────────────────────────
class _CareerStatusChip extends StatelessWidget {
  final String status;

  const _CareerStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = CareerStatusCategories.getColor(status);
    final isDark = theme.brightness == Brightness.dark;

    final hsl = HSLColor.fromColor(brand);
    final readableBrand = isDark
        ? hsl.withLightness((hsl.lightness + 0.25).clamp(0.0, 1.0)).toColor()
        : hsl.withLightness((hsl.lightness - 0.20).clamp(0.0, 1.0)).toColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: brand.withValues(alpha: isDark ? 0.20 : 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: readableBrand.withValues(alpha: isDark ? 0.45 : 0.35),
          width: 0.8,
        ),
      ),
      child: Text(
        CareerStatusCategories.getDisplayLabel(status),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: readableBrand,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
