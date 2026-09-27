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
import 'package:http/http.dart' as http;

import '../../../core/errors/exceptions.dart';

class StudentSheetsProxy {
  // independently-deployed Apps Script Web App URL — NOT the same URL as
  // GoogleSheetsProxy's Jobs+News deployment.
  static const String _baseUrl =
      'https://script.google.com/macros/s/AKfycbzJLNFiskJa5gOz-tw1M8SG5DL94B0ciJ3iRC1skb8UutYv2PT5skXCQ81y588KUCmwpA/exec';

  static const Duration _timeout = Duration(seconds: 20);

  bool get isConfigured => !_baseUrl.contains(
      'https://script.google.com/macros/s/AKfycbzJLNFiskJa5gOz-tw1M8SG5DL94B0ciJ3iRC1skb8UutYv2PT5skXCQ81y588KUCmwpA/exec');

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
      throw SheetsProxyException('Failed to reach Student service: $e');
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
      throw SheetsProxyException('Failed to reach Student service: $e');
    }
  }

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
