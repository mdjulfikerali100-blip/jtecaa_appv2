// lib/core/utils/districts.dart
//
// Architecture Appendix G.1 — Bangladesh's 64 districts, used by the
// District dropdown (Profile Edit), Directory Filter, and District
// Priority sorting (Architecture §7.3).

class Districts {
  static const List<String> all = [
    'BAGERHAT',
    'BANDARBAN',
    'BARGUNA',
    'BARISHAL',
    'BHOLA',
    'BOGRA',
    'BRAHMANBARIA',
    'CHANDPUR',
    'CHAPAINAWABGANJ',
    'CHATTOGRAM',
    'CHUADANGA',
    'COXS BAZAR',
    'CUMILLA',
    'DHAKA',
    'DINAJPUR',
    'FARIDPUR',
    'FENI',
    'GAIBANDHA',
    'GAZIPUR',
    'GOPALGANJ',
    'HABIGANJ',
    'JAMALPUR',
    'JASHORE',
    'JHALOKATI',
    'JHENAIDAH',
    'JOYPURHAT',
    'KHAGRACHHARI',
    'KHULNA',
    'KISHOREGANJ',
    'KURIGRAM',
    'KUSHTIA',
    'LAKSHMIPUR',
    'LALMONIRHAT',
    'MADARIPUR',
    'MAGURA',
    'MANIKGANJ',
    'MEHERPUR',
    'MOULVIBAZAR',
    'MUNSHIGANJ',
    'MYMENSINGH',
    'NAOGAON',
    'NARAIL',
    'NARAYANGANJ',
    'NARSINGDI',
    'NATORE',
    'NETRAKONA',
    'NILPHAMARI',
    'NOAKHALI',
    'PABNA',
    'PANCHAGARH',
    'PATUAKHALI',
    'PIROJPUR',
    'RAJBARI',
    'RAJSHAHI',
    'RANGAMATI',
    'RANGPUR',
    'SATKHIRA',
    'SHARIATPUR',
    'SHERPUR',
    'SIRAJGANJ',
    'SUNAMGANJ',
    'SYLHET',
    'TANGAIL',
    'THAKURGAON',
  ];

  /// Grouped by division for organized dropdown display.
  ///
  /// ⚠️ ROOT-CAUSE FIX applied here vs. the Architecture doc's own listing:
  /// the KHULNA division group in Appendix G.1 spells one entry
  /// "KHUSTIA", which does not match the canonical spelling "KUSHTIA" used
  /// in the `all` list two sections above in the same document. Left
  /// as-is, this typo would make the "byDivision" grouped dropdown show a
  /// district string that can never match a real `dist` field value saved
  /// via the (correctly-spelled) `all` list — a silent filter/display bug.
  /// Corrected to "KUSHTIA" below to match `all`.
  static const Map<String, List<String>> byDivision = {
    'DHAKA': [
      'DHAKA',
      'FARIDPUR',
      'GAZIPUR',
      'GOPALGANJ',
      'KISHOREGANJ',
      'MADARIPUR',
      'MANIKGANJ',
      'MUNSHIGANJ',
      'NARAYANGANJ',
      'NARSINGDI',
      'RAJBARI',
      'SHARIATPUR',
      'TANGAIL',
    ],
    'CHATTOGRAM': [
      'CHATTOGRAM',
      'BANDARBAN',
      'BRAHMANBARIA',
      'CHANDPUR',
      'COXS BAZAR',
      'FENI',
      'KHAGRACHHARI',
      'LAKSHMIPUR',
      'NOAKHALI',
      'RANGAMATI',
    ],
    'KHULNA': [
      'KHULNA',
      'BAGERHAT',
      'CHUADANGA',
      'JASHORE',
      'JHENAIDAH',
      'KUSHTIA',
      'MAGURA',
      'MEHERPUR',
      'NARAIL',
      'SATKHIRA',
    ],
    'RAJSHAHI': [
      'RAJSHAHI',
      'BOGRA',
      'CHAPAINAWABGANJ',
      'JOYPURHAT',
      'NAOGAON',
      'NATORE',
      'PABNA',
      'SIRAJGANJ',
    ],
    'BARISHAL': [
      'BARISHAL',
      'BARGUNA',
      'BHOLA',
      'JHALOKATI',
      'PIROJPUR',
      'PATUAKHALI',
    ],
    'SYLHET': [
      'SYLHET',
      'HABIGANJ',
      'MOULVIBAZAR',
      'SUNAMGANJ',
    ],
    'RANGPUR': [
      'RANGPUR',
      'DINAJPUR',
      'GAIBANDHA',
      'KURIGRAM',
      'LALMONIRHAT',
      'NILPHAMARI',
      'PANCHAGARH',
      'THAKURGAON',
    ],
    'MYMENSINGH': [
      'MYMENSINGH',
      'JAMALPUR',
      'NETRAKONA',
      'SHERPUR',
    ],
  };

  /// For search: returns districts matching query (used by the Directory
  /// filter bottom sheet's searchable district list, §7.3).
  static List<String> search(String query) {
    final q = query.toUpperCase();
    return all.where((d) => d.contains(q)).toList();
  }
}
