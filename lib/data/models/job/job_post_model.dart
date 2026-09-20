// lib/data/models/job/job_post_model.dart
//
// Architecture Appendix L.2.1 — job data as returned by the Google Sheets
// proxy (Appendix I). Not a Firestore model — Jobs live entirely in
// Sheets (§5), never in Firestore, so there's no toMap()/toFirestore()
// here, only fromMap() for parsing the proxy's JSON response.

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
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      company: map['company'] as String? ?? '',
      description: map['description'] as String?,
      deadline: map['deadline'] as String? ?? '',
      applyLink: map['apply_link'] as String?,
      applyEmail: map['apply_email'] as String?,
      applyPhone: map['apply_phone'] as String?,
      applyWhatsapp: map['apply_whatsapp'] as String?,
      postedByUid: map['posted_by'] as String? ?? '',
      // ⚠️ Fallback 'Alumni' matches Appendix L.2.1's JobPostModel default
      // — a row posted before this column existed must still render.
      postedByName: map['posted_by_name'] as String? ?? 'Alumni',
      postedByBatch: map['posted_by_batch'] as String? ?? '',
      postedAt: DateTime.tryParse(map['posted_at'] as String? ?? '') ??
          DateTime.now(),
      autoDeleteDays: int.tryParse('${map['auto_delete_days'] ?? 7}') ?? 7,
    );
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
