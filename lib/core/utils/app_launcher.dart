// lib/core/utils/app_launcher.dart
//
// Architecture Appendix B.1 — the shared, robust URL/intent launcher.
//
// ⚠️ PULLED FORWARD: no Master Prompt phase explicitly names this file,
// but Phase 5's "WhatsApp button (if available)" needs exactly this
// launcher to avoid recreating the exact bug Appendix K.4 documents:
// `Uri.parse(rawPhoneDigits)` with no scheme silently fails on real
// devices (Chrome never catches this), and an unguarded
// `canLaunchUrl`-false path leaves the user with zero feedback.
//
// ⚠️ FIX (Appendix K.1 / B.1): every `_showFailure(context, ...)` call
// that happens AFTER an `await` must be guarded by `context.mounted` —
// otherwise a fast-tapping user can trigger a "used after dispose"
// exception that never shows up in a quick Chrome test but does on a real
// device under real network latency.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'phone_validator.dart';

class AppLauncher {
  /// Launches [url], trying the external app first, then falling back to
  /// the platform default (in-app/external browser), and finally showing
  /// a SnackBar instead of failing silently. Returns true if something
  /// was opened.
  static Future<bool> open(
    BuildContext context,
    String? url, {
    String failureMessage = 'This link could not be opened.',
  }) async {
    if (url == null || url.isEmpty) {
      if (context.mounted) _showFailure(context, failureMessage);
      return false;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (context.mounted) _showFailure(context, failureMessage);
      return false;
    }

    try {
      // Try the native app / external handler first (dialer, FB app, etc).
      final launchedExternally =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launchedExternally) {
        return true;
      }

      // Fall back to platform default (in-app browser) for http/https
      // links where no matching app is installed.
      if (uri.scheme == 'http' || uri.scheme == 'https') {
        final launchedInApp =
            await launchUrl(uri, mode: LaunchMode.platformDefault);
        if (launchedInApp) {
          return true;
        }
      }
    } catch (_) {
      // canLaunchUrl/launchUrl can throw on some OEM ROMs (MIUI/Realme/
      // etc.) with hardened package visibility instead of just returning
      // false — always catch, never let this crash a tap.
    }

    if (context.mounted) {
      _showFailure(context, failureMessage);
    }
    return false;
  }

  static Future<bool> call(BuildContext context, String? phone) {
    return open(
      context,
      PhoneValidator.toTelUrl(phone),
      failureMessage: 'Could not open the dialer.',
    );
  }

  static Future<bool> whatsapp(BuildContext context, String? phone) {
    return open(
      context,
      PhoneValidator.toWhatsAppUrl(phone),
      failureMessage: 'Could not open WhatsApp.',
    );
  }

  /// [profileUrl] is expected to already be a full `https://facebook.com/...`
  /// URL (per the `users_private.fb` field) — never assume a bare username.
  static Future<bool> facebook(BuildContext context, String? profileUrl) async {
    if (profileUrl == null || profileUrl.isEmpty) {
      if (context.mounted) _showFailure(context, 'No Facebook link on file.');
      return false;
    }
    final normalized = profileUrl.startsWith('http')
        ? profileUrl
        : 'https://facebook.com/$profileUrl';
    return open(context, normalized,
        failureMessage: 'Could not open Facebook.');
  }

  static Future<bool> linkedin(BuildContext context, String? profileUrl) async {
    if (profileUrl == null || profileUrl.isEmpty) {
      if (context.mounted) _showFailure(context, 'No LinkedIn link on file.');
      return false;
    }
    final normalized = profileUrl.startsWith('http')
        ? profileUrl
        : 'https://linkedin.com/in/$profileUrl';
    return open(context, normalized,
        failureMessage: 'Could not open LinkedIn.');
  }

  static void _showFailure(BuildContext context, String message) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
