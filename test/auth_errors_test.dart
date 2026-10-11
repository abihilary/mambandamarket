// Proves the mapper never leaks raw server text and resolves in both locales.
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mambandamarket/api/auth_errors.dart';
import 'package:mambandamarket/l10n/gen/app_localizations.dart';

void main() {
  // The exact payload a user was shown on screen on 10 Oct.
  const raw =
      '{"code":"unexpected_failure","message":"Error sending confirmation email"}';

  for (final code in ['en', 'fr']) {
    final l10n = lookupAppLocalizations(Locale(code));

    test('[$code] mail-send failure is recognised and localised', () {
      final e = AuthException(raw, statusCode: '500', code: 'unexpected_failure');
      expect(isEmailUndeliverable(e), isTrue);
      final msg = authErrorMessage(e, l10n);
      expect(msg, l10n.authEmailUndeliverable);
      expect(msg, isNot(contains('unexpected_failure')));
      expect(msg, isNot(contains('{')));
    });

    test('[$code] older servers that only say it in prose still match', () {
      final e = AuthException('Error sending confirmation email', statusCode: '500');
      expect(isEmailUndeliverable(e), isTrue);
    });

    test('[$code] unknown codes fall back, never echo the server', () {
      final e = AuthException('some brand new server wording',
          statusCode: '500', code: 'never_seen_before');
      final msg = authErrorMessage(e, l10n);
      expect(msg, l10n.authGenericFailure);
      expect(msg, isNot(contains('brand new')));
    });

    test('[$code] known codes map to their own strings', () {
      String m(String? c, [String msg = 'x']) =>
          authErrorMessage(AuthException(msg, code: c), l10n);
      expect(m('invalid_credentials'), l10n.authInvalidCredentials);
      expect(m('weak_password'), l10n.authWeakPassword);
      expect(m('email_address_invalid'), l10n.authEmailInvalid);
      expect(m('user_already_exists'), l10n.signUpAlreadyRegistered);
      expect(m('otp_expired'), l10n.authLinkExpired);
      expect(m('over_email_send_rate_limit'), l10n.signUpRateLimited);
    });
  }

  test('French really is different text, not an English fallthrough', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(fr.authEmailUndeliverable, isNot(en.authEmailUndeliverable));
    expect(fr.authGenericFailure, isNot(en.authGenericFailure));
  });
}
