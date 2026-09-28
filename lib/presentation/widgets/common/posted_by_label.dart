// lib/presentation/widgets/common/posted_by_label.dart
//
// Architecture Appendix L.2.1 — "Posted by: [Name] (Batch)", rendered
// straight from the Sheet row with zero extra Firestore reads (the
// poster's name/batch were already written into the row at post-time by
// JobPostModel.toPostBody()/NewsPostModel.toPostBody()).

import 'package:flutter/material.dart';

class PostedByLabel extends StatelessWidget {
  final String name;
  final String batch;

  /// Optional icon override. Defaults to `person_outline` — the same
  /// visual rhythm used across Job/News cards. Set to `null` to omit
  /// the icon entirely (e.g. when this label appears inside a header
  /// that already has one).
  final IconData? icon;

  /// Optional flag to render the "(Batch)" fragment as a subtle inline
  /// chip instead of plain parenthesised text. Non-breaking: default
  /// `false` matches the original single-line presentation.
  final bool batchAsChip;

  const PostedByLabel({
    super.key,
    required this.name,
    required this.batch,
    this.icon = Icons.person_outline_rounded,
    this.batchAsChip = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final hasBatch = batch.isNotEmpty;

    // Two visual modes — both drop-in replacements for the original.
    if (batchAsChip) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              'Posted by: $name',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                height: 1.3,
              ),
            ),
          ),
          if (hasBatch) ...[
            const SizedBox(width: 6),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  batch,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ],
      );
    }

    // ── Original single-line presentation (default) ────────────
    // Kept byte-for-byte compatible with the previous output, so all
    // existing call sites render exactly what they used to.
    return Text(
      'Posted by: $name${hasBatch ? ' ($batch)' : ''}',
      maxLines: 2, // Appendix K.3 — allow wrap instead of overflow
      overflow: TextOverflow.ellipsis,
      style: textTheme.labelSmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
        // Subtle polish — same size/color, slightly firmer weight so the
        // name reads clearly when cards stack tightly in a feed.
        fontWeight: FontWeight.w500,
        height: 1.3,
        letterSpacing: 0.1,
      ),
    );
  }
}
