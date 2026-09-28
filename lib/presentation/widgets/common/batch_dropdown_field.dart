// lib/presentation/widgets/common/batch_dropdown_field.dart
//
// Architecture Appendix C. ⚠️ PULLED FORWARD from Phase 6: the Master
// Prompt schedules this file for Phase 6, but Phase 3's Signup screen
// (both Alumni and Student tabs, §M.2) needs a Batch dropdown too, since
// both AlumniIdValidator and StudentIdValidator validate against the
// selected Batch Number. Building it once now and having Phase 6 reuse it
// unchanged avoids two independent copies of the same dropdown drifting
// apart later.

import 'package:flutter/material.dart';

import '../../../core/utils/batch_helper.dart';

class BatchDropdownField extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;

  /// Optional label override — defaults to 'Batch'.
  /// Handy for future reuse (e.g. a "Filter by batch" screen), without
  /// touching this widget's core behaviour.
  final String label;

  /// Optional helper text override — defaults to the signup copy.
  final String? helperText;

  const BatchDropdownField({
    super.key,
    required this.value,
    required this.onChanged,
    this.validator,
    this.label = 'Batch',
    this.helperText = 'Select your graduation batch',
  });

  @override
  Widget build(BuildContext context) {
    final batchOptions = BatchHelper.generateBatchOptions();

    return DropdownButtonFormField<String>(
      // ⚠️ Renamed `value:` → `initialValue:` (Flutter SDK deprecation,
      // post v3.33). Verified safe for this widget's usage pattern: every
      // call site (Signup, Profile Edit) already knows the correct value
      // the moment this widget first builds — nothing re-sets it on an
      // already-built instance from an external async source later, so
      // the "initial value only" semantics of the new name match how
      // this widget was already being used.
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.school_outlined),
        helperText: helperText,
        // Helper text is 1 line in normal scale, 2 lines at 200% —
        // no ellipsis needed here since the copy is short & fixed.
      ),
      items: batchOptions
          .map(
            (batch) => DropdownMenuItem(
              value: batch,
              // Long batch labels never overflow — ellipsis + 1 line.
              child: Text(
                batch,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: validator ??
          (val) => (val == null || val.isEmpty) ? 'Select batch' : null,
      isExpanded: true,
      // Slightly taller than the default 300 — long batch lists scroll
      // less on small devices, and 400 still fits all common screens.
      menuMaxHeight: 400,
      // Ensure dropdown menu items are readable in both light & dark
      // without leaning on the app theme's defaults.
      dropdownColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      icon: Icon(
        Icons.expand_more_rounded,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
    );
  }
}
