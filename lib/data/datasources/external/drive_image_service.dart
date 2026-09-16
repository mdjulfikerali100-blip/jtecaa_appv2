// lib/data/datasources/external/drive_image_service.dart
//
// Architecture Appendix J.2 — upload + fetch through the Apps Script
// reverse-CORS proxy (Appendix I.7), RAM-first then Hive-disk caching.
//
// ⚠️ ADAPTED from Appendix J.2's original code: that version made its own
// raw `http` calls against a separate `_baseUrl` constant. Since the
// image endpoints (Appendix I.7) live in the SAME Apps Script deployment
// as Jobs+News (not a separate one — see google_sheets_proxy.dart's
// comment), this service calls through `GoogleSheetsProxy` instead of
// duplicating URL-building/error-handling logic in a third place.

import 'dart:convert';
import 'dart:typed_data';

import '../../../core/errors/exceptions.dart';
import 'google_sheets_proxy.dart';
import 'image_cache_service.dart';

class DriveImageData {
  final Uint8List bytes;
  final String mimeType;
  DriveImageData(this.bytes, this.mimeType);
}

class DriveImageService {
  final GoogleSheetsProxy _proxy;

  DriveImageService(this._proxy);

  /// Tier-1 RAM cache: fileId -> bytes (session lifetime). Static so it
  /// survives across widget rebuilds without needing a Provider of its
  /// own — matches Appendix J.2's original in-memory-map design.
  static final Map<String, DriveImageData> _ramCache = {};

  // ---------------------- FETCH (render path) ----------------------

  Future<DriveImageData> getImage(String fileId) async {
    final ram = _ramCache[fileId];
    if (ram != null) {
      return ram;
    }

    final disk = await ImageCacheService.get(fileId);
    if (disk != null) {
      final data = DriveImageData(disk, 'image/jpeg');
      _ramCache[fileId] = data;
      return data;
    }

    try {
      final result = await _proxy.getImage(fileId);
      final base64Str = result['base64'] as String;
      final mimeType = result['mimeType'] as String? ?? 'image/jpeg';
      final bytes = base64Decode(base64Str);

      final data = DriveImageData(bytes, mimeType);
      _ramCache[fileId] = data;
      await ImageCacheService.put(fileId, bytes);
      return data;
    } catch (e) {
      throw NetworkException('Could not load image: $e');
    }
  }

  // ---------------------- UPLOAD (profile photo path) ----------------------

  Future<String> uploadImage({
    required Uint8List bytes,
    required String filename,
    String mimeType = 'image/jpeg',
  }) async {
    try {
      final result = await _proxy.uploadImage(
        base64: base64Encode(bytes),
        filename: filename,
        mimeType: mimeType,
      );
      final fileId = result['fileId'] as String;

      // Prime caches so the new photo renders instantly, without waiting
      // for a round-trip through getImage().
      final data = DriveImageData(bytes, mimeType);
      _ramCache[fileId] = data;
      await ImageCacheService.put(fileId, bytes);

      return fileId;
    } catch (e) {
      throw NetworkException('Could not upload photo: $e');
    }
  }

  Future<void> deleteImage(String fileId) async {
    _ramCache.remove(fileId);
    await ImageCacheService.remove(fileId);
    try {
      await _proxy.deleteImage(fileId);
    } catch (_) {
      // Best-effort — a failed remote delete (e.g. already gone, network
      // hiccup) shouldn't block the user from finishing their profile
      // update; the orphaned Drive file is a storage-cost concern, not a
      // correctness one.
    }
  }

  /// Evicts from RAM + Hive without deleting the remote file — used when
  /// a photo reference changes locally (e.g. profile edit cancelled after
  /// a preview) but the Drive file itself should stay.
  Future<void> evictCache(String fileId) async {
    _ramCache.remove(fileId);
    await ImageCacheService.remove(fileId);
  }
}
