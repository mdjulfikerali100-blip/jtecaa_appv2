// lib/core/utils/phone_validator.dart
//
// Bangladesh phone number validation — Architecture Appendix B.
//
// ⚠️ `toTelUrl()` below is written with the Appendix K.4 fix already
// applied, from day one — the original bug was calling `Uri.parse(rawDigits)`
// with no scheme, which produces a valid *relative* URI (no `tel:` scheme),
// so `canLaunchUrl` correctly returns false and the Phone button silently
// does nothing. The fix is to always construct the URI with an explicit
// `scheme: 'tel'` via `Uri(scheme: 'tel', path: ...)`.

class PhoneValidator {
  /// Validates BD phone numbers: +8801XXXXXXXXX or 01XXXXXXXXX
  static bool isValidBangladeshPhone(String? phone) {
    if (phone == null || phone.isEmpty) return false;
    final cleaned = phone.replaceAll(RegExp(r'\s+'), '');
    final bdRegex = RegExp(r'^(\+8801|01)[3-9]\d{8}$');
    return bdRegex.hasMatch(cleaned);
  }

  /// Normalizes to standard format: 0171XXXXXXX
  static String? normalize(String? phone) {
    if (phone == null || phone.isEmpty) return null;
    final cleaned = phone.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.startsWith('+880')) {
      return cleaned.substring(3); // +88017... → 017...
    }
    return cleaned;
  }

  /// Formats for WhatsApp URL: https://wa.me/880171XXXXXXX
  static String? toWhatsAppUrl(String? phone) {
    final normalized = normalize(phone);
    if (normalized == null) return null;
    final withCountry =
        normalized.startsWith('0') ? '88$normalized' : normalized;
    return 'https://wa.me/$withCountry';
  }

  /// ⚠️ Appendix K.4 fix, applied from the start: a dialable number MUST
  /// be built with the `tel:` scheme via `Uri(scheme: 'tel', path: ...)` —
  /// never `Uri.parse(rawDigits)`, which silently fails on real devices.
  static String? toTelUrl(String? phone) {
    final normalized = normalize(phone);
    if (normalized == null) return null;
    return Uri(scheme: 'tel', path: normalized).toString();
  }

  static String? getErrorMessage(String? phone) {
    if (phone == null || phone.isEmpty) return 'Phone number is required';
    if (!isValidBangladeshPhone(phone)) {
      return 'Enter valid BD number (e.g., 0171XXXXXXX)';
    }
    return null;
  }
}
