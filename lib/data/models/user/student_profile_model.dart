// lib/data/models/user/student_profile_model.dart
//
// Architecture §M.4 — Student profile, stored in the "Students" tab of the
// same Google Sheet used for Jobs/News, via Apps Script (§M.4 endpoints:
// createStudent / updateStudent / getStudentByUid / deleteStudent). Never
// written to Firestore — the only Firestore document a Student ever gets
// is the write-once role flag at roles/{uid} (§M.5, see role_model.dart).

class StudentProfileModel {
  final String uid;
  final String fullName;
  final String phone;
  final String batch;
  final String? bloodGroup;
  final String? district;
  final String? currentLocation;
  final String email;
  final DateTime createdAt;
  final DateTime updatedAt;

  StudentProfileModel({
    required this.uid,
    required this.fullName,
    required this.phone,
    required this.batch,
    this.bloodGroup,
    this.district,
    this.currentLocation,
    required this.email,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudentProfileModel.fromMap(Map<String, dynamic> map) {
    return StudentProfileModel(
      uid: map['uid'] as String? ?? '',
      fullName: map['full_name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      batch: map['batch'] as String? ?? '',
      bloodGroup: map['blood_group'] as String?,
      district: map['district'] as String?,
      currentLocation: map['current_location'] as String?,
      email: map['email'] as String? ?? '',
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Request body for `action=createStudent` (§M.4). `created_at`/
  /// `updated_at` are set server-side by Apps Script, not sent by the app.
  Map<String, dynamic> toCreateBody() => {
        'uid': uid,
        'full_name': fullName,
        'phone': phone,
        'batch': batch,
        'blood_group': bloodGroup ?? '',
        'district': district ?? '',
        'current_location': currentLocation ?? '',
        'email': email,
      };

  StudentProfileModel copyWith({
    String? fullName,
    String? phone,
    String? batch,
    String? bloodGroup,
    String? district,
    String? currentLocation,
  }) {
    return StudentProfileModel(
      uid: uid,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      batch: batch ?? this.batch,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      district: district ?? this.district,
      currentLocation: currentLocation ?? this.currentLocation,
      email: email,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
