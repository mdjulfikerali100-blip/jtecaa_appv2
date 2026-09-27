// lib/data/datasources/external/student_sheets_proxy.dart
//
// HTTP client for the Student role's Google Apps Script backend (§M.4).
//
// ⚠️ DEVIATION FROM ARCHITECTURE (explicit user decision, this session):
// §M.4 originally says the Students tab lives in "the same Google Sheet
// used for Jobs/News" — one spreadsheet, one Apps Script deployment. The
// user has instead asked for Students to live in a COMPLETELY SEPARATE
// Google Sheet file, with its own independent Apps Script Web App
// deployment/URL. This class is that separate proxy — it is a sibling of
// GoogleSheetsProxy (Jobs+News), not a shared class with it, so the two
// can point at two different deployed Web Apps without any risk of a
// Student request accidentally hitting the Jobs+News spreadsheet or
// vice versa.
//
// Phase 11 will need to generate a SECOND, separate Code.gs (containing
// only §M.4's createStudent/updateStudent/getStudentByUid/deleteStudent/
// cleanExpiredStudents functions — none of the Jobs/News functions) and
// deploy it as its own Web App, to get the URL this file's `_baseUrl`
// needs.

import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../../../core/errors/exceptions.dart';

class StudentSheetsProxy {
  // TODO(Phase 11): replace with the Students spreadsheet's own,
  // independently-deployed Apps Script Web App URL — NOT the same URL as
  // GoogleSheetsProxy's Jobs+News deployment.
  static const String _baseUrl =
      'https://script.google.com/macros/s/AKfycbwbnBSOZkO1ua-NehRuV1tqYcxqAUpe2NgeI_sXV075fxepiKmumiRNto5e6lQBhso6gA/exec';

  static const Duration _timeout = Duration(seconds: 20);

  bool get isConfigured => !_baseUrl.contains('YOUR_STUDENTS_WEB_APP_URL_HERE');

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
      throw SheetsProxyException('Failed to reach Student service: $e');
    }
  }

  Future<Map<String, dynamic>> _post(
      String action, Map<String, dynamic> body) async {
    _assertConfigured();
    try {
      // ⚠️ WEB FIX: see google_sheets_proxy.dart's identical comment —
      // 'application/json' triggers a CORS preflight (OPTIONS) that Apps
      // Script cannot answer (no doOptions()); 'text/plain' is a
      // CORS-simple Content-Type, so no preflight is sent. Safe on every
      // platform since Apps Script reads the raw body regardless.
      final request = http.Request('POST', _uri(action))
        ..headers['Content-Type'] = 'text/plain;charset=utf-8'
        ..body = jsonEncode(body);
      final response = await _sendFollowingRedirects(request).timeout(_timeout);
      return _decode(response);
    } catch (e) {
      throw SheetsProxyException('Failed to reach Student service: $e');
    }
  }

  /// ⚠️ BUG FIX (native platforms) + WEB FIX — identical fix and
  /// reasoning as `google_sheets_proxy.dart`'s own version of this
  /// method: on native (Android/iOS), Apps Script's 302 redirect is
  /// followed manually since dart:io's automatic follow didn't reliably
  /// carry a POST through it. On Web, `package:http` uses a
  /// browser-native `fetch()`/XHR that follows redirects itself before
  /// Dart ever sees a response — there is nothing to manually intercept
  /// there, so this method just sends the request as-is on Web.
  ///
  /// ⚠️ HONEST CAVEAT: avoiding the CORS preflight (via `text/plain`
  /// above) does not by itself guarantee the browser will let Dart code
  /// read the final response body — that also requires Google's redirect
  /// target to return `Access-Control-Allow-Origin`, which is outside
  /// this app's control. See `google_sheets_proxy.dart`'s identical note.
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
        'Student Sheets proxy URL is not configured yet — set '
        'StudentSheetsProxy._baseUrl after deploying the Students-only '
        'Code.gs (Phase 11) as its own separate Web App.',
      );
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    // ⚠️ Defense-in-depth alongside the redirect fix above — see
    // google_sheets_proxy.dart's identical check for the full reasoning.
    if (response.body.isEmpty) {
      throw SheetsProxyException(
        'Empty response from the Student service (HTTP ${response.statusCode}). '
        'On Android/iOS this usually means the Apps Script Web App isn\'t '
        'deployed with "Who has access: Anyone", or the URL in '
        'StudentSheetsProxy._baseUrl is stale. On Web, this can also mean '
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
  // STUDENTS (§M.4)
  // ---------------------------------------------------------------------

  Future<Map<String, dynamic>> createStudent(
          Map<String, dynamic> studentData) =>
      _post('createStudent', studentData);

  Future<Map<String, dynamic>> updateStudent(
    String uid,
    Map<String, dynamic> changedFields,
  ) =>
      _post('updateStudent', {'uid': uid, ...changedFields});

  Future<Map<String, dynamic>?> getStudentByUid(String uid) async {
    final body = await _get('getStudentByUid', {'uid': uid});
    return body['data'] as Map<String, dynamic>?;
  }

  /// Used only by the account-deletion flow (§M.10) — not part of normal
  /// signup/update usage.
  Future<Map<String, dynamic>> deleteStudent(String uid) =>
      _post('deleteStudent', {'uid': uid});
}
