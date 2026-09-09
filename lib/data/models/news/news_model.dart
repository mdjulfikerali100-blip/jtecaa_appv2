// lib/data/models/news/news_model.dart
//
// Architecture Appendix L.2.1: "NewsPostModel is identical [to
// JobPostModel] minus the apply_* fields, plus body/imageUrl." Lives
// entirely in Google Sheets (§5), never Firestore.

class NewsPostModel {
  final String id;
  final String title;
  final String body;
  final String? imageUrl;
  final String postedByUid;
  final String postedByName;
  final String postedByBatch;
  final DateTime postedAt;
  final int autoDeleteDays;

  NewsPostModel({
    required this.id,
    required this.title,
    required this.body,
    this.imageUrl,
    required this.postedByUid,
    required this.postedByName,
    required this.postedByBatch,
    required this.postedAt,
    this.autoDeleteDays = 7,
  });

  /// Matches the Apps Script auto-delete check (Architecture §7.6):
  /// `posted_at + auto_delete_days`.
  bool get isExpired {
    final deleteAfter = postedAt.add(Duration(days: autoDeleteDays));
    return DateTime.now().isAfter(deleteAfter);
  }

  /// Days remaining before auto-delete — used by the progress bar
  /// (Architecture Appendix F.7.8), clamped to 0 rather than going negative.
  int get daysUntilExpiry {
    final deleteAfter = postedAt.add(Duration(days: autoDeleteDays));
    final remaining = deleteAfter.difference(DateTime.now()).inDays;
    return remaining < 0 ? 0 : remaining;
  }

  factory NewsPostModel.fromMap(Map<String, dynamic> map) {
    return NewsPostModel(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      imageUrl: map['image_url'] as String?,
      postedByUid: map['posted_by'] as String? ?? '',
      postedByName: map['posted_by_name'] as String? ?? 'Alumni',
      postedByBatch: map['posted_by_batch'] as String? ?? '',
      postedAt: DateTime.tryParse(map['posted_at'] as String? ?? '') ??
          DateTime.now(),
      autoDeleteDays: int.tryParse('${map['auto_delete_days'] ?? 7}') ?? 7,
    );
  }

  /// Request body shape for `action=postNews` (Appendix I.4).
  static Map<String, dynamic> toPostBody({
    required String title,
    required String body,
    String? imageUrl,
    required String postedByUid,
    required String postedByName,
    required String postedByBatch,
    int autoDeleteDays = 7,
  }) {
    return {
      'title': title,
      'body': body,
      'image_url': imageUrl ?? '',
      'posted_by': postedByUid,
      'posted_by_name': postedByName,
      'posted_by_batch': postedByBatch,
      'auto_delete_days': '$autoDeleteDays',
    };
  }
}
