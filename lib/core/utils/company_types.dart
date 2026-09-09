// lib/core/utils/company_types.dart
//
// Architecture Appendix G.4 — Company Type dropdown for Profile Edit and
// Directory Filter.

import 'package:flutter/material.dart';

class CompanyTypes {
  static const List<String> all = [
    'Buying House',
    'Trading Office',
    'Sourcing Office',
    'Liaison Office',
    'Retail Office',
    'Garments Industry',
    'Textile Industry',
    'University',
    'College',
    'Others',
  ];

  static List<DropdownMenuItem<String>> getDropdownItems() {
    return all.map((type) {
      return DropdownMenuItem(
        value: type,
        // ⚠️ Appendix K.3 pattern applied even though none of these
        // labels are especially long today — future additions to `all`
        // (e.g. a longer company-type name) won't reintroduce an overflow
        // bug because ellipsis is already the default here.
        child: Text(type, maxLines: 1, overflow: TextOverflow.ellipsis),
      );
    }).toList();
  }
}
