import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/news/news_model.dart';
import '../datasources/external/google_sheets_proxy.dart';

class NewsRepository {
  final GoogleSheetsProxy _proxy;

  NewsRepository([GoogleSheetsProxy? proxy])
      : _proxy = proxy ?? GoogleSheetsProxy();

  static const String _boxName = 'news_cache';
  static const String _cacheKey = 'news_list_v1';
  static const Duration _cacheTtl =
      Duration(hours: 6); // §6.2 "jobs/news: 6 hours"

  /// Cache-first read. `forceRefresh: true` is used for pull-to-refresh —
  /// bypasses the TTL check and always hits the network, then re-caches.
  Future<List<NewsModel>> getNews({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _readCache();
      if (cached != null) return cached;
    }

    final rawList = await _proxy.getNews();
    final news = rawList
        .map((row) => NewsModel.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList()
      // Newest first — Sheets appendRow() means new posts are at the
      // bottom of the underlying sheet, so the client sorts on read.
      ..sort((a, b) => b.postedAt.compareTo(a.postedAt));

    await _writeCache(news);
    return news;
  }

  /// Posts a brand-new News item. Returns the freshly-created NewsModel
  /// (built client-side from the same data just sent, plus the id/postedAt
  /// echoed back by Apps Script) so the UI can optimistically prepend it
  /// without waiting for a full list refetch.
  Future<NewsModel> postNews({
    required String title,
    required String body,
    String? imageFileId,
    required String postedByUid,
    required String postedByName,
    required String postedByBatch,
    int autoDeleteDays = 7,
  }) async {
    final payload = NewsModel.toCreateBody(
      title: title,
      body: body,
      imageFileId: imageFileId,
      postedByUid: postedByUid,
      postedByName: postedByName,
      postedByBatch: postedByBatch,
      autoDeleteDays: autoDeleteDays,
    );

    final response = await _proxy.postNews(payload);
    // Apps Script's postNews() returns { id, posted_at } (Appendix I.1).
    final id = (response['id'] ?? '').toString();
    final postedAt =
        DateTime.tryParse((response['posted_at'] ?? '').toString()) ??
            DateTime.now();

    final created = NewsModel(
      id: id,
      title: title,
      body: body,
      imageUrl: imageFileId,
      postedByUid: postedByUid,
      postedByName: postedByName,
      postedByBatch: postedByBatch,
      postedAt: postedAt,
      autoDeleteDays: autoDeleteDays,
    );

    // Invalidate cache so the next getNews() (even without forceRefresh
    // from the caller) doesn't serve a stale pre-post snapshot for 6h.
    await _clearCache();
    return created;
  }

  /// Edits an existing post. ⚠️ Sends ONLY id/title/body/image_url —
  /// see NewsModel.toEditBody() for why (Apps Script editNews() shape).
  Future<void> editNews(NewsModel updated) async {
    await _proxy.editNews(updated.toEditBody());
    await _clearCache();
  }

  Future<void> deleteNews(String id) async {
    await _proxy.deleteNews(id);
    await _clearCache();
  }

  // ---------------------------------------------------------------------
  // Hive cache helpers (Tier 2 of the 4-tier pyramid, §6.2)
  // ---------------------------------------------------------------------

  Future<void> _writeCache(List<NewsModel> news) async {
    final box = await Hive.openBox(_boxName);
    final payload = {
      'cached_at': DateTime.now().millisecondsSinceEpoch,
      'items': news
          .map((n) => {
                'id': n.id,
                'title': n.title,
                'body': n.body,
                'image_url': n.imageUrl,
                'posted_by': n.postedByUid,
                'posted_by_name': n.postedByName,
                'posted_by_batch': n.postedByBatch,
                'posted_at': n.postedAt.toIso8601String(),
                'auto_delete_days': n.autoDeleteDays.toString(),
              })
          .toList(),
    };
    await box.put(_cacheKey, jsonEncode(payload));
  }

  Future<List<NewsModel>?> _readCache() async {
    try {
      final box = await Hive.openBox(_boxName);
      final raw = box.get(_cacheKey);
      if (raw == null) return null;

      final decoded = jsonDecode(raw as String) as Map<String, dynamic>;
      final cachedAt = decoded['cached_at'] as int? ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - cachedAt;
      if (age > _cacheTtl.inMilliseconds) return null; // stale — treat as miss

      final items = (decoded['items'] as List)
          .map((m) => NewsModel.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList();
      return items;
    } catch (_) {
      return null; // corrupted cache — fall through to network, same as
      // StatsRepository's `_readCache()` pattern (Architecture §8.3).
    }
  }

  Future<void> _clearCache() async {
    try {
      final box = await Hive.openBox(_boxName);
      await box.delete(_cacheKey);
    } catch (_) {
      // best-effort — a failed cache clear shouldn't block the caller from
      // knowing their post/edit/delete already succeeded server-side.
    }
  }
}
