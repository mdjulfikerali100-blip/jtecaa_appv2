// lib/presentation/widgets/common/blood_group_badge.dart
//
// Architecture Appendix D + F.6.E — compact pill badge shown on the
// Directory Card and Profile Detail header.

import 'package:flutter/material.dart';

import '../../../core/utils/blood_group_helper.dart';

class BloodGroupBadge extends StatelessWidget {
  final String bloodGroup;

  const BloodGroupBadge({super.key, required this.bloodGroup});

  @override
  Widget build(BuildContext context) {
    final color = BloodGroupHelper.getColor(bloodGroup);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.foreground.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(color.icon, size: 14, color: color.foreground),
          const SizedBox(width: 4),
          Text(
            bloodGroup,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color.foreground),
          ),
        ],
      ),
    );
  }
}
