// lib/core/utils/batch_helper.dart
//
// Architecture Appendix B — generates batch dropdown options and extracts
// the numeric batch back out of a label like "85th Batch". This numeric
// extraction is also what feeds AlumniIdValidator/StudentIdValidator
// (Appendix H / §M.3, wired in Phase 2) since both checksums validate
// against a *numeric* batch, not the display string.

class BatchHelper {
  static const int maxBatch = 200;

  /// Returns list of batch strings: ["1st Batch", "2nd Batch", ..., "150th Batch"]
  static List<String> generateBatchOptions() {
    return List.generate(maxBatch, (index) {
      final number = index + 1;
      return '$number${_getOrdinalSuffix(number)} Batch';
    });
  }

  /// Extracts numeric batch from string (e.g., "85th Batch" → 85).
  /// Returns null (not a force-unwrapped crash) if the string is malformed
  /// — e.g. a legacy/corrupted value that somehow bypassed the dropdown.
  static int? extractBatchNumber(String batchString) {
    final match = RegExp(r'(\d+)').firstMatch(batchString);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  static String _getOrdinalSuffix(int number) {
    if (number >= 11 && number <= 13) return 'th';
    switch (number % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }
}
