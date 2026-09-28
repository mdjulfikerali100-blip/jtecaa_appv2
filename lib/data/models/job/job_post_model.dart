// lib/data/models/job/job_post_model.dart
//
// Architecture Appendix L.2.1 — job data as returned by the Google Sheets
// proxy (Appendix I). Not a Firestore model — Jobs live entirely in
// Sheets (§5), never in Firestore, so there's no toMap()/toFirestore()
// here, only fromMap() for parsing the proxy's JSON response.
//
// ⚠️ BUG FIX (root cause): every field below used to be parsed with a
// direct `map['x'] as String?` cast. Google Sheets auto-detects a cell's
// type from what's typed into it — a phone number entered without first
// setting the column to "Plain Text" format gets silently converted to a
// NUMBER (and its leading 0 permanently stripped in the process, e.g.
// "01788091669" -> 1788091669). Apps Script's `getValues()` then returns
// a JS number for that cell, `JSON.stringify()` emits it unquoted, and
// `jsonDecode()` on the Dart side produces a plain `int` — so
// `map['apply_phone'] as String?` threw `type 'int' is not a subtype of
// type 'String?'` the moment any phone-like field was actually a number
// rather than a string. This is Architecture's own documented "Leading
// Zero Fix" (Feature #42, marked as required), which had not actually
// been applied here yet. Every field is now read through `_asString()`
// below instead — the exact same `.toString()`-based defensive pattern
// `news_model.dart` already used safely (which is why News never hit
// this bug, only Jobs did).
class JobPostModel {
  final String id;
  final String title;
  final String company;
  final String? description;
  final String deadline; // ISO date string, e.g. "2026-08-15"
  final String? applyLink;
  final String? applyEmail;
  final String? applyPhone;
  final String? applyWhatsapp;
  final String postedByUid;
  final String postedByName; // Appendix L.2.1 — "Posted by: [Name] (Batch)"
  final String postedByBatch;
  final DateTime postedAt;
  final int autoDeleteDays;

  JobPostModel({
    required this.id,
    required this.title,
    required this.company,
    this.description,
    required this.deadline,
    this.applyLink,
    this.applyEmail,
    this.applyPhone,
    this.applyWhatsapp,
    required this.postedByUid,
    required this.postedByName,
    required this.postedByBatch,
    required this.postedAt,
    this.autoDeleteDays = 7,
  });

  /// True if at least one apply method exists — mirrors the "minimum 1
  /// required" validation enforced at post-time (Architecture §7.5).
  bool get hasApplyMethod =>
      (applyLink?.isNotEmpty ?? false) ||
      (applyEmail?.isNotEmpty ?? false) ||
      (applyPhone?.isNotEmpty ?? false) ||
      (applyWhatsapp?.isNotEmpty ?? false);

  /// Deadline + 5h grace period, matching the Apps Script auto-delete rule
  /// (Architecture §7.5) — used by the UI to show a "deadline passed" state
  /// even before the daily cleanup trigger has run.
  bool get isExpired {
    final parsedDeadline = DateTime.tryParse(deadline);
    if (parsedDeadline == null) return false;
    return DateTime.now().isAfter(parsedDeadline.add(const Duration(hours: 5)));
  }

  factory JobPostModel.fromMap(Map<String, dynamic> map) {
    return JobPostModel(
      id: _asString(map['id']) ?? '',
      title: _asString(map['title']) ?? '',
      company: _asString(map['company']) ?? '',
      description: _asString(map['description']),
      deadline: _asString(map['deadline']) ?? '',
      applyLink: _asString(map['apply_link']),
      applyEmail: _asString(map['apply_email']),
      // ⚠️ THE ACTUAL FIX for this bug report: these two are the fields
      // most likely to have been auto-converted to a Sheets Number
      // (phone-like values). `_asString()` accepts either a String OR a
      // num from jsonDecode and coerces it — this stops the crash for
      // ANY row, old or new. It CANNOT restore a leading zero that
      // Sheets already destroyed on a pre-existing row, though — see the
      // remediation note in this session's reply for fixing the sheet
      // itself.
      applyPhone: _asString(map['apply_phone']),
      applyWhatsapp: _asString(map['apply_whatsapp']),
      postedByUid: _asString(map['posted_by']) ?? '',
      // ⚠️ Fallback 'Alumni' matches Appendix L.2.1's JobPostModel default
      // — a row posted before this column existed must still render.
      postedByName: _asString(map['posted_by_name']) ?? 'Alumni',
      postedByBatch: _asString(map['posted_by_batch']) ?? '',
      postedAt: DateTime.tryParse(_asString(map['posted_at']) ?? '') ??
          DateTime.now(),
      autoDeleteDays: int.tryParse('${map['auto_delete_days'] ?? 7}') ?? 7,
    );
  }

  /// Coerces any JSON-decoded value (String, num, bool) into a String,
  /// treating null and empty strings alike as "absent" (`null`). This is
  /// the fix: a direct `as String?` cast throws the instant a Sheets cell
  /// was auto-typed as a Number; `.toString()` on a `num` always
  /// succeeds, and on an already-`String` value is a harmless no-op.
  static String? _asString(dynamic value) {
    if (value == null) return null;
    final str = value.toString();
    return str.isEmpty ? null : str;
  }

  /// Request body shape for `action=postJob` (Appendix I.4) — the
  /// `posted_by_name`/`posted_by_batch` values are filled by the caller
  /// from the poster's own cached profile, per Appendix L.2.1's
  /// "client computes, server just stores" pattern.
  static Map<String, dynamic> toPostBody({
    required String title,
    required String company,
    String? description,
    required String deadline,
    String? applyLink,
    String? applyEmail,
    String? applyPhone,
    String? applyWhatsapp,
    required String postedByUid,
    required String postedByName,
    required String postedByBatch,
    int autoDeleteDays = 7,
  }) {
    return {
      'title': title,
      'company': company,
      'description': description ?? '',
      'deadline': deadline,
      'apply_link': applyLink ?? '',
      'apply_email': applyEmail ?? '',
      // ⚠️ Sent as plain JSON strings here already (Dart's ?? '' keeps
      // these String-typed) — the corruption happens Sheets-side when
      // Apps Script's `appendRow()` writes them into an auto-formatted
      // column, not on this end. See Code.gs's `postJob()` for the
      // companion fix that stops Sheets from re-typing these as numbers.
      'apply_phone': applyPhone ?? '',
      'apply_whatsapp': applyWhatsapp ?? '',
      'posted_by': postedByUid,
      'posted_by_name': postedByName,
      'posted_by_batch': postedByBatch,
      'auto_delete_days': '$autoDeleteDays',
    };
  }

  /// Request body shape for `action=editJob` (Appendix I.1's `editJob()`).
  /// ⚠️ Deliberately does NOT include `posted_by`/`posted_by_name`/
  /// `posted_by_batch` — the Apps Script `editJob()` function only ever
  /// updates title/company/description/deadline/apply_* columns for the
  /// matched row (Appendix I.1's exact code), so the original poster's
  /// identity is preserved automatically; sending it again would just be
  /// redundant, not wrong, but omitting it keeps this body's shape an
  /// honest match of what the endpoint actually consumes.
  static Map<String, dynamic> toEditBody({
    required String id,
    required String title,
    required String company,
    String? description,
    required String deadline,
    String? applyLink,
    String? applyEmail,
    String? applyPhone,
    String? applyWhatsapp,
  }) {
    return {
      'id': id,
      'title': title,
      'company': company,
      'description': description ?? '',
      'deadline': deadline,
      'apply_link': applyLink ?? '',
      'apply_email': applyEmail ?? '',
      'apply_phone': applyPhone ?? '',
      'apply_whatsapp': applyWhatsapp ?? '',
    };
  }
}
