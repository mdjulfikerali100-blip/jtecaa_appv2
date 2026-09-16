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
    return Shimmer.fromColors(
      baseColor: theme.colorScheme.surfaceContainerHighest,
      highlightColor: theme.colorScheme.surface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(height: 300, color: Colors.white),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    height: 56, width: double.infinity, color: Colors.white),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Container(height: 72, color: Colors.white)),
                    const SizedBox(width: 12),
                    Expanded(child: Container(height: 72, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Container(height: 72, color: Colors.white)),
                    const SizedBox(width: 12),
                    Expanded(child: Container(height: 72, color: Colors.white)),
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
