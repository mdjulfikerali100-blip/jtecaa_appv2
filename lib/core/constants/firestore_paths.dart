// lib/core/constants/firestore_paths.dart
//
// Centralized Firestore collection name constants (Architecture §3 file
// tree: core/constants/firestore_paths.dart). Using constants instead of
// hardcoded strings scattered across repositories prevents a typo'd
// collection name from silently creating a second, empty collection.
//
// ⚠️ SPEC CONTRADICTION NOTED (not fixed here — just documented, since
// this file only holds path constants): Architecture §4.2.D explicitly
// states "❌ `alumni_registry` collection (schema, security rules,
// monitoring)" is removed, and Appendix H confirms ID verification is a
// pure offline checksum with "no network call needed". However, §9.2's
// Firestore Security Rules code block (and Phase 11 of the Master Prompt,
// which copies that same rules file) still contains a leftover
// `match /alumni_registry/{aid} { allow read: ...; allow write: if false; }`
// block. Since §4.2.D is the more specific, explicit removal instruction,
// this constants file follows it: NO `alumniRegistry` path constant is
// defined below, and no repository in this app will ever read/write that
// collection. When Phase 11 generates `firestore.rules`, that leftover
// match block should be deleted too, for the same reason.

class FirestorePaths {
  static const String usersPrivate = 'users_private';
  static const String usersPublic = 'users_public';
  static const String systemConfig = 'system/config'; // single document
  static const String userTokens = 'user_tokens';
  static const String notificationLog = 'notification_log';

  /// §M.5 — role flag only (no PII), write-once per uid.
  static const String roles = 'roles';
}
