import 'package:flutter/material.dart';
import '../../../data/models/news/news_model.dart';
import 'drive_image.dart';
import 'posted_by_label.dart';

class NewsCard extends StatefulWidget {
  final NewsModel news;
  final String? currentUid;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const NewsCard({
    super.key,
    required this.news,
    this.currentUid,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends State<NewsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final news = widget.news;
    final isOwner = news.isOwnedBy(widget.currentUid);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias, // so the image's top corners actually clip
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image — only if this post has one. AspectRatio(16/9) matches
          // the wireframe spec exactly ("Image: Aspect ratio 16:9, top").
          if (news.imageUrl != null)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: DriveImage(
                fileId: news.imageUrl!,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // ⚠️ K.3 — size to content
              children: [
                // Title
                Text(
                  news.title,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Meta: "Posted 2 days ago • Expires in 5 days"
                Text(
                  '${_relativeTime(news.postedAt)} • ${_expiryLabel(news)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme
                        .onSurfaceVariant, // ⚠️ K.1 — never hardcode
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Body — max 3 lines collapsed, expandable via "Read More".
                // ⚠️ Addendum §1.4: full News detail as its own bottom
                // sheet is deferred ("আপাতত inline") — this in-card expand
                // IS the current, intended behavior, not a placeholder.
                Text(
                  news.body,
                  maxLines: _expanded ? null : 3,
                  overflow:
                      _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                if (news.body.length > 140 || news.body.contains('\n'))
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize:
                            const Size(48, 36), // K accessibility: ≥48dp target
                        foregroundColor: theme.colorScheme.secondary,
                      ),
                      onPressed: () => setState(() => _expanded = !_expanded),
                      child: Text(_expanded ? 'Show Less' : 'Read More'),
                    ),
                  ),

                const SizedBox(height: 8),
                PostedByLabel(
                    name: news.postedByName, batch: news.postedByBatch),

                // Owner actions — Edit/Delete, only for the person who
                // posted it (Architecture §7.6, mirrors Jobs' pattern).
                if (isOwner) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: widget.onEdit,
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit'),
                      ),
                      TextButton.icon(
                        onPressed: widget.onDelete,
                        icon: Icon(Icons.delete_outline,
                            size: 18, color: theme.colorScheme.error),
                        label: Text(
                          'Delete',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 4),

                // Auto-delete indicator — SHRINKS toward 0 (Addendum §6),
                // not a normal "loading" bar that fills up.
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: news.lifeRemainingFraction,
                    minHeight: 4,
                    backgroundColor: theme.colorScheme.surfaceVariant,
                    color: news.isExpiringSoon
                        ? const Color(
                            0xFFD97706) // warning, per §F.2 semantic colors
                        : theme.colorScheme.tertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  news.daysRemaining <= 0
                      ? 'Expiring today'
                      : 'Expires in ${news.daysRemaining} day${news.daysRemaining > 1 ? 's' : ''}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: news.isExpiringSoon
                        ? const Color(0xFFD97706)
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Small local helper — no `timeago` package in the pubspec (Appendix
  /// H.2's dependency list doesn't include one), so this is a minimal
  /// hand-rolled version rather than adding a new dependency for one label.
  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return 'Posted ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Posted ${diff.inHours}h ago';
    final days = diff.inDays;
    return 'Posted $days day${days > 1 ? 's' : ''} ago';
  }

  String _expiryLabel(NewsModel news) {
    if (news.daysRemaining <= 0) return 'Expiring today';
    return 'Expires in ${news.daysRemaining} day${news.daysRemaining > 1 ? 's' : ''}';
  }
}
