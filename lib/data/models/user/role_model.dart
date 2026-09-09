// lib/data/models/user/role_model.dart
//
// Architecture §M.5 — `roles/{uid}` is the ONLY Firestore document a
// Student ever gets: `{ role: "alumni" | "student", ca: <unix timestamp> }`.
// No PII lives here — Student PII lives solely in the Google Sheet
// (student_profile_model.dart). This doc is write-once by Security Rules
// (§M.5's `!exists(...)` rule) — a role can never flip after signup.

enum SignupRole { alumni, student }

extension SignupRoleX on SignupRole {
  String get wireValue => this == SignupRole.alumni ? 'alumni' : 'student';

  static SignupRole fromWireValue(String? value) {
    // ⚠️ Defaults to alumni rather than throwing on an unexpected/missing
    // value — a malformed role document should degrade to the fuller
    // (Alumni) shell rather than silently locking someone out of the app
    // they already verified into.
    return value == 'student' ? SignupRole.student : SignupRole.alumni;
  }
}

class RoleModel {
  final String uid;
  final SignupRole role;
  final int createdAt; // unix seconds

  const RoleModel({
    required this.uid,
    required this.role,
    required this.createdAt,
  });

  factory RoleModel.fromMap(String uid, Map<String, dynamic> map) {
    return RoleModel(
      uid: uid,
      role: SignupRoleX.fromWireValue(map['role'] as String?),
      createdAt: map['ca'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'role': role.wireValue,
        'ca': createdAt,
      };
}
