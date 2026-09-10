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

  const BatchDropdownField({
    super.key,
    required this.value,
    required this.onChanged,
    this.validator,
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
      decoration: const InputDecoration(
        labelText: 'Batch',
        prefixIcon: Icon(Icons.school_outlined),
        helperText: 'Select your graduation batch',
      ),
      items: batchOptions.map((batch) {
        return DropdownMenuItem(value: batch, child: Text(batch));
      }).toList(),
      onChanged: onChanged,
      validator: validator ??
          (val) => (val == null || val.isEmpty) ? 'Select batch' : null,
      isExpanded: true,
      menuMaxHeight: 400,
    );
  }
}
