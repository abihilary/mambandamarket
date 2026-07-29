import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api_client.dart';
import 'models.dart';

/// Authentication + the signed-in user's profile.
///
/// Supabase Auth issues the JWT; the Core API turns it into a `profiles` row via
/// `/auth/sync` on first sign-in. The same token authenticates every API call
/// (and later the Chat API), so there is one identity across the whole product.
class AuthService {
  AuthService._() {
    _client.auth.onAuthStateChange.listen((state) {
      final signedIn = state.session != null;
      isSignedIn.value = signedIn;
      if (!signedIn) me.value = null;
    });
    isSignedIn.value = _client.auth.currentSession != null;
  }
  static final AuthService instance = AuthService._();

  final SupabaseClient _client = Supabase.instance.client;

  /// Current session state, for reactive UI (splash routing, account screen).
  final ValueNotifier<bool> isSignedIn = ValueNotifier(false);

  /// Profile + entitlements from `/me`; null until loaded or when signed out.
  final ValueNotifier<Me?> me = ValueNotifier(null);

  Session? get session => _client.auth.currentSession;
  User? get user => _client.auth.currentUser;
  String? get userId => user?.id;

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
