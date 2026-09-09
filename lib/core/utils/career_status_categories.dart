// lib/core/utils/career_status_categories.dart
//
// Architecture Appendix G.3 — Career Status dropdown, Donut Chart segment
// colors, and short labels.
//
// ⚠️ `getDropdownItems()` below already applies the Appendix K.3 overflow
// fix from day one: the longest label ("Preparing for a Government Job")
// plus a 12px color dot can exceed a narrow real device's dropdown-field
// width. Wrapping the text in Expanded + ellipsis + maxLines:1 prevents
// the "BOTTOM OVERFLOWED BY 31 PIXELS" error this exact widget caused on
// the Signup/Profile-Edit screens before the fix — building it correctly
// here means every screen that reuses this list is safe automatically.

import 'package:flutter/material.dart';

class CareerStatusCategories {
  static const List<String> all = [
    'Job Holder',
    'Looking for a Job',
    'Higher Studies',
    'Preparing for Higher Studies',
    'Preparing for a Government Job',
  ];

  /// Display colors for Donut Chart / UI badges (Architecture F.6.O).
  static const Map<String, Color> chartColors = {
    'Job Holder': Color(0xFF1A365D), // Primary Navy
    'Looking for a Job': Color(0xFFD97706), // Warning Amber
    'Higher Studies': Color(0xFF0F766E), // Tertiary Teal
    'Preparing for Higher Studies': Color(0xFFB45309), // Secondary Bronze
    'Preparing for a Government Job': Color(0xFF2563EB), // Info Blue
  };

  /// Short labels for compact display (chips, chart legend).
  static const Map<String, String> shortLabels = {
    'Job Holder': 'Employed',
    'Looking for a Job': 'Job Seeking',
    'Higher Studies': 'Studying',
    'Preparing for Higher Studies': 'Prep. Studies',
    'Preparing for a Government Job': 'Govt. Prep.',
  };

  static String getDisplayLabel(String category) {
    return shortLabels[category] ?? category;
  }

  static Color getColor(String category) {
    return chartColors[category] ?? const Color(0xFF64748B);
  }

  static List<DropdownMenuItem<String>> getDropdownItems() {
    return all.map((category) {
      return DropdownMenuItem(
        value: category,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: getColor(category),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            // ⚠️ Appendix K.3 pattern: Expanded + ellipsis + maxLines:1 so
            // the longest category label never overflows a narrow field.
            Expanded(
              child: Text(
                category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
