// lib/presentation/widgets/common/alumni_directory_card.dart
//
// Architecture Appendix D (Directory Card) + Appendix L.1.5 (Total Work
// Experience badge alongside Blood Group).

import 'package:flutter/material.dart';

import '../../../core/utils/career_status_categories.dart';
import '../../../core/utils/departments_helper.dart';
import '../../../data/models/user/user_public_model.dart';
import '../../../data/models/user/work_experience_model.dart';
import 'blood_group_badge.dart';
import 'contact_action_buttons.dart';

class AlumniDirectoryCard extends StatelessWidget {
  final UserPublicModel alumni;
  final VoidCallback? onTap;

  const AlumniDirectoryCard({super.key, required this.alumni, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ⚠️ `alumni.photoUrl` is a Google Drive fileId, not a
              // browsable URL (Architecture §5.4) — real photo rendering
              // needs DriveImageService/DriveImage (Appendix J), which
              // arrives in Phase 6. Initials avatar keeps this card fully
              // functional today without a broken network-image attempt.
              CircleAvatar(
                radius: 28,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  alumni.fullName.isNotEmpty ? alumni.fullName[0] : '?',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alumni.fullName,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Appendix L.1.5: Blood Group + Total Work Experience
                    // badges together, wrapped (not a bare Row) so a long
                    // experience label never right-overflows.
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (alumni.bloodGroup != null &&
                            alumni.bloodGroup!.isNotEmpty)
                          BloodGroupBadge(bloodGroup: alumni.bloodGroup!),
                        _WorkExperienceBadge(
                            experiences: alumni.workExperience),
                        if (alumni.careerStatus.isNotEmpty)
                          _CareerStatusChip(status: alumni.careerStatus),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${Departments.getShortLabel(alumni.department)} • ${alumni.batch ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    if (alumni.company != null && alumni.company!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '${alumni.designation ?? ''} at ${alumni.company}'
                          '${alumni.companyType != null ? ' (${alumni.companyType})' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    if (alumni.district != null && alumni.district!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          alumni.district!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ),
              ContactActionButtons(
                phone: alumni.phone,
                whatsapp: alumni.whatsapp,
                facebook: alumni.facebook,
                linkedin: alumni.linkedin,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        WorkExperienceCalculator.totalExperienceLabel(experiences),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onTertiaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CareerStatusChip extends StatelessWidget {
  final String status;

  const _CareerStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = CareerStatusCategories.getColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        CareerStatusCategories.getDisplayLabel(status),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
