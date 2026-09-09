// lib/core/utils/student_id_validator.dart
//
// Architecture §M.3 — offline verification of Student ID during signup.
// Mirrors AlumniIdValidator (Appendix H) exactly, but with a different
// suffix ("student" not "alumni") and a different additive constant
// (3577 not 7533) so a Student ID can never accidentally validate as an
// Alumni ID or vice versa.
//
// ID format: jtec + 8 uppercase letters + student
// Example: jtecABCDEFGHstudent

import 'alumni_id_validator.dart' show AlumniIdValidationResult;

class StudentIdValidator {
  static final RegExp _pattern = RegExp(r'^jtec([A-Z]{8})student$');

  /// [rawId] e.g. "jtecABCDEFGHstudent". [batchNumber] is the numeric batch
  /// already selected from the Batch dropdown (e.g. 85 for "85th Batch").
  static AlumniIdValidationResult validate(String rawId, int? batchNumber) {
    final id = rawId.trim();

    if (id.isEmpty) {
      return AlumniIdValidationResult.invalid('Please enter your Student ID');
    }
    if (batchNumber == null) {
      return AlumniIdValidationResult.invalid('Please select your Batch');
    }

    final match = _pattern.firstMatch(id);
    if (match == null) {
      return AlumniIdValidationResult.invalid(
        'Invalid ID format.',
      );
    }

    final eightLetters = match.group(1)!;
    final characterSum = eightLetters
        .split('')
        .map((c) => c.codeUnitAt(0) - 'A'.codeUnitAt(0) + 1)
        .fold<int>(0, (a, b) => a + b);

    final computedBatchNumber = (characterSum + 3577) % 200;

    if (computedBatchNumber != batchNumber) {
      return AlumniIdValidationResult.invalid(
          'Invalid ID Please correct your ID from the JTEACC.');
    }

    return AlumniIdValidationResult.valid();
  }
}
