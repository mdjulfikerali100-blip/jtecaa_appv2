// lib/presentation/widgets/common/job_detail_bottom_sheet.dart
//
// Architecture §7.7: "individual jobs/news don't have their own route —
// they only open as a bottom sheet from a list-item tap." This IS the
// job detail screen, by design — not a placeholder for a future route.

import 'package:flutter/material.dart';

import '../../../core/utils/app_launcher.dart';
import '../../../data/models/job/job_post_model.dart';
import 'posted_by_label.dart';

class JobDetailBottomSheet extends StatelessWidget {
  final JobPostModel job;

  const JobDetailBottomSheet({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // Deadline helpers — purely visual, no logic change.
    final deadline = DateTime.tryParse(job.deadline);
    final daysLeft = deadline?.difference(DateTime.now()).inDays;
    final isUrgent = daysLeft != null && daysLeft >= 0 && daysLeft <= 3;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // ── Grab handle (not part of scroll) ────────────────
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Scrollable content ──────────────────────────────
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                  children: [
                    // ── Company badge + title + company ─────────────
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
                                style: textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.onSurface,
                                  height: 1.2,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                job.company,
                                style: textTheme.titleMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Status strip: deadline + posted-by ──────────
                    _InfoRow(
                      icon: Icons.event_outlined,
                      color: job.isExpired
                          ? colorScheme.error
                          : (isUrgent
                              ? colorScheme.error
                              : colorScheme.onSurfaceVariant),
                      label: job.isExpired
                          ? 'Deadline passed'
                          : (deadline != null
                              ? 'Deadline · ${_formatDeadline(deadline)}'
                              : 'Deadline TBA'),
                      badge: isUrgent && !job.isExpired
                          ? (daysLeft == 0
                              ? 'Due today'
                              : '$daysLeft ${daysLeft == 1 ? "day" : "days"} left')
                          : null,
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    ),
                    const SizedBox(height: 10),
                    PostedByLabel(
                      name: job.postedByName,
                      batch: job.postedByBatch,
                    ),
                    const SizedBox(height: 24),

                    // ── Description ─────────────────────────────────
                    if (job.description != null &&
                        job.description!.isNotEmpty) ...[
                      _SectionLabel(
                        icon: Icons.description_outlined,
                        label: 'Description',
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        job.description!,
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurface,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],

                    // ── Apply section ───────────────────────────────
                    _SectionLabel(
                      icon: Icons.send_outlined,
                      label: 'Apply',
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    ),
                    const SizedBox(height: 12),

                    if (!job.hasApplyMethod)
                      _EmptyApplyNote(
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      )
                    else
                      _ApplyGrid(
                        job: job,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Formats a DateTime as `15 Oct 2026`.
  static String _formatDeadline(DateTime d) {
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
// Presentational helpers (no business logic).
// ─────────────────────────────────────────────────────────────────────────

/// Company avatar — gradient rounded square with the first letter.
/// Matches the design used on JobCard.
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
      width: 56,
      height: 56,
      decoration: BoxDecoration(
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
        borderRadius: BorderRadius.circular(16),
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
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

/// Compact icon + label row used for deadline information.
/// Optional `badge` shows a small pill on the right (e.g. "3 days left").
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.colorScheme,
    required this.textTheme,
    this.badge,
  });

  final IconData icon;
  final Color color;
  final String label;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badge!,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

/// Section heading with an inline icon, so Description and Apply read
/// as distinct blocks at a glance.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.colorScheme,
    required this.textTheme,
  });

  final IconData icon;
  final String label;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 13, color: colorScheme.onPrimaryContainer),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            style: textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Fallback card for the rare case where a job has no apply method.
class _EmptyApplyNote extends StatelessWidget {
  const _EmptyApplyNote({
    required this.colorScheme,
    required this.textTheme,
  });

  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No apply method was provided for this post.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Responsive grid of apply buttons. Uses Wrap so buttons flow onto a
/// second line on narrow screens and never overflow.
class _ApplyGrid extends StatelessWidget {
  const _ApplyGrid({
    required this.job,
    required this.colorScheme,
    required this.textTheme,
  });

  final JobPostModel job;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      if (job.applyLink != null && job.applyLink!.isNotEmpty)
        _ApplyButton(
          icon: Icons.open_in_new_rounded,
          label: 'Apply via Link',
          onTap: () => AppLauncher.open(context, job.applyLink),
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
      if (job.applyEmail != null && job.applyEmail!.isNotEmpty)
        _ApplyButton(
          icon: Icons.email_outlined,
          label: 'Apply via Email',
          onTap: () => AppLauncher.open(
            context,
            Uri(scheme: 'mailto', path: job.applyEmail).toString(),
            failureMessage: 'Could not open your email app.',
          ),
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
      if (job.applyPhone != null && job.applyPhone!.isNotEmpty)
        _ApplyButton(
          icon: Icons.call_outlined,
          label: 'Apply via Phone',
          onTap: () => AppLauncher.call(context, job.applyPhone),
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
      if (job.applyWhatsapp != null && job.applyWhatsapp!.isNotEmpty)
        _ApplyButton(
          icon: Icons.chat_outlined,
          label: 'Apply via WhatsApp',
          onTap: () => AppLauncher.whatsapp(context, job.applyWhatsapp),
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: buttons,
    );
  }
}

/// Outlined apply button with icon + label. Taller tap target (44dp)
/// than the original, so it's thumb-friendly on real devices.
class _ApplyButton extends StatelessWidget {
  const _ApplyButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.colorScheme,
    required this.textTheme,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        side: BorderSide(
          color: colorScheme.outline,
          width: 1.2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        foregroundColor: colorScheme.onSurface,
      ),
    );
  }
}
