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

  const PostedByLabel({super.key, required this.name, required this.batch});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'Posted by: $name${batch.isNotEmpty ? ' ($batch)' : ''}',
      maxLines: 2, // Appendix K.3 — allow wrap instead of overflow
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.labelSmall
          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    );
  }
}
