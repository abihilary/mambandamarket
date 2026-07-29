import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api_client.dart';
import 'models.dart';

/// Where Google sends the user back after consent.
///
/// On mobile this is a custom scheme handled by the app (registered in the
/// Android manifest and iOS Info.plist). On web we pass null so Supabase falls
/// back to the project's configured Site URL.
const String kOAuthRedirect = 'com.mabanda.mambandamarket://login-callback';

/// Where the password-recovery email link returns the user.
///
/// Supabase opens this after the user clicks "reset password" in their inbox;
/// the app receives a `passwordRecovery` auth event and can then set a new
/// password using the short-lived recovery session.
const String kPasswordResetRedirect =
    'com.mabanda.mambandamarket://password-reset';

/// Authentication + the signed-in user's profile.
///
/// Supabase Auth issues the JWT; the Core API turns it into a `profiles` row via
/// `/auth/sync` on first sign-in. The same token authenticates every API call
/// (and later the Chat API), so there is one identity across the whole product.
class AuthService {
  AuthService._() {
    _client.auth.onAuthStateChange.listen((state) async {
      final signedIn = state.session != null;
      isSignedIn.value = signedIn;

      // Arriving from a recovery link. Supabase grants a limited session whose
      // only purpose is setting a new password — flag it so the app routes to
      // the reset screen instead of dropping the user into the marketplace.
      if (state.event == AuthChangeEvent.passwordRecovery) {
        passwordRecoveryRequested.value = true;
        return;
      }

      if (!signedIn) {
        me.value = null;
        return;
      }
      // OAuth completes outside our sign-in methods (the user returns via the
      // deep link), so materialize the profile here — this is the one place
      // every successful sign-in passes through. Idempotent.
      if (state.event == AuthChangeEvent.signedIn) {
        try {
          await syncProfile(
            displayName: state.session?.user.userMetadata?['full_name']
                    as String? ??
                state.session?.user.userMetadata?['name'] as String?,
          );
          await refreshMe();
        } catch (_) {
          // Non-fatal: the app still works, /me just retries later.
        }
      }
    });
    isSignedIn.value = _client.auth.currentSession != null;
  }
  static final AuthService instance = AuthService._();

  final SupabaseClient _client = Supabase.instance.client;

  /// Current session state, for reactive UI (splash routing, account screen).
  final ValueNotifier<bool> isSignedIn = ValueNotifier(false);

  /// Profile + entitlements from `/me`; null until loaded or when signed out.
  final ValueNotifier<Me?> me = ValueNotifier(null);

  /// Fires when the user arrives from a password-recovery link, so the app can
  /// show the "set a new password" screen.
  final ValueNotifier<bool> passwordRecoveryRequested = ValueNotifier(false);

  Session? get session => _client.auth.currentSession;
  User? get user => _client.auth.currentUser;
  String? get userId => user?.id;

  /// True once the address has been confirmed. Unconfirmed accounts can exist
  /// (and even hold a session) when confirmations are enabled, so screens use
  /// this to nudge rather than assume.
  bool get isEmailConfirmed => user?.emailConfirmedAt != null;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
    await syncProfile();
    await refreshMe();
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
    String role = 'buyer',
  }) async {
    await _client.auth.signUp(email: email, password: password);
    // With email confirmation enabled there is no session yet; the profile is
    // synced on the first successful sign-in instead.
    if (session != null) {
      await syncProfile(displayName: displayName, role: role);
      await refreshMe();
    }
  }

  /// Google sign-in. Opens the consent screen; on mobile the user returns to
  /// the app through the deep link and `onAuthStateChange` finishes the job
  /// (profile sync + entitlements), so callers just await this and react to
  /// the session appearing.
  ///
  /// Returns false if the user dismissed the consent screen.
  Future<bool> signInWithGoogle() async {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : kOAuthRedirect,
      authScreenLaunchMode:
          kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );
  }

  /// Email a password-recovery link.
  ///
  /// Deliberately does not reveal whether the address has an account — the
  /// caller shows the same confirmation either way, so this can't be used to
  /// enumerate registered users.
  Future<void> sendPasswordReset(String email) async {
    await _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: kIsWeb ? null : kPasswordResetRedirect,
    );
  }

  /// Set a new password. Requires either a normal session or the short-lived
  /// recovery session created by the emailed link.
  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
    passwordRecoveryRequested.value = false;
  }

  /// Re-send the sign-up confirmation email.
  Future<void> resendConfirmation(String email) async {
    await _client.auth.resend(type: OtpType.signup, email: email.trim());
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    me.value = null;
  }

  /// Create/update the caller's profile row. Idempotent — safe on every login.
  Future<void> syncProfile({
    String? displayName,
    String? role,
    String? phone,
    String? city,
  }) async {
    if (session == null) return;
    await ApiClient.instance.post('/auth/sync', {
      if (displayName != null) 'display_name': displayName,
      if (role != null) 'role': role,
      if (phone != null) 'phone': phone,
      if (city != null) 'city': city,
    });
  }

  /// Load profile + subscription + entitlements.
  Future<Me?> refreshMe() async {
    if (session == null) {
      me.value = null;
      return null;
    }
    final json = await ApiClient.instance.get('/me') as Map<String, dynamic>;
    final value = Me.fromJson(json);
    me.value = value;
    return value;
  }

  Future<Profile?> updateProfile(Map<String, dynamic> fields) async {
    final json =
        await ApiClient.instance.patch('/me', fields) as Map<String, dynamic>;
    await refreshMe();
    final p = (json['profile'] as Map?)?.cast<String, dynamic>();
    return p == null ? null : Profile.fromJson(p);
  }
}
