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

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: theme.colorScheme.outline,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Text(job.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                job.company,
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.event_outlined,
                      size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    job.isExpired
                        ? 'Deadline passed'
                        : 'Deadline: ${job.deadline}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: job.isExpired
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              PostedByLabel(name: job.postedByName, batch: job.postedByBatch),
              const SizedBox(height: 20),
              if (job.description != null && job.description!.isNotEmpty) ...[
                Text('Description', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Text(job.description!, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 24),
              ],
              Text('Apply', style: theme.textTheme.titleSmall),
              const SizedBox(height: 12),
              if (!job.hasApplyMethod)
                Text(
                  'No apply method was provided for this post.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (job.applyLink != null && job.applyLink!.isNotEmpty)
                      _ApplyButton(
                        icon: Icons.open_in_new,
                        label: 'Apply via Link',
                        onTap: () => AppLauncher.open(context, job.applyLink),
                      ),
                    if (job.applyEmail != null && job.applyEmail!.isNotEmpty)
                      _ApplyButton(
                        icon: Icons.email_outlined,
                        label: 'Apply via Email',
                        onTap: () => AppLauncher.open(
                          context,
                          Uri(scheme: 'mailto', path: job.applyEmail)
                              .toString(),
                          failureMessage: 'Could not open your email app.',
                        ),
                      ),
                    if (job.applyPhone != null && job.applyPhone!.isNotEmpty)
                      _ApplyButton(
                        icon: Icons.call,
                        label: 'Apply via Phone',
                        onTap: () => AppLauncher.call(context, job.applyPhone),
                      ),
                    if (job.applyWhatsapp != null &&
                        job.applyWhatsapp!.isNotEmpty)
                      _ApplyButton(
                        icon: Icons.chat,
                        label: 'Apply via WhatsApp',
                        onTap: () =>
                            AppLauncher.whatsapp(context, job.applyWhatsapp),
                      ),
                  ],
                ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _ApplyButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ApplyButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
