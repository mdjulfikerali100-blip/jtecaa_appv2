// lib/presentation/widgets/skeletons/profile_skeleton.dart
//
// Architecture Appendix F.6.N — shimmer loading state for Profile Detail.

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // ✅ Theme-aware shimmer palette:
    //    - baseColor: the "solid" of the skeleton blocks
    //    - highlightColor: the animated sweep that passes across
    //    In dark mode, the sweep must be LIGHTER than the base; in light
    //    mode, the sweep is BRIGHTER than the base. Getting this backwards
    //    makes the shimmer look inverted/invisible in one of the modes.
    final baseColor = colorScheme.surfaceContainerHighest;
    final highlightColor =
        isDark ? colorScheme.surfaceContainerHigh : colorScheme.surface;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // ── Header / cover block ────────────────────────────────
          // Was 300px fixed. Now 260px — reads closer to the real
          // Profile header's visual weight on most devices, and the
          // skeleton doesn't overshoot the actual content height.
          _SkeletonBlock(
            height: 260,
            color: baseColor,
          ),

          // ── Body: identity card + 2×2 grid of action cards ──────
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + subtitle placeholder
                _SkeletonBlock(
                  height: 56,
                  color: baseColor,
                  radius: 12,
                ),
                const SizedBox(height: 16),

                // Row 1 — two equal cards
                Row(
                  children: [
                    Expanded(
                      child: _SkeletonBlock(
                        height: 72,
                        color: baseColor,
                        radius: 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SkeletonBlock(
                        height: 72,
                        color: baseColor,
                        radius: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Row 2 — two equal cards
                Row(
                  children: [
                    Expanded(
                      child: _SkeletonBlock(
                        height: 72,
                        color: baseColor,
                        radius: 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SkeletonBlock(
                        height: 72,
                        color: baseColor,
                        radius: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Presentational helper.
// ─────────────────────────────────────────────────────────────────────────

/// A single skeleton block. Extracted so the shimmer uses a single
/// consistent color/radius and the layout above stays declarative.
class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    required this.height,
    required this.color,
    this.radius = 0,
  });

  final double height;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      // width is inherited from parent (double.infinity when used directly,
      // or the Expanded's share in a Row).
      width: double.infinity,
      decoration: BoxDecoration(
        // ✅ Was `color: Colors.white` — the white flashed in dark mode
        // and, worse, the shimmer's own baseColor was ALSO white in dark
        // mode, so the entire skeleton was invisible.
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
