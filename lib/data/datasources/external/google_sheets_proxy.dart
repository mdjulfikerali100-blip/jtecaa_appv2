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
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../../../core/errors/exceptions.dart';

class GoogleSheetsProxy {
  // Web App URL (Appendix I.2, Step 6). This is now a DIFFERENT
  // deployment from the Students sheet (see student_sheets_proxy.dart).
  static const String _baseUrl =
      'https://script.google.com/macros/s/AKfycbwARB5WsyQS3UcPpQirVZHyQUabv7ejonYBA534i3tlNZk5zegjT1ysxYA7bXHhYXg/exec';

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
      final request = http.Request('GET', _uri(action, params));
      final response = await _sendFollowingRedirects(request).timeout(_timeout);
      return _decode(response);
    } catch (e) {
      throw SheetsProxyException('Failed to reach Jobs/News service: $e');
    }
  }

  Future<Map<String, dynamic>> _post(
      String action, Map<String, dynamic> body) async {
    _assertConfigured();
    try {
      // ⚠️ WEB FIX: 'application/json' is a non-simple Content-Type, so a
      // browser sends a CORS preflight (OPTIONS) request first — but Apps
      // Script has no doOptions() handler, so that preflight always fails
      // and the real POST never goes out at all (surfaces as "Failed to
      // fetch"). 'text/plain;charset=utf-8' is one of the fetch spec's
      // CORS-simple Content-Types, so no preflight is sent. Apps Script's
      // doPost(e) reads the raw body via `e.postData.contents` regardless
      // of the declared Content-Type — JSON.parse() on the server side
      // works identically either way — so this is safe on every platform,
      // not just Web.
      final request = http.Request('POST', _uri(action))
        ..headers['Content-Type'] = 'text/plain;charset=utf-8'
        ..body = jsonEncode(body);
      final response = await _sendFollowingRedirects(request).timeout(_timeout);
      return _decode(response);
    } catch (e) {
      throw SheetsProxyException('Failed to reach Jobs/News service: $e');
    }
  }

  /// ⚠️ BUG FIX (root cause of "FormatException: Unexpected end of input
  /// (at character 1)" on NATIVE platforms): a deployed Apps Script Web
  /// App's `/exec` URL always responds with an HTTP 302 redirect — the
  /// real JSON body lives at a separate `script.googleusercontent.com`
  /// URL given in the `Location` header. `package:http`'s automatic
  /// redirect-following (via dart:io on Android/iOS) does not reliably
  /// carry a POST through this specific redirect chain, so redirects are
  /// followed manually below with a fresh GET to each `Location` header.
  ///
  /// ⚠️ WEB FIX (added — see the ClientException:"Failed to fetch" report):
  /// on Flutter Web, `package:http` uses a `BrowserClient` that wraps the
  /// browser's native `fetch()`/`XMLHttpRequest`, NOT dart:io. Browsers
  /// follow redirects themselves, transparently, before Dart code ever
  /// sees a response — `http.Request.followRedirects = false` has no
  /// effect there and there is no way to intercept a redirect hop from
  /// Dart running in a browser. So on Web this method does NOT attempt
  /// the manual-follow trick at all; it just sends the request and lets
  /// the browser do what it already does. What made this fail before was
  /// a CORS preflight being rejected (fixed above via `text/plain`), not
  /// the redirect itself.
  ///
  /// ⚠️ HONEST CAVEAT (not glossed over): avoiding the preflight does NOT
  /// by itself guarantee the browser will let Dart code READ the final
  /// response body — that additionally requires the redirect TARGET
  /// (`script.googleusercontent.com`, a Google-controlled server) to
  /// return an `Access-Control-Allow-Origin` header on ITS response. This
  /// is Google's server behavior, outside this app's control, and reports
  /// on this vary. If calls still fail on Web after this fix, the next
  /// step is a small CORS-forwarding proxy in front of Apps Script — not
  /// something fixable from the Flutter side alone.
  Future<http.Response> _sendFollowingRedirects(http.Request request) async {
    if (kIsWeb) {
      final client = http.Client();
      try {
        return await http.Response.fromStream(await client.send(request));
      } finally {
        client.close();
      }
    }

    request.followRedirects = false;
    final client = http.Client();
    try {
      var response = await http.Response.fromStream(await client.send(request));
      var hops = 0;
      while (_isRedirect(response.statusCode) && hops < 5) {
        final location = response.headers['location'];
        if (location == null) break;
        final redirectRequest = http.Request('GET', Uri.parse(location));
        response =
            await http.Response.fromStream(await client.send(redirectRequest));
        hops++;
      }
      return response;
    } finally {
      client.close();
    }
  }

  bool _isRedirect(int statusCode) =>
      statusCode == 301 || statusCode == 302 || statusCode == 303;

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
    // ⚠️ Defense-in-depth alongside the redirect fix above: if a response
    // is STILL empty for any other reason (deployment set to "Only
    // myself" instead of "Anyone", a since-deleted/re-deployed URL,
    // etc.), surface an actionable message instead of the cryptic
    // FormatException that was previously the only symptom ever seen.
    if (response.body.isEmpty) {
      throw SheetsProxyException(
        'Empty response from the Jobs/News service (HTTP ${response.statusCode}). '
        'On Android/iOS this usually means the Apps Script Web App isn\'t '
        'deployed with "Who has access: Anyone", or the URL in '
        'GoogleSheetsProxy._baseUrl is stale. On Web, this can also mean '
        'the browser blocked reading the response due to CORS on Google\'s '
        'redirect target — a CORS-forwarding proxy may be needed in front '
        'of Apps Script for Web support.',
      );
    }
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
