// lib/core/errors/exceptions.dart
//
// ⚠️ ADDED BEYOND THE MASTER PROMPT'S EXPLICIT PHASE 2 FILE LIST — the
// Master Prompt's "Code Quality Requirements" section mandates "Custom
// exceptions in lib/core/errors/" and Architecture §3's file tree lists
// `core/errors/exceptions.dart`, but no numbered Phase in the Master
// Prompt ever explicitly generates it. Every datasource file in this
// phase (firestore_service, auth_service, google_sheets_proxy) needs a
// structured exception type to throw instead of leaking a raw
// FirebaseException/SocketException message to the UI — so it's added
// here, now, flagged clearly, rather than silently invented later.
//
// `failures.dart` (also listed in §3's file tree) is deliberately NOT
// created — this app's state management is plain Riverpod
// AsyncValue.error (per the Master Prompt's "State Management" rule), not
// an Either<Failure, T> functional-error pattern, so a separate Failure
// class hierarchy would have no consumer anywhere in this codebase (YAGNI).

/// Base class for all app-specific exceptions. Catching `AppException`
/// anywhere in the UI layer is always safe — `.message` is guaranteed to
/// be a short, user-presentable string (never a raw stack trace or a
/// Firebase internal error code).
abstract class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}

/// Firestore/Firebase Auth/FCM read-write failures.
class NetworkException extends AppException {
  const NetworkException(super.message);
}

/// Firebase Authentication failures (sign up, sign in, verification).
class AuthException extends AppException {
  const AuthException(super.message);
}

/// Hive read/write failures (corrupted box, disk full, etc.) — repositories
/// should catch these and fall back to a network fetch or an empty state,
/// never let a cache failure crash the screen.
class CacheException extends AppException {
  const CacheException(super.message);
}

/// Input validation failures — offline ID checksum mismatch, malformed
/// phone number, etc. (Appendix H / §M.3 validators raise these indirectly
/// via their own Result classes, but repositories that re-validate before
/// a write use this).
class ValidationException extends AppException {
  const ValidationException(super.message);
}

/// Google Sheets Apps Script proxy failures (Architecture Appendix I) —
/// distinct from NetworkException so the UI can show a more specific
/// "Jobs/News service unavailable" message if useful later.
class SheetsProxyException extends AppException {
  const SheetsProxyException(super.message);
}
