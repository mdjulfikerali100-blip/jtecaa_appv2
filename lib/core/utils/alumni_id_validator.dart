// lib/core/utils/alumni_id_validator.dart
//
// Architecture Appendix H — offline verification of Alumni ID during
// signup. No network call needed — the checksum is self-verifying against
// the Batch Number the user picks from the existing Batch dropdown.
//
// ⚠️ Organizational note: the Master Prompt bundles this conceptually
// under "auth_service.dart" (its Phase 2 bullet says "Alumni ID / Student
// ID verification (offline validators, Appendix H & §M.3)"). It's
// implemented here as its own file instead, because Appendix H itself
// describes it as "fully offline (no network call needed)" pure Dart
// logic — bundling it inside auth_service.dart would force the Signup
// screen to import a Firebase-dependent class just to validate a string
// offline. auth_service.dart re-exports this for convenience so callers
// following the Master Prompt's mental model still find it there too.
//
// ID format: jtec + 8 uppercase letters + alumni
// Example: jtecAAAAAKZZalumni

class AlumniIdValidationResult {
  final bool isValid;
  final String? errorMessage;

  const AlumniIdValidationResult._(this.isValid, this.errorMessage);

  factory AlumniIdValidationResult.valid() =>
      const AlumniIdValidationResult._(true, null);

  factory AlumniIdValidationResult.invalid(String message) =>
      AlumniIdValidationResult._(false, message);
}

class AlumniIdValidator {
  // Group 1 = the 8 uppercase letters between "jtec" and "alumni".
  static final RegExp _pattern = RegExp(r'^jtec([A-Z]{8})alumni$');

  /// [rawId] is the full ID text the user typed, e.g. "jtecAAAAAKZZalumni".
  /// [batchNumber] is the numeric batch already selected from the Batch
  /// dropdown (e.g. 85 for "85th Batch") — NOT a free-text Roll/Student ID
  /// (that field was removed from Signup entirely, Architecture §4.2.D).
  static AlumniIdValidationResult validate(String rawId, int? batchNumber) {
    final id = rawId.trim();

    if (id.isEmpty) {
      return AlumniIdValidationResult.invalid('Please enter your Alumni ID');
    }
    if (batchNumber == null) {
      return AlumniIdValidationResult.invalid('Please select your Batch');
    }

    final match = _pattern.firstMatch(id);
    if (match == null) {
      return AlumniIdValidationResult.invalid(
        'Invalid ID format — must be "jtec" + 8 uppercase letters + "alumni"',
      );
    }

    final eightLetters = match.group(1)!;

    // Character Sum: A=1, B=2, ..., Z=26.
    final characterSum = eightLetters
        .split('')
        .map((c) => c.codeUnitAt(0) - 'A'.codeUnitAt(0) + 1)
        .fold<int>(0, (a, b) => a + b);

    final computedBatchNumber = (characterSum + 7533) % 200;

    if (computedBatchNumber != batchNumber) {
      return AlumniIdValidationResult.invalid('Invalid ID — batch mismatch');
    }

    return AlumniIdValidationResult.valid();
  }
}
