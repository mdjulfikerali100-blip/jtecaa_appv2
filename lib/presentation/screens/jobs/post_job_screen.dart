// lib/presentation/screens/jobs/post_job_screen.dart
//
// Architecture §7.5 (Post Job Form) — Title, Company, Description,
// Deadline, and 4 apply methods with "minimum 1 required" validation.
// Doubles as the Edit form when [existingJob] is passed in.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/job/job_post_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/jobs_provider.dart';

class PostJobScreen extends ConsumerStatefulWidget {
  final JobPostModel? existingJob;

  const PostJobScreen({super.key, this.existingJob});

  @override
  ConsumerState<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends ConsumerState<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _companyController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _linkController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();

  DateTime? _deadline;
  bool _isSubmitting = false;

  bool get _isEditing => widget.existingJob != null;

  @override
  void initState() {
    super.initState();
    final job = widget.existingJob;
    if (job != null) {
      _titleController.text = job.title;
      _companyController.text = job.company;
      _descriptionController.text = job.description ?? '';
      _linkController.text = job.applyLink ?? '';
      _emailController.text = job.applyEmail ?? '';
      _phoneController.text = job.applyPhone ?? '';
      _whatsappController.text = job.applyWhatsapp ?? '';
      _deadline = DateTime.tryParse(job.deadline);
    }

    // Keep the apply-method section live so the "at least one" hint can
    // update visually as the user types (no logic impact).
    for (final c in [
      _linkController,
      _emailController,
      _phoneController,
      _whatsappController,
    ]) {
      c.addListener(_onApplyMethodChanged);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _companyController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  /// Visual-only: triggers a rebuild so the apply-method hint chip can
  /// reflect whether at least one method has been entered.
  void _onApplyMethodChanged() {
    if (mounted) setState(() {});
  }

  bool get _hasAnyApplyMethod =>
      _linkController.text.trim().isNotEmpty ||
      _emailController.text.trim().isNotEmpty ||
      _phoneController.text.trim().isNotEmpty ||
      _whatsappController.text.trim().isNotEmpty;

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 14)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_deadline == null) {
      _showError('Please select a deadline');
      return;
    }
    if (!_hasAnyApplyMethod) {
      _showError(
          'At least one apply method (Link, Email, Phone, or WhatsApp) is required');
      return;
    }

    setState(() => _isSubmitting = true);
    final deadlineStr =
        '${_deadline!.year}-${_deadline!.month.toString().padLeft(2, '0')}-${_deadline!.day.toString().padLeft(2, '0')}';

    try {
      if (_isEditing) {
        final body = JobPostModel.toEditBody(
          id: widget.existingJob!.id,
          title: _titleController.text.trim(),
          company: _companyController.text.trim(),
          description: _descriptionController.text.trim(),
          deadline: deadlineStr,
          applyLink: _linkController.text.trim().isEmpty
              ? null
              : _linkController.text.trim(),
          applyEmail: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          applyPhone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          applyWhatsapp: _whatsappController.text.trim().isEmpty
              ? null
              : _whatsappController.text.trim(),
        );
        await ref.read(jobRepositoryProvider).editJob(body);
      } else {
        final uid = ref.read(currentUidProvider);
        if (uid == null) {
          throw StateError('Not signed in.');
        }
        // Appendix L.2.1 "client computes, server just stores" — pull
        // the poster's name/batch from their own cache-first profile
        // read rather than a fresh Firestore query.
        final myProfile =
            await ref.read(userRepositoryProvider).getMyProfile(uid);
        final body = JobPostModel.toPostBody(
          title: _titleController.text.trim(),
          company: _companyController.text.trim(),
          description: _descriptionController.text.trim(),
          deadline: deadlineStr,
          applyLink: _linkController.text.trim().isEmpty
              ? null
              : _linkController.text.trim(),
          applyEmail: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          applyPhone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          applyWhatsapp: _whatsappController.text.trim().isEmpty
              ? null
              : _whatsappController.text.trim(),
          postedByUid: uid,
          postedByName: myProfile.fullName,
          postedByBatch: myProfile.batch,
        );
        await ref.read(jobRepositoryProvider).postJob(body);
      }

      ref.invalidate(activeJobsProvider);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showError('Could not save: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showError(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: colorScheme.errorContainer,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Job' : 'Post a Job',
          style: theme.textTheme.titleLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        iconTheme: IconThemeData(
          color: colorScheme.onSurface,
          size: 24,
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxContentWidth =
                  constraints.maxWidth > 640 ? 560.0 : constraints.maxWidth;
              final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

              return Center(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    constraints.maxWidth > 640 ? 32 : 20,
                    20,
                    constraints.maxWidth > 640 ? 32 : 20,
                    32 + bottomInset,
                  ),
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxContentWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Section: Job Basics ────────────────────
                          _SectionHeader(
                            icon: Icons.work_outline_rounded,
                            label: 'Job Basics',
                            textTheme: theme.textTheme,
                            colorScheme: colorScheme,
                          ),
                          const SizedBox(height: 14),

                          TextFormField(
                            controller: _titleController,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Job Title',
                              hintText: 'e.g. Production Officer',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _companyController,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Company',
                              hintText: 'e.g. SQ Hues Ltd.',
                              prefixIcon: Icon(Icons.business_outlined),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _descriptionController,
                            textInputAction: TextInputAction.newline,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              hintText: 'Role, responsibilities, requirements…',
                              alignLabelWithHint: true,
                            ),
                            maxLines: 5,
                            minLines: 3,
                          ),
                          const SizedBox(height: 20),

                          // ── Section: Deadline ──────────────────────
                          _SectionHeader(
                            icon: Icons.event_outlined,
                            label: 'Deadline',
                            textTheme: theme.textTheme,
                            colorScheme: colorScheme,
                          ),
                          const SizedBox(height: 14),

                          _DeadlineTile(
                            deadline: _deadline,
                            onTap: _pickDeadline,
                            formatDeadline: _formatDeadline,
                            colorScheme: colorScheme,
                            textTheme: theme.textTheme,
                          ),
                          const SizedBox(height: 24),

                          // ── Section: Apply Methods ─────────────────
                          _SectionHeader(
                            icon: Icons.send_outlined,
                            label: 'Apply Methods',
                            trailing: _hasAnyApplyMethod
                                ? _MiniChip(
                                    label: 'Ready',
                                    icon: Icons.check_circle_outline,
                                    bg: colorScheme.secondaryContainer,
                                    fg: colorScheme.onSecondaryContainer,
                                  )
                                : _MiniChip(
                                    label: 'At least 1 required',
                                    icon: Icons.info_outline,
                                    bg: colorScheme.errorContainer
                                        .withValues(alpha: 0.6),
                                    fg: colorScheme.onErrorContainer,
                                  ),
                            textTheme: theme.textTheme,
                            colorScheme: colorScheme,
                          ),
                          const SizedBox(height: 14),

                          TextFormField(
                            controller: _linkController,
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: const InputDecoration(
                              labelText: 'Apply Link',
                              hintText: 'https://example.com/apply',
                              prefixIcon: Icon(Icons.link_rounded),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: const InputDecoration(
                              labelText: 'Apply Email',
                              hintText: 'hr@company.com',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Apply Phone',
                              hintText: '0171XXXXXXX',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _whatsappController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Apply WhatsApp',
                              hintText: '0171XXXXXXX',
                              prefixIcon: Icon(Icons.chat_outlined),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // ── Submit ─────────────────────────────────
                          _SubmitButton(
                            isSubmitting: _isSubmitting,
                            label: _isEditing ? 'UPDATE JOB' : 'POST JOB',
                            onPressed: _submit,
                            colorScheme: colorScheme,
                            textTheme: theme.textTheme,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _isEditing
                                ? 'Changes go live immediately for all viewers.'
                                : 'Once posted, alumni can see this job on '
                                    'the Job Board right away.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Presentational helpers (no business logic).
// ─────────────────────────────────────────────────────────────────────────

/// Section header: icon chip + label + optional trailing mini chip.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.textTheme,
    required this.colorScheme,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final TextTheme textTheme;
  final ColorScheme colorScheme;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: colorScheme.onPrimaryContainer),
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
        const SizedBox(width: 12),
        if (trailing != null)
          trailing!
        else
          Expanded(
            child: Container(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
      ],
    );
  }
}

/// Small status chip used in section headers (e.g. "Ready", "At least 1").
class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
  });

  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: fg,
                letterSpacing: 0.2,
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

/// Tappable deadline tile — behaves like a form field but opens a picker.
class _DeadlineTile extends StatelessWidget {
  const _DeadlineTile({
    required this.deadline,
    required this.onTap,
    required this.formatDeadline,
    required this.colorScheme,
    required this.textTheme,
  });

  final DateTime? deadline;
  final VoidCallback onTap;
  final String Function(DateTime) formatDeadline;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final hasValue = deadline != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasValue
                ? colorScheme.primary.withValues(alpha: 0.5)
                : colorScheme.outlineVariant,
            width: hasValue ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 20,
              color:
                  hasValue ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deadline',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasValue ? formatDeadline(deadline!) : 'Not set',
                    style: textTheme.titleMedium?.copyWith(
                      color: hasValue
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                      fontWeight: hasValue ? FontWeight.w700 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Elevated submit button with a press-scale micro-interaction.
class _SubmitButton extends StatefulWidget {
  const _SubmitButton({
    required this.isSubmitting,
    required this.label,
    required this.onPressed,
    required this.colorScheme,
    required this.textTheme,
  });

  final bool isSubmitting;
  final String label;
  final VoidCallback onPressed;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  State<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<_SubmitButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: widget.isSubmitting ? null : widget.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.colorScheme.primary,
              foregroundColor: widget.colorScheme.onPrimary,
              disabledBackgroundColor:
                  widget.colorScheme.primary.withValues(alpha: 0.5),
              disabledForegroundColor:
                  widget.colorScheme.onPrimary.withValues(alpha: 0.8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: widget.isSubmitting
                ? SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: widget.colorScheme.onPrimary,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_rounded,
                        size: 20,
                        color: widget.colorScheme.onPrimary,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: widget.textTheme.labelLarge?.copyWith(
                            color: widget.colorScheme.onPrimary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
