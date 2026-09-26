/// lib/data/models/news/news_model.dart
///
/// News item model — backed by the "News" tab of the Jobs+News Google
/// Sheet (Architecture §5.2, §I.3). Follows the exact same
/// "client computes, Apps Script just stores" pattern as JobPostModel
/// (Appendix L.2.1) and StatsRepository (§8.3): nothing here ever touches
/// Firestore, this is 100% Sheets-Proxy + Hive cache (§6).
///
/// ⚠️ IMPORTANT (Addendum §6, Phase 8 design decision):
/// `imageUrl` stores a **Google Drive fileId**, never a plain network URL —
/// exactly like `users_private.purl` (Architecture §5.4). It must always be
/// rendered through the `DriveImage` widget (Phase 6), never
/// `Image.network()` / `CachedNetworkImage`, or it will fail silently
/// (Drive URLs are CORS-blocked, §5.4 "CORS-Proof Rendering").
class NewsModel {
  final String id;
  final String title;
  final String body;
  final String?
      imageUrl; // Drive fileId, nullable — not every post has an image
  final String postedByUid;
  final String postedByName;
  final String postedByBatch;
  final DateTime postedAt;
  final int autoDeleteDays;

  const NewsModel({
    required this.id,
    required this.title,
    required this.body,
    this.imageUrl,
    required this.postedByUid,
    required this.postedByName,
    required this.postedByBatch,
    required this.postedAt,
    required this.autoDeleteDays,
  });

  /// Parses a row already normalized by GoogleSheetsProxy's `getNews()`
  /// (which itself mirrors Apps Script's `rowToObject()`, Appendix I.1 —
  /// lowercase, underscore-joined keys, e.g. "image_url", "posted_by_name").
  factory NewsModel.fromMap(Map<String, dynamic> map) {
    return NewsModel(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      body: (map['body'] ?? '').toString(),
      // Sheets returns '' for an empty cell, not null — normalize to null
      // so `imageUrl != null` checks (DriveImage rendering) work correctly.
      imageUrl:
          (map['image_url'] == null || map['image_url'].toString().isEmpty)
              ? null
              : map['image_url'].toString(),
      postedByUid: (map['posted_by'] ?? '').toString(),
      // Fallback label matches Appendix L.2.1's PostedByLabel default —
      // an older row created before posted_by_name/batch existed should
      // still render something sensible instead of a blank name.
      postedByName: (map['posted_by_name'] == null ||
              map['posted_by_name'].toString().isEmpty)
          ? 'Alumni'
          : map['posted_by_name'].toString(),
      postedByBatch: (map['posted_by_batch'] ?? '').toString(),
      // Apps Script writes posted_at as an ISO string (`new Date().toISOString()`,
      // Appendix I.1 postNews()) — tryParse falls back to "now" so a malformed
      // row never crashes the whole list, it just shows as freshly posted.
      postedAt: DateTime.tryParse((map['posted_at'] ?? '').toString()) ??
          DateTime.now(),
      autoDeleteDays:
          int.tryParse((map['auto_delete_days'] ?? '7').toString()) ?? 7,
    );
  }

  /// Owner check — used to show/hide Edit/Delete actions on a card
  /// (Architecture §7.6 "Owner Edit: Same as jobs").
  bool isOwnedBy(String? currentUid) =>
      currentUid != null && currentUid.isNotEmpty && currentUid == postedByUid;

  /// When this post's auto-delete window ends. Apps Script's own
  /// `cleanExpiredNews()` (Appendix I.1) is the actual source of truth for
  /// deletion — this is purely a client-side display calculation so the
  /// countdown/progress bar can render without a network call.
  DateTime get expiresAt => postedAt.add(Duration(days: autoDeleteDays));

  /// Whole days left before auto-delete, floored at 0 (never negative —
  /// a post lingering past its Apps Script cleanup window, e.g. because
  /// the daily trigger hasn't run yet, should show "Expires today", not
  /// "-1 days").
  int get daysRemaining {
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) return 0;
    // Ceil so "23 hours left" still reads as "1 day left", not "0 days".
    return (remaining.inHours / 24).ceil();
  }

  /// ⚠️ Addendum §6 design decision: the progress bar **shrinks toward 0**
  /// as the post approaches expiry (i.e. this is "life remaining", not
  /// "time elapsed") — 1.0 = just posted, 0.0 = about to be deleted.
  /// `LinearProgressIndicator(value: lifeRemainingFraction)` is exactly
  /// what a UI needs to visualize a countdown that drains, not fills.
  double get lifeRemainingFraction {
    final totalMs = Duration(days: autoDeleteDays).inMilliseconds;
    if (totalMs <= 0) return 0.0;
    final remainingMs = expiresAt.difference(DateTime.now()).inMilliseconds;
    return (remainingMs / totalMs).clamp(0.0, 1.0);
  }

  /// True once fewer than 2 days remain — used to switch the progress bar
  /// color to `warning` (Architecture §F.7 "News Screen" wireframe:
  /// "Color: warning if < 2 days left").
  bool get isExpiringSoon => daysRemaining < 2;

  /// Payload for `POST ?action=postNews` (Appendix I.1 `postNews()`).
  /// `posted_by`/`posted_by_name`/`posted_by_batch` are supplied by the
  /// caller (from the poster's own cached profile, §L.2.1 pattern) rather
  /// than read off `this`, because this factory is used to BUILD a new
  /// post before it has an id/postedAt of its own yet.
  static Map<String, dynamic> toCreateBody({
    required String title,
    required String body,
    String? imageFileId,
    required String postedByUid,
    required String postedByName,
    required String postedByBatch,
    int autoDeleteDays = 7,
  }) {
    return {
      'title': title,
      'body': body,
      'image_url': imageFileId ?? '',
      'posted_by': postedByUid,
      'posted_by_name': postedByName,
      'posted_by_batch': postedByBatch,
      'auto_delete_days': autoDeleteDays.toString(),
    };
  }

  /// ⚠️ Addendum §6 design decision: Apps Script's `editNews()` (Appendix
  /// I.1) only ever reads `id`/`title`/`body`/`image_url` off the request —
  /// it does NOT accept posted_by/posted_at/auto_delete_days changes. This
  /// method deliberately sends ONLY those 4 keys so a future accidental
  /// param never gets silently ignored server-side without the caller
  /// realizing edit payloads and create payloads have different shapes.
  Map<String, dynamic> toEditBody() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'image_url': imageUrl ?? '',
    };
  }

  NewsModel copyWith({
    String? title,
    String? body,
    String? imageUrl,
  }) {
    return NewsModel(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      imageUrl: imageUrl ?? this.imageUrl,
      postedByUid: postedByUid,
      postedByName: postedByName,
      postedByBatch: postedByBatch,
      postedAt: postedAt,
      autoDeleteDays: autoDeleteDays,
    );
  }
}
