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

  /// Optional label override — defaults to 'Blood Group'.
  final String label;

  /// Optional helper text override — defaults to the signup copy.
  /// Pass `null` to hide the helper entirely (e.g. on a compact form).
  final String? helperText;

  const BloodGroupDropdownField({
    super.key,
    required this.value,
    required this.onChanged,
    this.validator,
    this.label = 'Blood Group',
    this.helperText = 'Select for emergency contact purposes',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DropdownButtonFormField<String>(
      // ⚠️ Same rename + safety note as batch_dropdown_field.dart.
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.bloodtype_outlined),
        helperText: helperText,
      ),
      items: BloodGroupHelper.bloodGroups.map((code) {
        return DropdownMenuItem<String>(
          value: code,
          // Overflow-proof label — never overflows even at 200% text scale.
          child: Text(
            BloodGroupHelper.getDisplayLabel(code),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        );
      }).toList(),
      onChanged: onChanged,
      validator: validator ??
          (val) => (val == null || val.isEmpty) ? 'Select blood group' : null,
      isExpanded: true,
      // Slightly taller than default 300 — long blood-group lists scroll
      // less on small devices and fit common screen heights.
      menuMaxHeight: 400,
      // Ensure dropdown menu surface reads well in both light & dark
      // modes without relying on app theme defaults.
      dropdownColor: colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      icon: Icon(
        Icons.expand_more_rounded,
        color: colorScheme.onSurfaceVariant,
      ),
      // Explicit text style — drop the hardcoded fontSize:15 in favour
      // of the theme's bodyLarge, so system font scaling (200%) is
      // respected and light/dark contrast is inherited correctly.
      style: theme.textTheme.bodyLarge?.copyWith(
        color: colorScheme.onSurface,
      ),
    );
  }
}
