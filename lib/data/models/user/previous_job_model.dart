// lib/data/models/user/previous_job_model.dart
//
// ⚠️ LEGACY (Architecture Appendix A: "Legacy — migrate to
// workExperience"). Kept only so old `users_private` documents written
// before the WorkExperience system existed still deserialize without
// crashing. Do NOT use this class for any new feature — use
// `WorkExperience` (work_experience_model.dart) instead.

class PreviousJob {
  final String company;
  final String designation;
  final String sector;
  final String years;

  PreviousJob({
    required this.company,
    required this.designation,
    required this.sector,
    required this.years,
  });

  Map<String, dynamic> toMap() => {
        'co': company,
        'des': designation,
        'sec': sector,
        'y': years,
      };

  factory PreviousJob.fromMap(Map<String, dynamic> map) => PreviousJob(
        company: map['co'] as String? ?? '',
        designation: map['des'] as String? ?? '',
        sector: map['sec'] as String? ?? '',
        years: map['y'] as String? ?? '',
      );
}
