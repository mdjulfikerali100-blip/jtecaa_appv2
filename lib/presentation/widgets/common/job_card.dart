// lib/presentation/widgets/common/job_card.dart
//
// Master Prompt Phase 7 + Architecture §7.5/Appendix F.7.7.
//
// ⚠️ "Company Logo (48px, placeholder if none)" — there is no logo field
// anywhere in the Jobs Sheet schema (Appendix I.3) or JobPostModel, so
// this is ALWAYS the placeholder (a colored circle with the company's
// first letter) — there is no real-logo code path to fall back from.
//
// Apply-method chips here are informational only (non-interactive) — the
// actual clickable apply actions live in JobDetailBottomSheet, opened by
// tapping the card, matching Architecture §7.7's "detail shown via a
// bottom sheet triggered by tapping a card" design (no per-item route).

import 'package:flutter/material.dart';

import '../../../data/models/job/job_post_model.dart';
import 'posted_by_label.dart';

class JobCard extends StatelessWidget {
  final JobPostModel job;
  final bool isOwner;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const JobCard({
    super.key,
    required this.job,
    this.isOwner = false,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deadline = DateTime.tryParse(job.deadline);
    final daysLeft = deadline?.difference(DateTime.now()).inDays;
    final isUrgent = daysLeft != null && daysLeft <= 3;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      job.company.isNotEmpty
                          ? job.company[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.title,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          job.company,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Chip(
                              label: Text(
                                job.isExpired
                                    ? 'Expired'
                                    : 'Deadline: ${job.deadline}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              backgroundColor: (isUrgent || job.isExpired)
                                  ? theme.colorScheme.errorContainer
                                  : theme.colorScheme.secondaryContainer,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (job.applyLink != null && job.applyLink!.isNotEmpty)
                    _applyChip(theme, 'Link'),
                  if (job.applyEmail != null && job.applyEmail!.isNotEmpty)
                    _applyChip(theme, 'Email'),
                  if (job.applyPhone != null && job.applyPhone!.isNotEmpty)
                    _applyChip(theme, 'Phone'),
                  if (job.applyWhatsapp != null &&
                      job.applyWhatsapp!.isNotEmpty)
                    _applyChip(theme, 'WhatsApp'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child: PostedByLabel(
                          name: job.postedByName, batch: job.postedByBatch)),
                  if (isOwner) ...[
                    TextButton(onPressed: onEdit, child: const Text('Edit')),
                    TextButton(
                      onPressed: onDelete,
                      child: Text('Delete',
                          style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _applyChip(ThemeData theme, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Apply via $label',
        style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.secondary,
            fontWeight: FontWeight.w500),
      ),
    );
  }
}
