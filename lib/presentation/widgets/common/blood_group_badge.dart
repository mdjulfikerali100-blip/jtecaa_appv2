// lib/presentation/widgets/common/blood_group_badge.dart
//
// Architecture Appendix D + F.6.E — compact pill badge shown on the
// Directory Card and Profile Detail header.

import 'package:flutter/material.dart';

import '../../../core/utils/blood_group_helper.dart';

class BloodGroupBadge extends StatelessWidget {
  final String bloodGroup;

  /// Optional size preset — lets callers shrink/grow the badge to match
  /// its context (dense list vs. profile header) without duplicating
  /// styles. Defaults preserve current appearance exactly.
  final BloodGroupBadgeSize size;

  const BloodGroupBadge({
    super.key,
    required this.bloodGroup,
    this.size = BloodGroupBadgeSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    final color = BloodGroupHelper.getColor(bloodGroup);
    final _Metrics m = _Metrics.of(size);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: m.hPad,
        vertical: m.vPad,
      ),
      decoration: BoxDecoration(
        color: color.background,
        borderRadius: BorderRadius.circular(m.radius),
        border: Border.all(
          color: color.foreground.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(color.icon, size: m.iconSize, color: color.foreground),
          SizedBox(width: m.gap),
          // 200% font scale safe: badge never clips its label.
          // Flexible lets it yield inside a tight parent Row.
          Flexible(
            child: Text(
              bloodGroup,
              style: TextStyle(
                fontSize: m.fontSize,
                fontWeight: FontWeight.w700,
                color: color.foreground,
                letterSpacing: 0.2,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
        ],
      ),
    );
  }
}

/// Public size presets so callers can express intent without magic numbers.
enum BloodGroupBadgeSize { small, medium, large }

/// Internal metrics table — one source of truth for each preset.
class _Metrics {
  const _Metrics({
    required this.hPad,
    required this.vPad,
    required this.radius,
    required this.iconSize,
    required this.gap,
    required this.fontSize,
  });

  final double hPad;
  final double vPad;
  final double radius;
  final double iconSize;
  final double gap;
  final double fontSize;

  static _Metrics of(BloodGroupBadgeSize size) {
    switch (size) {
      case BloodGroupBadgeSize.small:
        return const _Metrics(
          hPad: 6,
          vPad: 2,
          radius: 8,
          iconSize: 11,
          gap: 3,
          fontSize: 10,
        );
      case BloodGroupBadgeSize.medium:
        // ✅ Preserves the exact original metrics — zero visual change
        // for existing call sites.
        return const _Metrics(
          hPad: 8,
          vPad: 4,
          radius: 12,
          iconSize: 14,
          gap: 4,
          fontSize: 12,
        );
      case BloodGroupBadgeSize.large:
        return const _Metrics(
          hPad: 10,
          vPad: 5,
          radius: 14,
          iconSize: 16,
          gap: 5,
          fontSize: 13,
        );
    }
  }
}
