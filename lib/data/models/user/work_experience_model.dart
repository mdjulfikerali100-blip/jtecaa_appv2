// lib/data/models/user/work_experience_model.dart
//
// Full professional history entry — Architecture Appendix A.
//
// ⚠️ Uses `startDate`/`endDate` (nullable = still running) instead of a
// free-text `duration` string ("2015-2018") so `WorkExperienceCalculator`
// below can sum real spans accurately — a free-text field can't be summed
// reliably (ambiguous months, overlapping ranges, "Present" as plain text,
// etc). See Appendix L.1.5 for the calculation that consumes this.

import 'package:intl/intl.dart';

class WorkExperience {
  final String companyType;
  final String? groupOfCompanies;
  final String companyName;
  final String designation;
  final String jobDepartment;
  final DateTime startDate;
  final DateTime? endDate; // null = currently running ("Present")

  WorkExperience({
    required this.companyType,
    this.groupOfCompanies,
    required this.companyName,
    required this.designation,
    required this.jobDepartment,
    required this.startDate,
    this.endDate,
  });

  /// Human-readable duration label, e.g. "Mar 2015 — Jun 2018" or
  /// "Mar 2018 — Present". Purely for display — never parsed back.
  String get durationLabel {
    final fmt = DateFormat('MMM yyyy');
    final start = fmt.format(startDate);
    final end = endDate != null ? fmt.format(endDate!) : 'Present';
    return '$start — $end';
  }

  /// Duration of just this one entry, clamped so a bad/future date never
  /// produces a negative span (e.g. a corrupted `sd`/`ed` pair from an old
  /// manual Firestore edit).
  Duration get span {
    final end = endDate ?? DateTime.now();
    final diff = end.difference(startDate);
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Short Firestore keys (Architecture §4.1 "Short Keys" cost rule).
  /// `sd`/`ed` stored as Unix seconds — consistent with the rest of the
  /// schema's "int instead of Timestamp" convention.
  Map<String, dynamic> toMap() => {
        'ct': companyType,
        'gco': groupOfCompanies,
        'co': companyName,
        'des': designation,
        'jd': jobDepartment,
        'sd': startDate.millisecondsSinceEpoch ~/ 1000,
        'ed': endDate != null ? endDate!.millisecondsSinceEpoch ~/ 1000 : null,
      };

  factory WorkExperience.fromMap(Map<String, dynamic> map) => WorkExperience(
        companyType: map['ct'] as String? ?? 'Others',
        groupOfCompanies: map['gco'] as String?,
        companyName: map['co'] as String? ?? '',
        designation: map['des'] as String? ?? '',
        jobDepartment: map['jd'] as String? ?? 'Others',
        // ⚠️ Null-safety: fall back to "now" rather than force-unwrapping
        // `map['sd']!` — a malformed/legacy document must never crash the
        // whole directory list over one bad record.
        startDate: map['sd'] != null
            ? DateTime.fromMillisecondsSinceEpoch((map['sd'] as int) * 1000)
            : DateTime.now(),
        endDate: map['ed'] != null
            ? DateTime.fromMillisecondsSinceEpoch((map['ed'] as int) * 1000)
            : null,
      );
}

/// Sums every `WorkExperience.span` into a single "X yrs Y mos" label for
/// the profile card / directory card, shown next to the Blood Group badge
/// (Appendix L.1.5).
class WorkExperienceCalculator {
  static String totalExperienceLabel(List<WorkExperience> experiences) {
    if (experiences.isEmpty) return 'No experience yet';

    final totalDays = experiences.fold<int>(
      0,
      (sum, w) => sum + w.span.inDays,
    );

    final totalYears = totalDays ~/ 365;
    final remMonths = (totalDays % 365) ~/ 30;

    if (totalYears == 0 && remMonths == 0) return '< 1 month';
    if (totalYears == 0) return '$remMonths mo${remMonths > 1 ? 's' : ''}';
    if (remMonths == 0) return '$totalYears yr${totalYears > 1 ? 's' : ''}';
    return '$totalYears yr${totalYears > 1 ? 's' : ''} $remMonths mo${remMonths > 1 ? 's' : ''}';
  }
}
