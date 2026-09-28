// lib/presentation/widgets/common/news_card.dart
//
// News feed card — image (optional), title, meta line, expandable body,
// posted-by footer, owner actions (Edit/Delete), and an auto-delete
// countdown bar that shrinks toward zero as the post ages.

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
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final news = widget.news;
    final isOwner = news.isOwnedBy(widget.currentUid);

    // Warning tone — used for both the bar and its label.
    // ✅ Replaced hardcoded 0xFFD97706 with a theme-aware warning palette:
    //    amber in light mode, a brighter amber in dark mode for contrast.
    final isDark = theme.brightness == Brightness.dark;
    final warningColor = isDark
        ? const Color(0xFFFBBF24) // amber-400
        : const Color(0xFFD97706); // amber-600

    // Pre-compute so we don't evaluate the same condition multiple times.
    final isExpiringSoon = news.isExpiringSoon;
    final isExpiredToday = news.daysRemaining <= 0;

    final expiryText = _expiryLabel(news);
    final expiryColor =
        isExpiringSoon ? warningColor : colorScheme.onSurfaceVariant;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cover image (optional) ────────────────────────────
          if (news.imageUrl != null && news.imageUrl!.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: DriveImage(
                fileId: news.imageUrl!,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Title ────────────────────────────────────────
                Text(
                  news.title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),

                // ── Meta line ────────────────────────────────────
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _relativeTime(news.postedAt),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.hourglass_bottom_rounded,
                      size: 12,
                      color: expiryColor,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        expiryText,
                        style: textTheme.bodySmall?.copyWith(
                          color: expiryColor,
                          fontWeight: isExpiringSoon
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Body — expandable ─────────────────────────────
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topLeft,
                  child: Text(
                    news.body,
                    maxLines: _expanded ? null : 3,
                    overflow: _expanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                      height: 1.5,
                    ),
                  ),
                ),

                // ── Read More / Show Less toggle ───────────────────
                if (news.body.length > 140 || news.body.contains('\n'))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: TextButton.icon(
                      onPressed: () => setState(() => _expanded = !_expanded),
                      icon: AnimatedRotation(
                        duration: const Duration(milliseconds: 200),
                        turns: _expanded ? 0.5 : 0.0,
                        child: const Icon(Icons.expand_more_rounded, size: 18),
                      ),
                      label: Text(_expanded ? 'Show less' : 'Read more'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: const Size(0, 40),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: colorScheme.primary,
                        textStyle: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 8),
                PostedByLabel(
                  name: news.postedByName,
                  batch: news.postedByBatch,
                ),

                // ── Owner actions ────────────────────────────────
                if (isOwner) ...[
                  const SizedBox(height: 8),
                  Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _OwnerButton(
                        icon: Icons.edit_outlined,
                        label: 'Edit',
                        color: colorScheme.primary,
                        onPressed: widget.onEdit,
                      ),
                      const SizedBox(width: 4),
                      _OwnerButton(
                        icon: Icons.delete_outline_rounded,
                        label: 'Delete',
                        color: colorScheme.error,
                        onPressed: widget.onDelete,
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),

                // ── Auto-delete countdown bar ─────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: news.lifeRemainingFraction.clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    color: isExpiringSoon ? warningColor : colorScheme.tertiary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      isExpiredToday
                          ? Icons.timer_off_outlined
                          : Icons.timer_outlined,
                      size: 12,
                      color: expiryColor,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        expiryText,
                        style: textTheme.labelSmall?.copyWith(
                          color: expiryColor,
                          fontWeight: isExpiringSoon
                              ? FontWeight.w700
                              : FontWeight.w500,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

// ─────────────────────────────────────────────────────────────────────────
// Presentational helpers (no business logic).
// ─────────────────────────────────────────────────────────────────────────

/// Owner action button — icon + label, colored by intent.
/// Slightly tighter than a default TextButton so two fit comfortably
/// without pushing each other around at 200% text scale.
class _OwnerButton extends StatelessWidget {
  const _OwnerButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: TextButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
