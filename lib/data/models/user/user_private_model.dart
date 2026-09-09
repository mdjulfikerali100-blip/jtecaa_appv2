// lib/data/models/user/user_private_model.dart
//
// users_private/{uid} — the source of truth (Architecture §4.2.A).
//
// ⚠️ SPEC CONTRADICTION RESOLVED (see chat explanation): Appendix A's
// original toMap()/fromMap() still read/write an `aid` (alumniId) field,
// but Architecture §4.2.D explicitly lists as "Explicitly REMOVED":
//   "❌ `aid` / `claimed` / `cby` fields in any model or document"
// This is left-over text in Appendix A that was never updated after the
// ID system became a pure offline checksum (Appendix H) with no
// Firestore-side registry to link back to. §4.2.D is the more specific,
// more recently-stated rule, so this model follows §4.2.D: no `alumniId`
// field anywhere, no `aid` key in toMap()/fromMap(). The ID is validated
// once at signup (Appendix H's AlumniIdValidator, wired in Phase 2's
// auth_service.dart) and then discarded — never persisted.

import 'previous_job_model.dart';
import 'work_experience_model.dart';

class UserProfileModel {
  final String uid;
  final String firstName;
  final String lastName;
  final String fullName; // Auto: firstName + lastName
  final String email;
  final String
      department; // raw code, e.g. "YARN_ENGINEERING" — never render directly (Appendix G.2)
  final String batch; // "1st Batch" to "150th Batch"
  final String bloodGroup; // "A+", "O-", etc.
  final String district; // one of the 64 Bangladesh districts
  // ⚠️ REMOVED (Appendix L.1.1): `hometown` field deleted entirely.
  // `district` is the single source of truth for location filtering.
  final String
      currentLocation; // free-text specific area/thana (Appendix L.1.2)
  final String phone;
  final String? whatsapp;
  final String careerStatus; // 5 categories — see CareerStatusCategories
  final String? companyType;
  final String? groupOfCompanies;
  final String? company;
  final String? designation;
  final String? jobDepartment;
  final String? dateOfJoining; // YYYY-MM-DD
  final int? experienceYears;
  final List<PreviousJob> previousJobs; // Legacy — migrate to workExperience
  final List<WorkExperience> workExperience;
  final List<String> skills;
  final String? bio;
  final String? linkedIn;
  final String? facebook;
  final String? photoUrl; // Google Drive fileId (Architecture §5.4), not a URL
  final bool isVerified; // Firebase Auth email_verified mirror
  final bool isActivated;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfileModel({
    required this.uid,
    required this.firstName,
    required this.lastName,
    this.fullName = '',
    required this.email,
    required this.department,
    required this.batch,
    required this.bloodGroup,
    required this.district,
    required this.currentLocation,
    required this.phone,
    this.whatsapp,
    required this.careerStatus,
    this.companyType,
    this.groupOfCompanies,
    this.company,
    this.designation,
    this.jobDepartment,
    this.dateOfJoining,
    this.experienceYears,
    this.previousJobs = const [],
    this.workExperience = const [],
    this.skills = const [],
    this.bio,
    this.linkedIn,
    this.facebook,
    this.photoUrl,
    required this.isVerified,
    required this.isActivated,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Firestore map with short keys (Architecture §4.1 cost-optimization
  /// rule). No `aid` key — see the removal note at the top of this file.
  Map<String, dynamic> toMap() {
    return {
      '_v': 4,
      'uid': uid,
      'fn': firstName.toUpperCase(),
      'ln': lastName.toUpperCase(),
      'n': '${firstName.toUpperCase()} ${lastName.toUpperCase()}',
      'e': email,
      'd': department,
      'b': batch,
      'bg': bloodGroup,
      'dist': district,
      'cl': currentLocation,
      'ph': phone,
      'wa': whatsapp,
      'cs': careerStatus,
      'ct': companyType,
      'gco': groupOfCompanies,
      'co': company,
      'des': designation,
      'jd': jobDepartment,
      'doj': dateOfJoining,
      'exp': experienceYears,
      'prev': previousJobs.map((j) => j.toMap()).toList(),
      'wx': workExperience.map((w) => w.toMap()).toList(),
      'sk': skills,
      'bio': bio,
      'li': linkedIn,
      'fb': facebook,
      'purl': photoUrl,
      'v': isVerified,
      'act': isActivated,
      'ca': createdAt.millisecondsSinceEpoch ~/ 1000,
      'ua': updatedAt.millisecondsSinceEpoch ~/ 1000,
    };
  }

  factory UserProfileModel.fromMap(Map<String, dynamic> map) {
    // ⚠️ Null-safety: default to empty string rather than force-unwrapping
    // — a partially-written or legacy document (e.g. mid-migration) must
    // never crash the whole profile screen over one missing field.
    final fn = map['fn'] as String? ?? '';
    final ln = map['ln'] as String? ?? '';
    return UserProfileModel(
      uid: map['uid'] as String? ?? '',
      firstName: fn,
      lastName: ln,
      fullName:
          map['n'] as String? ?? '${fn.toUpperCase()} ${ln.toUpperCase()}',
      email: map['e'] as String? ?? '',
      department: map['d'] as String? ?? '',
      batch: map['b'] as String? ?? '',
      bloodGroup: map['bg'] as String? ?? '',
      district: map['dist'] as String? ?? '',
      currentLocation: map['cl'] as String? ?? '',
      phone: map['ph'] as String? ?? '',
      whatsapp: map['wa'] as String?,
      careerStatus: map['cs'] as String? ?? 'Job Holder',
      companyType: map['ct'] as String?,
      groupOfCompanies: map['gco'] as String?,
      company: map['co'] as String?,
      designation: map['des'] as String?,
      jobDepartment: map['jd'] as String?,
      dateOfJoining: map['doj'] as String?,
      experienceYears: map['exp'] as int?,
      previousJobs: (map['prev'] as List?)
              ?.map((j) => PreviousJob.fromMap(j as Map<String, dynamic>))
              .toList() ??
          [],
      workExperience: (map['wx'] as List?)
              ?.map((w) => WorkExperience.fromMap(w as Map<String, dynamic>))
              .toList() ??
          [],
      skills: (map['sk'] as List?)?.cast<String>() ?? [],
      bio: map['bio'] as String?,
      linkedIn: map['li'] as String?,
      facebook: map['fb'] as String?,
      photoUrl: map['purl'] as String?,
      isVerified: map['v'] as bool? ?? false,
      isActivated: map['act'] as bool? ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        ((map['ca'] as int?) ?? 0) * 1000,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        ((map['ua'] as int?) ?? 0) * 1000,
      ),
    );
  }

  UserProfileModel copyWith({
    String? firstName,
    String? lastName,
    String? department,
    String? batch,
    String? bloodGroup,
    String? district,
    String? currentLocation,
    String? phone,
    String? whatsapp,
    String? careerStatus,
    String? companyType,
    String? groupOfCompanies,
    String? company,
    String? designation,
    String? jobDepartment,
    String? dateOfJoining,
    int? experienceYears,
    List<PreviousJob>? previousJobs,
    List<WorkExperience>? workExperience,
    List<String>? skills,
    String? bio,
    String? linkedIn,
    String? facebook,
    String? photoUrl,
    DateTime? updatedAt,
  }) {
    final newFn = firstName ?? this.firstName;
    final newLn = lastName ?? this.lastName;
    return UserProfileModel(
      uid: uid,
      firstName: newFn,
      lastName: newLn,
      fullName: '${newFn.toUpperCase()} ${newLn.toUpperCase()}',
      email: email,
      department: department ?? this.department,
      batch: batch ?? this.batch,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      district: district ?? this.district,
      currentLocation: currentLocation ?? this.currentLocation,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      careerStatus: careerStatus ?? this.careerStatus,
      companyType: companyType ?? this.companyType,
      groupOfCompanies: groupOfCompanies ?? this.groupOfCompanies,
      company: company ?? this.company,
      designation: designation ?? this.designation,
      jobDepartment: jobDepartment ?? this.jobDepartment,
      dateOfJoining: dateOfJoining ?? this.dateOfJoining,
      experienceYears: experienceYears ?? this.experienceYears,
      previousJobs: previousJobs ?? this.previousJobs,
      workExperience: workExperience ?? this.workExperience,
      skills: skills ?? this.skills,
      bio: bio ?? this.bio,
      linkedIn: linkedIn ?? this.linkedIn,
      facebook: facebook ?? this.facebook,
      photoUrl: photoUrl ?? this.photoUrl,
      isVerified: isVerified,
      isActivated: isActivated,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
