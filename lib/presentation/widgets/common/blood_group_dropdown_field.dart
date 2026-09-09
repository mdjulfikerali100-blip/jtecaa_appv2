// lib/presentation/widgets/common/blood_group_dropdown_field.dart
//
// Architecture Appendix C. ⚠️ PULLED FORWARD from Phase 6 — same reason
// as batch_dropdown_field.dart: Phase 3's Signup screen needs a Blood
// Group dropdown for both roles, so it's built once here and Phase 6
// reuses this file unchanged.

import 'package:flutter/material.dart';

import '../../../core/utils/blood_group_helper.dart';

class BloodGroupDropdownField extends StatelessWidget {
  final String? value; // stores "A+", "B-", etc.
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;

  const BloodGroupDropdownField({
    super.key,
    required this.value,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: const InputDecoration(
        labelText: 'Blood Group',
        prefixIcon: Icon(Icons.bloodtype_outlined),
        helperText: 'Select for emergency contact purposes',
      ),
      items: BloodGroupHelper.bloodGroups.map((code) {
        return DropdownMenuItem(
          value: code,
          child: Text(
            BloodGroupHelper.getDisplayLabel(code),
            style: const TextStyle(fontSize: 15),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
      validator: validator ??
          (val) => (val == null || val.isEmpty) ? 'Select blood group' : null,
      isExpanded: true,
    );
  }
}
