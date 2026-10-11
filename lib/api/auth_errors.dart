// One place that turns a Supabase AuthException into something a person can
// read, in their own language.
//
// Before this existed every screen did its own `e.message.contains('...')` and
// fell through to showing `e.message` raw. That had two failure modes, both of
// which reached production:
//
//   * The server's text is English, so a French user got English — or worse.
//     When gotrue cannot parse an error body it puts the body itself in
//     `message`, and a signed-up user was shown the literal string
//     `{"code":"unexpected_failure","message":"Error sending confirmation
//     email"}` on a red bar.
//   * Matching on English prose breaks silently whenever the server rewords a
//     message, and nothing fails loudly enough to notice.
//
// So: switch on `code`, which gotrue populates from the server's stable error
// code, and never return `message`. Anything unrecognised becomes a generic
// localized line, with the raw text left in the debug log so a report like
// "it just said something went wrong" is still diagnosable.
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/l10n.dart';

/// True when sign-up failed because the confirmation email could not be sent.
///
/// Worth its own predicate because it is the one failure the user can route
/// around themselves — Google sign-in sends no mail — so callers offer that
/// instead of a dead end. GoTrue rolls the user row back when the mail fails,
/// so retrying the same address later is safe.
bool isEmailUndeliverable(AuthException e) {
  if (e.code == 'unexpected_failure') return true;
  final m = e.message.toLowerCase();
  // Belt and braces: the code is recent, and older servers only say it in prose.
  return m.contains('error sending') ||
      (m.contains('email') && m.contains('could not send'));
}

/// True when the address already has an account.
bool isAlreadyRegistered(AuthException e) =>
    e.code == 'user_already_exists' || e.code == 'email_exists';

/// True when the account exists but the address was never confirmed.
bool isEmailNotConfirmed(AuthException e) =>
    e.code == 'email_not_confirmed' ||
    e.message.toLowerCase().contains('email not confirmed');

/// True when a recovery/confirmation link is spent or stale.
bool isLinkExpired(AuthException e) {
  if (e.code == 'otp_expired') return true;
  final m = e.message.toLowerCase();
  return m.contains('expired') || m.contains('invalid');
}

/// True when the server is throttling outbound mail.
bool isRateLimited(AuthException e) =>
    e.code == 'over_email_send_rate_limit' ||
    e.code == 'over_request_rate_limit' ||
    e.message.toLowerCase().contains('rate limit');

/// A localized, user-facing line for [e]. Never returns raw server text.
///
/// Callers that want to *act* on a specific failure — offer Google, offer a
/// "resend", route to sign-in — should test with the predicates above and
/// handle it themselves; this is the fallback for everything else.
String authErrorMessage(AuthException e, AppLocalizations l10n) {
  if (isRateLimited(e)) return l10n.signUpRateLimited;
  if (isEmailUndeliverable(e)) return l10n.authEmailUndeliverable;
  if (isAlreadyRegistered(e)) return l10n.signUpAlreadyRegistered;
  if (isEmailNotConfirmed(e)) return l10n.emailNotConfirmedBody;
  if (isLinkExpired(e)) return l10n.authLinkExpired;

  switch (e.code) {
    case 'invalid_credentials':
    case 'invalid_grant':
      return l10n.authInvalidCredentials;
    case 'weak_password':
      return l10n.authWeakPassword;
    case 'email_address_invalid':
    case 'validation_failed':
      return l10n.authEmailInvalid;
  }

  // Unrecognised. Keep the original where a developer can find it, and show
  // the person something that is at least in their language.
  debugPrint('[auth] unmapped ${e.code ?? '-'} / ${e.statusCode ?? '-'}: ${e.message}');
  return l10n.authGenericFailure;
}
