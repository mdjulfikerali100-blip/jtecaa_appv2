// lib/data/datasources/external/google_sheets_proxy.dart
//
// HTTP client for the Jobs + News Google Apps Script backend
// (Architecture Appendix I.4/I.5).
//
// ⚠️ SCOPE CHANGE (per explicit user decision): originally this single
// class also handled Student endpoints (§M.4), matching Architecture's
// "same Google Sheet used for Jobs/News" design. The user has since asked
// for Students to live in a COMPLETELY SEPARATE Google Sheet file with
// its own Apps Script deployment/Web App URL — see
// student_sheets_proxy.dart for that half. This file now handles ONLY
// Jobs + News, which stay together in one Sheet file as Architecture
// §5.2 originally specified.
//
// ⚠️ `_baseUrl` is a placeholder — fill it in with the Jobs+News
// spreadsheet's deployed Apps Script Web App URL (Appendix I.2, Step 6)
// once Phase 11 deploys that Code.gs. Every method below will throw a
// clear SheetsProxyException until this is set, rather than failing with
// a confusing DNS error.

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../core/errors/exceptions.dart';

class GoogleSheetsProxy {
  // TODO(Phase 11): replace with the Jobs+News spreadsheet's Apps Script
  // Web App URL (Appendix I.2, Step 6). This is now a DIFFERENT
  // deployment from the Students sheet (see student_sheets_proxy.dart).
  static const String _baseUrl = 'YOUR_JOBS_NEWS_WEB_APP_URL_HERE';

  static const Duration _timeout = Duration(seconds: 20);

  bool get isConfigured =>
      !_baseUrl.contains('YOUR_JOBS_NEWS_WEB_APP_URL_HERE');

  Uri _uri(String action, [Map<String, String>? extraParams]) {
    return Uri.parse(_baseUrl).replace(queryParameters: {
      'action': action,
      ...?extraParams,
    });
  }

  Future<Map<String, dynamic>> _get(String action,
      [Map<String, String>? params]) async {
    _assertConfigured();
    try {
      final response = await http.get(_uri(action, params)).timeout(_timeout);
      return _decode(response);
    } catch (e) {
      throw SheetsProxyException('Failed to reach Jobs/News service: $e');
    }
  }

  Future<Map<String, dynamic>> _post(
      String action, Map<String, dynamic> body) async {
    _assertConfigured();
    try {
      final response = await http
          .post(
            _uri(action),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      return _decode(response);
    } catch (e) {
      throw SheetsProxyException('Failed to reach Jobs/News service: $e');
    }
  }

  void _assertConfigured() {
    if (!isConfigured) {
      throw const SheetsProxyException(
        'Jobs/News Sheets proxy URL is not configured yet — set '
        'GoogleSheetsProxy._baseUrl after deploying the Jobs+News Code.gs '
        '(Appendix I.2).',
      );
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || body['success'] != true) {
      throw SheetsProxyException(body['error']?.toString() ?? 'Request failed');
    }
    return body;
  }

  // ---------------------------------------------------------------------
  // JOBS
  // ---------------------------------------------------------------------

  Future<List<dynamic>> getJobs() async {
    final body = await _get('getJobs');
    return body['data'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>?> getJobById(String id) async {
    final body = await _get('getJobById', {'id': id});
    return body['data'] as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>> postJob(Map<String, dynamic> jobData) =>
      _post('postJob', jobData);

  Future<Map<String, dynamic>> editJob(Map<String, dynamic> jobData) =>
      _post('editJob', jobData);

  Future<Map<String, dynamic>> deleteJob(String id) =>
      _post('deleteJob', {'id': id});

  // ---------------------------------------------------------------------
  // NEWS
  // ---------------------------------------------------------------------

  Future<List<dynamic>> getNews() async {
    final body = await _get('getNews');
    return body['data'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>?> getNewsById(String id) async {
    final body = await _get('getNewsById', {'id': id});
    return body['data'] as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>> postNews(Map<String, dynamic> newsData) =>
      _post('postNews', newsData);

  Future<Map<String, dynamic>> editNews(Map<String, dynamic> newsData) =>
      _post('editNews', newsData);

  Future<Map<String, dynamic>> deleteNews(String id) =>
      _post('deleteNews', {'id': id});

  // ---------------------------------------------------------------------
  // IMAGES (Appendix I.7) — profile photos live in Google Drive, served
  // through this SAME Apps Script deployment (not a separate one) since
  // Appendix I.7 explicitly adds these functions to the same Code.gs as
  // Jobs+News. There is no dedicated "Images" spreadsheet — Drive is the
  // storage, this Web App is purely a CORS-safe proxy in front of it.
  // ---------------------------------------------------------------------

  /// Appendix I.7.3 `uploadImage` — returns `{fileId, directUrl}`.
  Future<Map<String, dynamic>> uploadImage({
    required String base64,
    required String filename,
    required String mimeType,
  }) async {
    final body = await _post('uploadImage', {
      'base64': base64,
      'filename': filename,
      'mimeType': mimeType,
    });
    return body['data'] as Map<String, dynamic>;
  }

  /// Appendix I.7.3 `getImage` — the Reverse CORS Proxy. Returns
  /// `{fileId, mimeType, base64, fetchedAt}`.
  Future<Map<String, dynamic>> getImage(String fileId) async {
    final body = await _get('getImage', {'fileId': fileId});
    return body['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> deleteImage(String fileId) =>
      _post('deleteImage', {'fileId': fileId});
}
