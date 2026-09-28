// lib/presentation/widgets/common/whatsapp_field.dart
//
// Architecture Appendix C — WhatsApp number input field for Profile Edit.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/phone_validator.dart';

class WhatsAppField extends StatelessWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;

  /// Optional label override — defaults to 'WhatsApp Number'.
  final String label;

  /// Optional helper text override. Pass `null` to hide the helper.
  final String? helperText;

  /// Focus/next-field wiring — passed through to the TextFormField so
  /// parent forms can chain keyboard focus. Non-breaking: defaults
  /// preserve current single-field behaviour.
  final TextInputAction textInputAction;
  final void Function(String)? onFieldSubmitted;

  /// Optional focus node — lets parents auto-focus this field.
  final FocusNode? focusNode;

  const WhatsAppField({
    super.key,
    required this.controller,
    this.validator,
    this.label = 'WhatsApp Number',
    this.helperText =
        'Enter BD number without +880 (e.g., 0171XXXXXXX). Optional.',
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.phone,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      autofillHints: const [AutofillHints.telephoneNumber],
      // Autocorrect off for phone numbers — prevents "helpful" fixes.
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: label,
        hintText: '0171XXXXXXX',
        prefixIcon: const Icon(Icons.chat_bubble_outline),
        helperText: helperText,
      ),
      validator: validator ??
          (val) {
            // ⚠️ WhatsApp is optional (not required at signup or edit) —
            // an empty value is valid; only a NON-empty, malformed value
            // is rejected.
            if (val == null || val.isEmpty) {
              return null;
            }
            if (!PhoneValidator.isValidBangladeshPhone(val)) {
              return 'Enter a valid BD WhatsApp number';
            }
            return null;
          },
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(11),
      ],
    );
  }
}
