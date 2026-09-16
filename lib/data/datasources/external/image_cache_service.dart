// lib/data/datasources/external/image_cache_service.dart
//
// Architecture Appendix J.1 — Hive disk cache for image bytes (Tier 2 of
// the image caching pyramid, §5.4). Key = Drive fileId. TTL = 30 days.

import 'dart:typed_data';

import '../../../core/constants/cache_keys.dart';
import '../local/hive_service.dart';

class ImageCacheService {
  static Future<Uint8List?> get(String fileId) async {
    if (fileId.isEmpty) {
      return null;
    }
    final raw = HiveService.get(CacheKeys.imageCacheBox, fileId);
    if (raw == null) {
      return null;
    }
    try {
      final entry = raw as Map;
      final savedAt = entry['t'] as int? ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - savedAt;
      if (age > CacheKeys.imageCacheTtl.inMilliseconds) {
        await HiveService.delete(CacheKeys.imageCacheBox, fileId); // expired
        return null;
      }
      final bytes = (entry['b'] as List?)?.cast<int>();
      return bytes != null ? Uint8List.fromList(bytes) : null;
    } catch (_) {
      return null; // corrupted entry — treat as a miss, not a crash
    }
  }

  static Future<void> put(String fileId, Uint8List bytes) async {
    if (fileId.isEmpty) {
      return;
    }
    await HiveService.put(CacheKeys.imageCacheBox, fileId, {
      'b': bytes.toList(),
      't': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Future<void> remove(String fileId) async {
    await HiveService.delete(CacheKeys.imageCacheBox, fileId);
  }
}
