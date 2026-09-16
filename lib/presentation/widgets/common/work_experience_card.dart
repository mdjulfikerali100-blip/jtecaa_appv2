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

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getTypeColor(experience.companyType)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    experience.companyType,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _getTypeColor(experience.companyType),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    experience.durationLabel,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.primary),
                  ),
                ),
                if (isEditable) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: onEdit,
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        size: 18, color: theme.colorScheme.error),
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              experience.companyName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (experience.groupOfCompanies != null &&
                experience.groupOfCompanies!.isNotEmpty)
              Text(
                experience.groupOfCompanies!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Text(
              '${experience.designation}  •  ${experience.jobDepartment}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

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
}
