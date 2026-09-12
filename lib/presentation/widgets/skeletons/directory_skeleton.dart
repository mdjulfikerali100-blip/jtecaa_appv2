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
    return Shimmer.fromColors(
      baseColor: theme.colorScheme.surfaceContainerHighest,
      highlightColor: theme.colorScheme.surface,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: itemCount,
        itemBuilder: (context, i) => const _SkeletonTile(),
      ),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const CircleAvatar(radius: 28, backgroundColor: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: 140, color: Colors.white),
                  const SizedBox(height: 8),
                  Container(height: 10, width: 100, color: Colors.white),
                  const SizedBox(height: 8),
                  Container(height: 10, width: 180, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
