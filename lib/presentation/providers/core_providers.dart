// lib/presentation/providers/core_providers.dart
//
// ⚠️ ADDED BEYOND THE MASTER PROMPT'S EXPLICIT FILE LIST — no phase names
// a dedicated "dependency wiring" file, but Riverpod needs exactly one
// place where concrete FirebaseFirestore/FirestoreService/repository
// instances are constructed and exposed as Providers, so every screen
// provider (auth_provider.dart, role_provider.dart, and every later
// phase's screen-specific provider) can `ref.watch(...)` them instead of
// constructing `UserRepository(FirestoreService(FirebaseFirestore.instance))`
// by hand in multiple places. This is the single source of truth for
// "how is this repository built" — if a repository's constructor
// signature ever changes, only this file needs to change.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/external/google_sheets_proxy.dart';
import '../../data/datasources/external/student_sheets_proxy.dart';
import '../../data/datasources/remote/firestore_service.dart';
import '../../data/repositories/directory_repository.dart';
import '../../data/repositories/job_repository.dart';
import '../../data/repositories/news_repository.dart';
import '../../data/repositories/stats_repository.dart';
import '../../data/repositories/student_profile_repository.dart';
import '../../data/repositories/user_repository.dart';

final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService(ref.watch(firebaseFirestoreProvider));
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(firestoreServiceProvider));
});

final directoryRepositoryProvider = Provider<DirectoryRepository>((ref) {
  return DirectoryRepository(ref.watch(firestoreServiceProvider));
});

final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  return StatsRepository(ref.watch(firestoreServiceProvider));
});

// ⚠️ Jobs+News and Students point at TWO SEPARATE Sheets/Apps Script
// deployments (per the explicit decision to split them — see
// google_sheets_proxy.dart / student_sheets_proxy.dart's own comments).
final googleSheetsProxyProvider = Provider<GoogleSheetsProxy>((ref) {
  return GoogleSheetsProxy();
});

final studentSheetsProxyProvider = Provider<StudentSheetsProxy>((ref) {
  return StudentSheetsProxy();
});

final jobRepositoryProvider = Provider<JobRepository>((ref) {
  return JobRepository(ref.watch(googleSheetsProxyProvider));
});

final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  return NewsRepository(ref.watch(googleSheetsProxyProvider));
});

final studentProfileRepositoryProvider =
    Provider<StudentProfileRepository>((ref) {
  return StudentProfileRepository(ref.watch(studentSheetsProxyProvider));
});
