// lib/presentation/widgets/skeletons/directory_skeleton.dart
//
// Architecture Appendix F.6.N (Skeleton Loading) — shimmer sweep over a
// shape matching AlumniDirectoryCard, shown during the initial directory
// fetch and appended at the bottom while loading the next page.

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class DirectorySkeleton extends StatelessWidget {
  final int itemCount;

  const DirectorySkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // ✅ Theme-aware shimmer palette — same pattern as ProfileSkeleton
    // and DriveImage's placeholder. In dark mode the sweep must be
    // slightly LIGHTER than the base to be visible; in light mode it
    // must be brighter.
    final baseColor = colorScheme.surfaceContainerHighest;
    final highlightColor =
        isDark ? colorScheme.surfaceContainerHigh : colorScheme.surface;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        // Not scrollable — it's a loading placeholder, not real content.
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (context, i) => _SkeletonTile(
          baseColor: baseColor,
          colorScheme: colorScheme,
        ),
      ),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile({
    required this.baseColor,
    required this.colorScheme,
  });

  final Color baseColor;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 0,
      // ✅ Match the real card's look — border instead of shadow, so the
      // transition from skeleton → real card feels seamless.
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Avatar placeholder — ✅ was `Colors.white` (invisible in
            // dark mode), now theme-aware. Rounded square to match the
            // real card's avatar shape (not a circle).
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  _SkeletonLine(
                    height: 14,
                    width: 140,
                    color: baseColor,
                    radius: 4,
                  ),
                  const SizedBox(height: 8),
                  // Batch / small meta line
                  _SkeletonLine(
                    height: 10,
                    width: 100,
                    color: baseColor,
                    radius: 4,
                  ),
                  const SizedBox(height: 8),
                  // Department / wider meta line
                  _SkeletonLine(
                    height: 10,
                    width: 180,
                    color: baseColor,
                    radius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small horizontal skeleton "line" — always rounded, theme-safe.
class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({
    required this.height,
    required this.width,
    required this.color,
    this.radius = 4,
  });

  final double height;
  final double width;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
