// lib/presentation/providers/profile_provider.dart
//
// Architecture §7.4 (Profile Management) + Appendix F.7.5 (Profile Detail
// wireframe).
//
// ⚠️ Profile Detail must handle TWO distinct data sources depending on
// whose profile is being viewed:
//   - OWN profile → `UserRepository.getMyProfile()` reads `users_private`
//     (Phase 2, cache-first) — has EVERY field, including `dateOfJoining`,
//     `skills`, `bio`, `email`.
//   - SOMEONE ELSE's profile → `DirectoryRepository.getAlumniByUid()`
//     reads `users_public` (Phase 6 addition) — has everything EXCEPT
//     `dateOfJoining` and `email`, because Architecture's own
//     `syncUserPublic()` (§8.2) never copies `doj` into the public
//     document (a genuine, documented Architecture gap — see
//     user_public_model.dart's comment).
//
// `ProfileViewData` below normalizes both into one shape so
// profile_detail_screen.dart has a single layout instead of two parallel
// ones, with `dateOfJoining`/`email` simply null when viewing someone else.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user/user_private_model.dart';
import '../../data/models/user/user_public_model.dart';
import '../../data/models/user/work_experience_model.dart';
import 'auth_provider.dart';
import 'core_providers.dart';

class ProfileViewData {
  final String uid;
  final String fullName;
  final String? email; // null when viewing someone else
  final String department;
  final String batch;
  final String bloodGroup;
  final String? district;
  final String? currentLocation;
  final String careerStatus;
  final String? companyType;
  final String? company;
  final String? groupOfCompanies;
  final String? designation;
  final String? jobDepartment;
  final String?
      dateOfJoining; // null when viewing someone else (Architecture gap)
  final int? experienceYears;
  final List<WorkExperience> workExperience;
  final List<String> skills;
  final String? bio;
  final String? phone;
  final String? whatsapp;
  final String? linkedIn;
  final String? facebook;
  final String? photoUrl;
  final bool isOwnProfile;

  const ProfileViewData({
    required this.uid,
    required this.fullName,
    this.email,
    required this.department,
    required this.batch,
    required this.bloodGroup,
    this.district,
    this.currentLocation,
    required this.careerStatus,
    this.companyType,
    this.company,
    this.groupOfCompanies,
    this.designation,
    this.jobDepartment,
    this.dateOfJoining,
    this.experienceYears,
    this.workExperience = const [],
    this.skills = const [],
    this.bio,
    this.phone,
    this.whatsapp,
    this.linkedIn,
    this.facebook,
    this.photoUrl,
    required this.isOwnProfile,
  });

  factory ProfileViewData.fromOwn(UserProfileModel p) => ProfileViewData(
        uid: p.uid,
        fullName: p.fullName,
        email: p.email,
        department: p.department,
        batch: p.batch,
        bloodGroup: p.bloodGroup,
        district: p.district,
        currentLocation: p.currentLocation,
        careerStatus: p.careerStatus,
        companyType: p.companyType,
        company: p.company,
        groupOfCompanies: p.groupOfCompanies,
        designation: p.designation,
        jobDepartment: p.jobDepartment,
        dateOfJoining: p.dateOfJoining,
        experienceYears: p.experienceYears,
        workExperience: p.workExperience,
        skills: p.skills,
        bio: p.bio,
        phone: p.phone,
        whatsapp: p.whatsapp,
        linkedIn: p.linkedIn,
        facebook: p.facebook,
        photoUrl: p.photoUrl,
        isOwnProfile: true,
      );

  factory ProfileViewData.fromPublic(UserPublicModel p) => ProfileViewData(
        uid: p.uid,
        fullName: p.fullName,
        department: p.department ?? '',
        batch: p.batch ?? '',
        bloodGroup: p.bloodGroup ?? '',
        district: p.district,
        currentLocation: p.currentLocation,
        careerStatus: p.careerStatus,
        companyType: p.companyType,
        company: p.company,
        groupOfCompanies: p.groupOfCompanies,
        designation: p.designation,
        jobDepartment: p.jobDepartment,
        dateOfJoining: null, // not present in users_public — see file header
        experienceYears: p.experienceYears,
        workExperience: p.workExperience,
        skills: p.skills,
        bio: p.bio,
        phone: p.phone,
        whatsapp: p.whatsapp,
        linkedIn: p.linkedin,
        facebook: p.facebook,
        photoUrl: p.photoUrl,
        isOwnProfile: false,
      );
}

/// Fetches and normalizes the profile for [uid]. Automatically routes to
/// the richer "own profile" path when [uid] matches the signed-in user.
final profileViewProvider = FutureProvider.autoDispose
    .family<ProfileViewData, String>((ref, uid) async {
  final currentUid = ref.watch(currentUidProvider);

  if (currentUid != null && currentUid == uid) {
    final profile = await ref.watch(userRepositoryProvider).getMyProfile(uid);
    return ProfileViewData.fromOwn(profile);
  }

  final publicProfile =
      await ref.watch(directoryRepositoryProvider).getAlumniByUid(uid);
  if (publicProfile == null) {
    throw StateError('Profile not found.');
  }
  return ProfileViewData.fromPublic(publicProfile);
});

/// Convenience provider for Profile Edit, which always operates on the
/// signed-in user's OWN full `UserProfileModel` (never the normalized
/// view — editing needs every raw field, including ones not shown on
/// Profile Detail).
final myEditableProfileProvider =
    FutureProvider.autoDispose<UserProfileModel>((ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) {
    throw StateError('myEditableProfileProvider watched while signed out.');
  }
  return ref
      .watch(userRepositoryProvider)
      .getMyProfile(uid, forceRefresh: true);
});
