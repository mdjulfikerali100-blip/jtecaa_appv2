// lib/data/models/user/user_public_model.dart
//
// users_public/{uid} — the directory view (Architecture §4.2.B).
//
// ⚠️ No Privacy filtering anywhere in this model (Appendix E: Privacy
// Settings feature removed entirely). Every field here mirrors the
// corresponding users_private field unconditionally — there is no
// "sp"/"sd"/"sb" style visibility toggle to check.
//
// ⚠️ This model is READ-ONLY by design (fromMap only, no toMap). Writing
// users_public is done by hand-building a Map directly inside
// UserRepository.syncUserPublic() (Architecture §8.2, Phase 2) — not by
// calling `.toMap()` on this class — because the write path needs to pull
// straight from the freshly-saved users_private data, not from an
// already-constructed UserPublicModel instance.
//
// ⚠️ Fields beyond the original Appendix D version, and why:
//   - phone, facebook, linkedin: Appendix K.4 root-cause fix — these
//     existed as Firestore fields (`ph`/`fb`/`li`) but were missing from
//     this model entirely, which is one of two independent reasons the
//     Phone/Facebook/LinkedIn contact buttons could never have worked.
//   - companyType, groupOfCompanies, jobDepartment, workExperience:
//     Appendix L.1.3/L.1.5 — needed so the Directory search box can match
//     on Group of Companies / Job Department / past company names, and so
//     the Total Work Experience badge can be computed on the directory
//     card without an extra Firestore read.
//   - skills, bio, experienceYears: ⚠️ SELF-CAUGHT BUG (Phase 6) — these
//     three fields ARE written to `users_public` by
//     UserRepository.syncUserPublic() (`sk`/`bio`/`exp`, matching
//     Architecture §8.2's own code and the §4.2.B schema example), but
//     this model never parsed them out. Profile Detail (Phase 6) needs
//     Skills and Bio when viewing someone else's profile via
//     `users_public`, so they're added now.
//
// ⚠️ KNOWN GAP (not fixed here — a genuine Architecture limitation):
// `doj` (Date of Joining) is written to `users_private` but is NOT
// copied into `users_public` by Architecture's own §8.2 `_buildPublicMap`
// code. This means Date of Joining is simply unavailable when viewing
// someone ELSE's profile — only visible on your OWN profile (read from
// `users_private` instead). Profile Detail Screen (Phase 6) handles this
// by omitting that field gracefully for other users' profiles rather
// than guessing or crashing.

import 'work_experience_model.dart';

class UserPublicModel {
  final String uid;
  final String fullName;
  final String? department;
  final String? batch;
  final String? bloodGroup;
  final String? district;
  final String? currentLocation;
  final String? company;
  final String? designation;
  final String careerStatus; // always visible: 5 categories
  final String? photoUrl; // Google Drive fileId
  final String? whatsapp;
  final String? phone;
  final String? facebook;
  final String? linkedin;
  final String? companyType;
  final String? groupOfCompanies;
  final String? jobDepartment;
  final List<WorkExperience> workExperience;
  final List<String> skills;
  final String? bio;
  final int? experienceYears;
  final int lastUpdated; // unix seconds — `lu` field, Architecture §4.2.B

  UserPublicModel({
    required this.uid,
    required this.fullName,
    this.department,
    this.batch,
    this.bloodGroup,
    this.district,
    this.currentLocation,
    this.company,
    this.designation,
    this.careerStatus = 'Job Holder',
    this.photoUrl,
    this.whatsapp,
    this.phone,
    this.facebook,
    this.linkedin,
    this.companyType,
    this.groupOfCompanies,
    this.jobDepartment,
    this.workExperience = const [],
    this.skills = const [],
    this.bio,
    this.experienceYears,
    this.lastUpdated = 0,
  });

  factory UserPublicModel.fromMap(Map<String, dynamic> map) {
    return UserPublicModel(
      uid: map['uid'] as String? ?? '',
      fullName: map['n'] as String? ?? '',
      department: map['d'] as String?,
      batch: map['b'] as String?,
      bloodGroup: map['bg'] as String?,
      district: map['dist'] as String?,
      currentLocation: map['cl'] as String?,
      company: map['co'] as String?,
      designation: map['des'] as String?,
      careerStatus: map['s'] as String? ?? 'Job Holder',
      photoUrl: map['purl'] as String?,
      whatsapp: map['wa'] as String?,
      phone: map['ph'] as String?,
      facebook: map['fb'] as String?,
      linkedin: map['li'] as String?,
      companyType: map['ct'] as String?,
      groupOfCompanies: map['gco'] as String?,
      jobDepartment: map['jd'] as String?,
      // ⚠️ Null-safety: a directory card must render even if `wx` is
      // missing/malformed on one particular document — never let one bad
      // record break the whole paginated list.
      workExperience: (map['wx'] as List?)
              ?.map((w) => WorkExperience.fromMap(w as Map<String, dynamic>))
              .toList() ??
          [],
      skills: (map['sk'] as List?)?.cast<String>() ?? [],
      bio: map['bio'] as String?,
      experienceYears: map['exp'] as int?,
      lastUpdated: map['lu'] as int? ?? 0,
    );
  }
}
