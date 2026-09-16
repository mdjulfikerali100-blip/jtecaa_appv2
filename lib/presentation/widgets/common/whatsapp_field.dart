// lib/presentation/widgets/common/whatsapp_field.dart
//
// Architecture Appendix C — WhatsApp number input field for Profile Edit.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/phone_validator.dart';

class WhatsAppField extends StatelessWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;

  const WhatsAppField({super.key, required this.controller, this.validator});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      decoration: const InputDecoration(
        labelText: 'WhatsApp Number',
        hintText: '0171XXXXXXX',
        prefixIcon: Icon(Icons.chat_bubble_outline),
        helperText:
            'Enter BD number without +880 (e.g., 0171XXXXXXX). Optional.',
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
