// lib/core/utils/departments_helper.dart
//
// ⚠️ ADDED BEYOND THE MASTER PROMPT'S EXPLICIT PHASE 1 FILE LIST — the
// Master Prompt's Phase 1 utils list (batch_helper, blood_group_helper,
// phone_validator, career_status_categories, company_types,
// job_departments, districts) omits this file, but Architecture Appendix
// G.2 defines it as essential, load-bearing code: it's the fix for the
// "WET_PROCESS_ENGINEERING" raw-enum-code-on-screen bug (Appendix G.2's
// own words), used by the Directory Card, Profile Detail/Edit, Home
// greeting card, and the Directory filter dropdown. Skipping it here would
// mean every one of those later phases either breaks or has to silently
// redefine it — generating it now, explicitly flagged, is the correct
// minimal-diff choice.
//
// Project-wide rule (Architecture G.2): the raw department code
// (`YARN_ENGINEERING`, etc.) is the correct value to *store* (Firestore
// field `d`) but must NEVER be rendered directly in a Text widget —
// always call `Departments.getShortLabel(code)` first.

class Departments {
  static const List<String> all = [
    'YARN_ENGINEERING',
    'FABRIC_ENGINEERING',
    'WET_PROCESS_ENGINEERING',
    'APPAREL_ENGINEERING',
  ];

  /// Full official names — formal contexts only (certificates, long-form
  /// labels) — NOT for everyday card/list UI.
  static const Map<String, String> fullNames = {
    'YARN_ENGINEERING': 'Yarn Engineering',
    'FABRIC_ENGINEERING': 'Fabric Engineering',
    'WET_PROCESS_ENGINEERING': 'Wet Process Engineering',
    'APPAREL_ENGINEERING': 'Apparel Engineering',
  };

  /// Short, human-readable labels for everyday UI — Profile card,
  /// Directory card, Directory Filter dropdown, "Dept • Batch" line.
  static const Map<String, String> shortNames = {
    'YARN_ENGINEERING': 'Yarn Eng.',
    'FABRIC_ENGINEERING': 'Fabric Eng.',
    'WET_PROCESS_ENGINEERING': 'Wet Process Eng.',
    'APPAREL_ENGINEERING': 'Apparel Eng.',
  };

  /// Short display label for cards/lists, e.g. "Wet Process Eng.".
  /// Falls back to a title-cased version of the raw code for any future
  /// department added to `all` but not yet added to `shortNames`, so the
  /// UI degrades gracefully instead of ever showing a raw
  /// `SOME_NEW_DEPARTMENT` code again.
  static String getShortLabel(String? code) {
    if (code == null || code.isEmpty) return '';
    return shortNames[code] ?? _titleCaseFallback(code);
  }

  /// Full display label: "YARN_ENGINEERING — Yarn Engineering" — kept for
  /// admin/CSV export tooling, NOT for user-facing cards.
  static String getDisplayLabel(String code) {
    final full = fullNames[code];
    return full != null ? '$code — $full' : code;
  }

  static List<String> getDisplayOptions() {
    return all.map(getDisplayLabel).toList();
  }

  static String extractCode(String displayLabel) {
    return displayLabel.split(' — ').first;
  }

  static String _titleCaseFallback(String code) {
    return code
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0]}${w.substring(1).toLowerCase()}')
        .join(' ');
  }
}
