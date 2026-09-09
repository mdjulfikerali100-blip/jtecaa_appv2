// lib/core/utils/blood_group_helper.dart
//
// Architecture Appendix B — blood group dropdown options, display labels,
// and the badge color logic used by the Directory Card's blood-group pill
// (Appendix D).

import 'package:flutter/material.dart';

class BloodGroupHelper {
  static const List<String> bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'O+',
    'O-',
    'AB+',
    'AB-',
  ];

  /// Map of English code to full English display label.
  static const Map<String, String> _fullLabels = {
    'A+': 'A Positive',
    'A-': 'A Negative',
    'B+': 'B Positive',
    'B-': 'B Negative',
    'O+': 'O Positive',
    'O-': 'O Negative',
    'AB+': 'AB Positive',
    'AB-': 'AB Negative',
  };

  /// Returns display string: "A+ (A Positive)"
  static String getDisplayLabel(String bloodGroup) {
    final full = _fullLabels[bloodGroup];
    return full != null ? '$bloodGroup ($full)' : bloodGroup;
  }

  /// Returns only the full English label for compact display.
  static String getFullLabel(String bloodGroup) {
    return _fullLabels[bloodGroup] ?? bloodGroup;
  }

  static List<String> getDisplayOptions() {
    return bloodGroups.map(getDisplayLabel).toList();
  }

  /// Extracts code from display label (e.g., "A+ (A Positive)" → "A+").
  static String extractCode(String displayLabel) {
    return displayLabel.split(' ').first;
  }

  /// Returns the badge color scheme for a blood group (Architecture
  /// Appendix B + F.6.E). O- is the universal donor, so it gets a
  /// slightly darker/distinct red to stand out from the other 7 groups —
  /// this is a semantic emphasis, not decoration, so it lives here in the
  /// data-layer helper rather than being re-decided per-widget.
  static BloodGroupColor getColor(String bloodGroup) {
    if (bloodGroup == 'O-') {
      return const BloodGroupColor(
        background: Color(0xFFFFEBEE),
        foreground: Color(0xFFC62828),
        icon: Icons.water_drop,
      );
    }
    return const BloodGroupColor(
      background: Color(0xFFFFEBEE),
      foreground: Color(0xFFD32F2F),
      icon: Icons.water_drop,
    );
  }
}

class BloodGroupColor {
  final Color background;
  final Color foreground;
  final IconData icon;

  const BloodGroupColor({
    required this.background,
    required this.foreground,
    required this.icon,
  });
}
