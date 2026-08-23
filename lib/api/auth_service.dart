import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api_client.dart';
import 'remote_config.dart';
import 'models.dart';
import 'push_service.dart';

/// Where Google sends the user back after consent.
///
/// On mobile this is a custom scheme handled by the app (registered in the
/// Android manifest and iOS Info.plist).
const String kOAuthRedirect = 'com.mabanda.mambandamarket://login-callback';

/// Where the password-recovery email link returns the user.
///
/// Supabase opens this after the user clicks "reset password" in their inbox;
/// the app receives a `passwordRecovery` auth event and can then set a new
/// password using the short-lived recovery session.
const String kPasswordResetRedirect =
    'com.mabanda.mambandamarket://password-reset';

/// Where auth flows return to, for whichever platform this is running on.
///
/// On web this must be the page's own origin. Passing null there does not mean
/// "come back here" — Supabase falls back to the project's Site URL, which is
/// the marketing site, so the user would finish signing in and land on a page
/// that is not the app at all, with the session left behind in a redirect they
/// never saw. Both web origins are on the project's redirect allowlist.
String _redirectFor(String mobileScheme) =>
    kIsWeb ? Uri.base.origin : mobileScheme;

/// How a sign-up attempt ended.
///
/// `alreadyRegistered` exists because Supabase does not treat a duplicate
/// address as an error — it answers as though the account were new so the
/// endpoint cannot be used to discover who has registered. The caller has to
/// distinguish it, or someone with an existing account is told to check their
/// email for a message that will never come.
enum SignUpOutcome {
  /// Confirmations are off: there is a session and the profile is synced.
  signedIn,

  /// Account created; the user must confirm by email before signing in.
  confirmationRequired,

  /// The address already has an account. Send them to sign-in instead.
  alreadyRegistered,
}

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
        needsRoleSelection.value = false;
        return;
      }
      // OAuth completes outside our sign-in methods (the user returns via the
      // deep link), so finish the job here — this is the one place every
      // successful sign-in passes through.
      if (state.event == AuthChangeEvent.signedIn) {
        final user = state.session!.user;
        final meta = user.userMetadata;
        final signupName =
            meta?['full_name'] as String? ?? meta?['name'] as String?;
        // Role chosen at sign-up. The email flow stashes it in user_metadata so
        // it survives the confirmation gap (no session there to sync it);
        // Google sign-ups carry no role yet.
        final metaRole = meta?['role'] as String?;
        try {
          // Load the profile first — its absence means this is a brand-new
          // account whose type hasn't been recorded yet.
          final loaded = await refreshMe();
          if (loaded?.profile == null) {
            if (metaRole != null && metaRole.isNotEmpty) {
              // Email sign-up: materialize the profile with the chosen role +
              // name, then send seller/business on to the subscription step.
              await syncProfile(role: metaRole, displayName: signupName);
              await refreshMe();
              needsRoleSelection.value = false;
              if (metaRole == 'individual_seller' || metaRole == 'business') {
                pendingSubscriptionRole = metaRole;
              }
            } else if (RemoteConfig.instance.roleSelectionEnabled) {
              // Social sign-up with no role yet → must pick one before entering,
              // rather than silently defaulting to buyer.
              pendingOAuthDisplayName = signupName;
              needsRoleSelection.value = true;
            } else {
              // Not asking: create the profile with the configured role and let
              // them straight in. `justSignedUpSocially` is what tells the
              // welcome screen to still offer the referral step — that prompt
              // used to live on the role screen, and skipping the screen must
              // not quietly cost referrers their credit.
              await syncProfile(
                role: RemoteConfig.instance.defaultSignupRole,
                displayName: signupName,
              );
              await refreshMe();
              needsRoleSelection.value = false;
              justSignedUpSocially = true;
            }
          } else {
            needsRoleSelection.value = false;
          }
          // A code parked at sign-up can only be claimed once a profile exists.
          // This handler is the one place every sign-in passes through — email,
          // Google, or a session restored at launch — so claiming here is what
          // makes a referral survive any route through onboarding. It is a
          // no-op when nothing is parked. Skipped while role selection is
          // pending: there is no profile yet to attach the referral to, and
          // RoleSelectionScreen claims it as soon as it creates one.
          if (!needsRoleSelection.value) await redeemPendingReferral();
        } catch (_) {
          // Non-fatal: the app still works, /me just retries later.
        } finally {
          // Signal screens that routing can now proceed (profile loaded and the
          // new-account decision made) — so they never navigate on a
          // half-resolved session.
          signInResolved.value++;
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

  /// True after a social (Google) sign-in for an account that has no profile
  /// yet — the app must ask which kind of account to create before entering.
  /// Cleared once a role is chosen (or on sign-out).
  final ValueNotifier<bool> needsRoleSelection = ValueNotifier(false);

  /// Bumped once a sign-in has been fully processed (profile loaded and, for
  /// social sign-ups, [needsRoleSelection] decided). Auth screens wait on this
  /// before routing so they don't navigate on a half-resolved session.
  final ValueNotifier<int> signInResolved = ValueNotifier(0);

  /// True for the one sign-in that created a social account, when the
  /// account-type step was switched off. The referral prompt used to be pushed
  /// by that step; this is how the screen after sign-in knows to offer it
  /// instead. Consumed (cleared) by whoever shows it.
  bool justSignedUpSocially = false;

  /// The name Google gave us, kept so the role-selection step can persist it
  /// alongside the chosen role when it finally creates the profile.
  String? pendingOAuthDisplayName;

  /// Set when a brand-new seller/business account is first established (the
  /// email flow after confirmation, or an immediate signup), so the sign-in
  /// resolver sends them to the subscription step once — mirroring the Google
  /// role-selection flow. Consumed (cleared) by the resolver.
  String? pendingSubscriptionRole;

  Session? get session => _client.auth.currentSession;
  User? get user => _client.auth.currentUser;
  String? get userId => user?.id;

  /// True once the address has been confirmed. Unconfirmed accounts can exist
  /// (and even hold a session) when confirmations are enabled, so screens use
  /// this to nudge rather than assume.
  bool get isEmailConfirmed => user?.emailConfirmedAt != null;

  /// Effective moderation state from the last `/me` load (active by default).
  Moderation get moderation => me.value?.moderation ?? const Moderation();

  /// A blocked or actively-suspended account must be sent to the blocker screen
  /// instead of into the app.
  bool get isAccountRestricted => moderation.isRestricted;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
    // Profile materialization + entitlements happen in the onAuthStateChange
    // handler (the single path every sign-in takes), which also applies the
    // role chosen at sign-up. Syncing here too would race that and could create
    // the profile as a plain buyer before the chosen role is read back.
  }

  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    String? displayName,
    String role = 'buyer',
  }) async {
    // Carry the chosen role + name in user_metadata so they survive the email
    // confirmation gap (with confirmations on there's no session yet, hence
    // nothing to sync). onAuthStateChange reads them back and materializes the
    // profile on the first successful sign-in.
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        if (displayName != null && displayName.trim().isNotEmpty)
          'full_name': displayName.trim(),
        'role': role,
      },
    );

    // Signing up with an address that already has an account is NOT an error
    // in Supabase: it returns a session-less user so the response cannot be
    // used to enumerate who is registered. Left unhandled that shows "check
    // your email" to someone who already has an account and is simply trying
    // to sign in — they wait for a mail that never arrives.
    //
    // The tell is an empty identity list, which only ever happens in this case.
    if (session == null && (res.user?.identities?.isEmpty ?? false)) {
      return SignUpOutcome.alreadyRegistered;
    }
    // Confirmations disabled ⇒ signed in immediately; sync now and flag the
    // subscription step for paid roles.
    if (session != null) {
      await syncProfile(displayName: displayName, role: role);
      await refreshMe();
      if (role == 'individual_seller' || role == 'business') {
        pendingSubscriptionRole = role;
      }
      return SignUpOutcome.signedIn;
    }
    return SignUpOutcome.confirmationRequired;
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
      redirectTo: _redirectFor(kOAuthRedirect),
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
      redirectTo: _redirectFor(kPasswordResetRedirect),
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
    // Before the session goes, not after: removing a device token is an
    // authenticated call. Left behind, it would keep this phone receiving
    // another account's messages after somebody else signed in on it.
    await PushService.instance.unregister();
    await _client.auth.signOut();
    me.value = null;
    needsRoleSelection.value = false;
    pendingOAuthDisplayName = null;
    pendingSubscriptionRole = null;
    justSignedUpSocially = false;
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

  // ── Referral held over from sign-up ────────────────────────────────────────
  //
  // A referral can only be claimed once a session exists, but sign-up often
  // ends at "check your email" — the user leaves, confirms, and comes back to
  // the login screen, by which point an in-memory code is long gone. Parking it
  // in preferences is what makes the code someone typed at sign-up actually
  // count when they finally arrive.
  static const _kPendingReferral = 'pending_referral_code';

  Future<void> stashReferralCode(String code) async {
    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPendingReferral, trimmed);
    } catch (_) {
      // Storage unavailable — the referral is lost, but sign-up must not fail
      // over it.
    }
  }

  /// Redeem anything parked at sign-up. Safe to call on every launch: the
  /// server treats attribution as write-once, and the code is cleared whether
  /// it was accepted or rejected, so a bad code is not retried forever.
  ///
  /// Returns true when a parked code was consumed (accepted or refused), so a
  /// caller can skip asking for one it has already dealt with.
  Future<bool> redeemPendingReferral() async {
    if (session == null) return false;
    // Mid-onboarding for a social sign-up: the profile is deliberately not
    // created until a role is chosen, and the no_profile retry below would
    // create a roleless one — quietly turning a seller into a buyer before they
    // ever reach the subscription step. RoleSelectionScreen calls this the
    // moment it creates the profile instead.
    if (needsRoleSelection.value) return false;
    SharedPreferences prefs;
    String? code;
    try {
      prefs = await SharedPreferences.getInstance();
      code = prefs.getString(_kPendingReferral);
    } catch (_) {
      return false;
    }
    if (code == null || code.isEmpty) return false;

    try {
      await ApiClient.instance.post('/referrals/apply', {'code': code});
    } on ApiException catch (e) {
      // The server reached a verdict. Anything other than "not ready yet" is
      // final — clear the code so this stops running on every launch.
      if (e.code == 'no_profile') {
        // /auth/sync has not created the profile yet. Sync and try once more;
        // if that still fails the code stays parked for the next launch.
        try {
          await syncProfile();
          await ApiClient.instance.post('/referrals/apply', {'code': code});
        } catch (_) {
          return false; // keep the code
        }
      }
    } catch (_) {
      // Offline, or the server is unhappy. Keep the code: discarding it here
      // would quietly cost the person who invited them their credit, which is
      // the one outcome this whole feature exists to prevent.
      return false;
    }
    await prefs.remove(_kPendingReferral);
    return true;
  }

  /// Best-effort top-up of [me] when it is missing.
  ///
  /// The splash screen warms the profile at launch, but it swallows failures —
  /// so one offline moment or a token refresh landing mid-flight leaves `me`
  /// null for the whole session. Everything gated on a role then quietly
  /// disappears, and a verified company loses its dashboard until it happens to
  /// pull-to-refresh. Screens that depend on the profile call this on entry so
  /// the state repairs itself; it is a no-op once the profile is loaded.
  Future<void> ensureMe() async {
    if (session == null || me.value != null) return;
    try {
      await refreshMe();
    } catch (_) {
      // Still offline — leave `me` as-is; the next screen entry retries.
    }
  }

  Future<Profile?> updateProfile(Map<String, dynamic> fields) async {
    final json =
        await ApiClient.instance.patch('/me', fields) as Map<String, dynamic>;
    await refreshMe();
    final p = (json['profile'] as Map?)?.cast<String, dynamic>();
    return p == null ? null : Profile.fromJson(p);
  }
}
