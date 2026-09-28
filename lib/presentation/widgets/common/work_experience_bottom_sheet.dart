// lib/presentation/widgets/common/work_experience_bottom_sheet.dart
//
// Architecture Appendix C + L.1.5 — Add/Edit Work Experience form.
//
// ⚠️ Uses Start/End Date pickers, NOT the free-text "duration" field from
// Appendix C's original code. Appendix L.1.5 explicitly replaced that:
// "added startDate/endDate (nullable = still running) so 'Total Work
// Experience' can be computed accurately instead of parsing the old
// free-text duration string, which can't be summed reliably." Since
// `WorkExperience` (Phase 1) was already built with startDate/endDate,
// this form matches that model from the start.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/company_types.dart';
import '../../../core/utils/job_departments.dart';
import '../../../data/models/user/work_experience_model.dart';

class WorkExperienceBottomSheet extends StatefulWidget {
  final WorkExperience? initialExperience;
  final ValueChanged<WorkExperience> onSave;

  const WorkExperienceBottomSheet({
    super.key,
    this.initialExperience,
    required this.onSave,
  });

  @override
  State<WorkExperienceBottomSheet> createState() =>
      _WorkExperienceBottomSheetState();
}

class _WorkExperienceBottomSheetState extends State<WorkExperienceBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _groupController = TextEditingController();
  final _designationController = TextEditingController();

  late String _companyType;
  late String _jobDepartment;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isCurrentJob = false;

  bool get _isEditMode => widget.initialExperience != null;

  @override
  void initState() {
    super.initState();
    final exp = widget.initialExperience;
    _companyType = exp?.companyType ?? CompanyTypes.all.first;
    _jobDepartment = exp?.jobDepartment ?? JobDepartments.all.first;
    _companyController.text = exp?.companyName ?? '';
    _groupController.text = exp?.groupOfCompanies ?? '';
    _designationController.text = exp?.designation ?? '';
    _startDate = exp?.startDate;
    _endDate = exp?.endDate;
    _isCurrentJob = exp != null && exp.endDate == null;
  }

  @override
  void dispose() {
    _companyController.dispose();
    _groupController.dispose();
    _designationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? now,
      firstDate: DateTime(1980),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _save() {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_startDate == null) {
      _showError('Please select a start date');
      return;
    }
    if (!_isCurrentJob && _endDate == null) {
      _showError('Please select an end date, or check "I currently work here"');
      return;
    }

    final experience = WorkExperience(
      companyType: _companyType,
      groupOfCompanies: _groupController.text.trim().isEmpty
          ? null
          : _groupController.text.trim(),
      companyName: _companyController.text.trim(),
      designation: _designationController.text.trim(),
      jobDepartment: _jobDepartment,
      startDate: _startDate!,
      endDate: _isCurrentJob ? null : _endDate,
    );
    widget.onSave(experience);
    Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          Flexible(
            child: Form(
              key: _formKey,
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 12,
                  bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
                ),
                children: [
                  // ── Title ────────────────────────────────────
                  Text(
                    _isEditMode
                        ? 'Edit Work Experience'
                        : 'Add Work Experience',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isEditMode
                        ? 'Update the details of this role.'
                        : 'Add a role to build your professional profile.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 24),

                  // ── Section: Company ─────────────────────────
                  _SectionHeader(
                    icon: Icons.business_outlined,
                    label: 'Company',
                    textTheme: textTheme,
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    initialValue: _companyType,
                    decoration: const InputDecoration(
                      labelText: 'Company Type',
                      prefixIcon: Icon(Icons.business),
                    ),
                    items: CompanyTypes.all
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(
                                t,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _companyType = v!),
                    validator: (v) => v == null ? 'Select company type' : null,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(14),
                    dropdownColor: colorScheme.surfaceContainerHigh,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _groupController,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Group of Companies',
                      prefixIcon: Icon(Icons.account_tree_outlined),
                      hintText: 'e.g., Square Group, Beximco Group',
                      helperText: 'Optional',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _companyController,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Company Name',
                      prefixIcon: Icon(Icons.apartment_outlined),
                      hintText: 'e.g., Square Textiles Ltd.',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Company name is required'
                        : null,
                  ),

                  const SizedBox(height: 24),

                  // ── Section: Role ────────────────────────────
                  _SectionHeader(
                    icon: Icons.work_outline_rounded,
                    label: 'Role',
                    textTheme: textTheme,
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _designationController,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Designation / Position',
                      prefixIcon: Icon(Icons.work_outline),
                      hintText: 'e.g., Production Officer',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Designation is required'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _jobDepartment,
                    decoration: const InputDecoration(
                      labelText: 'Job Department',
                      prefixIcon: Icon(Icons.groups_outlined),
                    ),
                    items: JobDepartments.all
                        .map((d) => DropdownMenuItem(
                              value: d,
                              child: Text(
                                d,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _jobDepartment = v!),
                    validator: (v) => v == null ? 'Select department' : null,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(14),
                    dropdownColor: colorScheme.surfaceContainerHigh,
                  ),

                  const SizedBox(height: 24),

                  // ── Section: Duration ────────────────────────
                  _SectionHeader(
                    icon: Icons.event_outlined,
                    label: 'Duration',
                    textTheme: textTheme,
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 14),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _DateField(
                          label: 'Start Date',
                          value: _startDate,
                          dateFormat: DateFormat('MMM yyyy'),
                          onTap: () => _pickDate(isStart: true),
                          required: true,
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DateField(
                          label: 'End Date',
                          value: _isCurrentJob ? null : _endDate,
                          dateFormat: DateFormat('MMM yyyy'),
                          onTap: _isCurrentJob
                              ? null
                              : () => _pickDate(isStart: false),
                          // "Present" reads as a filled state.
                          overrideText: _isCurrentJob ? 'Present' : null,
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Currently working checkbox ───────────────
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    child: CheckboxListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      controlAffinity: ListTileControlAffinity.leading,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      title: Text(
                        'I currently work here',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      value: _isCurrentJob,
                      onChanged: (v) => setState(() {
                        _isCurrentJob = v ?? false;
                        if (_isCurrentJob) {
                          _endDate = null;
                        }
                      }),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Submit ───────────────────────────────────
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      _isEditMode ? 'UPDATE EXPERIENCE' : 'ADD EXPERIENCE',
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Presentational helpers (no business logic).
// ─────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.textTheme,
    required this.colorScheme,
  });

  final IconData icon;
  final String label;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

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

/// Tappable date field — mimics a filled form input. Renders "Select" or
/// a formatted date; disabled state (End Date while "Present") dims it.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.dateFormat,
    required this.onTap,
    required this.colorScheme,
    required this.textTheme,
    this.required = false,
    this.overrideText,
  });

  final String label;
  final DateTime? value;
  final DateFormat dateFormat;
  final VoidCallback? onTap;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final bool required;
  final String? overrideText;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;
    final hasValue = value != null || overrideText != null;
    final displayText =
        overrideText ?? (value != null ? dateFormat.format(value!) : 'Select');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isDisabled
              ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.25)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasValue && !isDisabled
                ? colorScheme.primary.withValues(alpha: 0.5)
                : colorScheme.outlineVariant,
            width: hasValue && !isDisabled ? 1.4 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 12,
                  color: isDisabled
                      ? colorScheme.onSurfaceVariant.withValues(alpha: 0.6)
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    required ? '$label *' : label,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              displayText,
              style: textTheme.titleSmall?.copyWith(
                color: isDisabled
                    ? colorScheme.onSurfaceVariant.withValues(alpha: 0.6)
                    : (hasValue
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant),
                fontWeight: hasValue ? FontWeight.w700 : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
