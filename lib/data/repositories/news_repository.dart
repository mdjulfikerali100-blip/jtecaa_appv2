// lib/data/repositories/news_repository.dart
//
// Architecture §5.3 (Sheets proxy + Hive cache) + §7.6 (News) + Appendix
// L.2.1 ("Posted by" fields). Mirrors job_repository.dart's structure —
// News lives entirely in Google Sheets, never Firestore.

import 'dart:convert';

import '../../core/constants/cache_keys.dart';
import '../datasources/external/google_sheets_proxy.dart';
import '../datasources/local/hive_service.dart';
import '../models/news/news_model.dart';

class NewsRepository {
  final GoogleSheetsProxy _proxy;
  static const String _cacheKey = 'news_list_v1';

  NewsRepository(this._proxy);

  Future<List<NewsPostModel>> getActiveNews({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _readFromCache();
      if (cached != null) return cached;
    }

    final raw = await _proxy.getNews();
    final news = raw
        .map((n) => NewsPostModel.fromMap(n as Map<String, dynamic>))
        .where((n) => !n.isExpired)
        .toList();

    await _writeToCache(news);
    return news;
  }

  Future<Map<String, dynamic>> postNews(Map<String, dynamic> newsData) async {
    final result = await _proxy.postNews(newsData);
    await _invalidateCache();
    return result;
  }

  Future<Map<String, dynamic>> editNews(Map<String, dynamic> newsData) async {
    final result = await _proxy.editNews(newsData);
    await _invalidateCache();
    return result;
  }

  Future<Map<String, dynamic>> deleteNews(String id) async {
    final result = await _proxy.deleteNews(id);
    await _invalidateCache();
    return result;
  }

  List<NewsPostModel>? _readFromCache() {
    final raw = HiveService.get(CacheKeys.newsCacheBox, _cacheKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw as String) as Map<String, dynamic>;
      final cachedAt = decoded['cachedAt'] as int? ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - cachedAt;
      if (age > CacheKeys.jobsNewsTtl.inMilliseconds) return null;
      return (decoded['data'] as List)
          .map((n) => NewsPostModel.fromMap(n as Map<String, dynamic>))
          .where((n) => !n.isExpired)
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeToCache(List<NewsPostModel> newsList) async {
    final serializable = newsList
        .map((n) => {
              'id': n.id,
              'title': n.title,
              'body': n.body,
              'image_url': n.imageUrl,
              'posted_by': n.postedByUid,
              'posted_by_name': n.postedByName,
              'posted_by_batch': n.postedByBatch,
              'posted_at': n.postedAt.toIso8601String(),
              'auto_delete_days': n.autoDeleteDays,
            })
        .toList();
    await HiveService.put(
      CacheKeys.newsCacheBox,
      _cacheKey,
      jsonEncode({
        'data': serializable,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  Future<void> _invalidateCache() async {
    await HiveService.delete(CacheKeys.newsCacheBox, _cacheKey);
  }
}
