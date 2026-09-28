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
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final deadline = DateTime.tryParse(job.deadline);
    final daysLeft = deadline?.difference(DateTime.now()).inDays;
    final isUrgent = daysLeft != null && daysLeft >= 0 && daysLeft <= 3;
    final isExpired = job.isExpired;

    // Status config — single source of truth for the deadline chip.
    final _DeadlineStatus status;
    if (isExpired) {
      status = _DeadlineStatus(
        label: 'Expired',
        icon: Icons.event_busy_outlined,
        bg: colorScheme.errorContainer,
        fg: colorScheme.onErrorContainer,
      );
    } else if (isUrgent) {
      status = _DeadlineStatus(
        label: deadline != null && daysLeft != null
            ? (daysLeft == 0
                ? 'Due today'
                : '$daysLeft ${daysLeft == 1 ? "day" : "days"} left')
            : 'Urgent',
        icon: Icons.access_time_rounded,
        bg: colorScheme.errorContainer,
        fg: colorScheme.onErrorContainer,
      );
    } else {
      status = _DeadlineStatus(
        label: _formatDeadline(deadline),
        icon: Icons.event_available_outlined,
        bg: colorScheme.secondaryContainer,
        fg: colorScheme.onSecondaryContainer,
      );
    }

    // Collect apply methods for compact display.
    final applyMethods = <_ApplyMethod>[
      if (job.applyLink != null && job.applyLink!.isNotEmpty)
        const _ApplyMethod(
          label: 'Link',
          icon: Icons.link_rounded,
        ),
      if (job.applyEmail != null && job.applyEmail!.isNotEmpty)
        const _ApplyMethod(
          label: 'Email',
          icon: Icons.email_outlined,
        ),
      if (job.applyPhone != null && job.applyPhone!.isNotEmpty)
        const _ApplyMethod(
          label: 'Phone',
          icon: Icons.phone_outlined,
        ),
      if (job.applyWhatsapp != null && job.applyWhatsapp!.isNotEmpty)
        const _ApplyMethod(
          label: 'WhatsApp',
          icon: Icons.chat_outlined,
        ),
    ];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      // Subtle elevated look with border — modern Material 3.
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: logo + title + company + deadline chip ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CompanyAvatar(
                    company: job.company,
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.title,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          job.company,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        // Deadline / status pill
                        _StatusPill(status: status),
                      ],
                    ),
                  ),
                ],
              ),

              // ── Apply methods row ──────────────────────────────
              if (applyMethods.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(
                      Icons.send_outlined,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Apply via',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: applyMethods
                            .map((m) => _ApplyChip(
                                  method: m,
                                  colorScheme: colorScheme,
                                  textTheme: textTheme,
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),

              // ── Footer: posted by + owner actions ──────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: PostedByLabel(
                        name: job.postedByName,
                        batch: job.postedByBatch,
                      ),
                    ),
                    if (isOwner) ...[
                      const SizedBox(width: 8),
                      _OwnerActionButton(
                        icon: Icons.edit_outlined,
                        label: 'Edit',
                        color: colorScheme.primary,
                        onPressed: onEdit,
                      ),
                      const SizedBox(width: 4),
                      _OwnerActionButton(
                        icon: Icons.delete_outline_rounded,
                        label: 'Delete',
                        color: colorScheme.error,
                        onPressed: onDelete,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Formats a DateTime as a compact human-readable date.
  /// Example: `15 Oct 2026`.
  static String _formatDeadline(DateTime? d) {
    if (d == null) return 'Deadline TBA';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Private presentational helpers (no business logic).
// ─────────────────────────────────────────────────────────────────────────

class _DeadlineStatus {
  const _DeadlineStatus({
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
  });
  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;
}

class _ApplyMethod {
  const _ApplyMethod({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

/// Company avatar — falls back to the first letter when there is no logo,
/// matching the Architecture spec (§ Appendix F.7.7 has no logo field).
class _CompanyAvatar extends StatelessWidget {
  const _CompanyAvatar({
    required this.company,
    required this.colorScheme,
    required this.textTheme,
  });

  final String company;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final initial = company.isNotEmpty ? company[0].toUpperCase() : '?';

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        // Soft gradient for a bit of depth — reads well in both modes.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer,
            Color.lerp(
                  colorScheme.primaryContainer,
                  colorScheme.primary,
                  0.18,
                ) ??
                colorScheme.primaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.12),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: textTheme.titleLarge?.copyWith(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
    );
  }
}

/// Compact status pill for deadline / urgent / expired states.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final _DeadlineStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status.bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 13, color: status.fg),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              status.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: status.fg,
                letterSpacing: 0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small "Apply via X" chip with icon — replaces the flat text container.
class _ApplyChip extends StatelessWidget {
  const _ApplyChip({
    required this.method,
    required this.colorScheme,
    required this.textTheme,
  });

  final _ApplyMethod method;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.secondary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            method.icon,
            size: 13,
            color: colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 5),
          Text(
            method.label,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Owner action button — icon + label, colored by intent.
/// Tap target ≥ 40dp height keeps it usable without dominating the row.
class _OwnerActionButton extends StatelessWidget {
  const _OwnerActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: TextButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
