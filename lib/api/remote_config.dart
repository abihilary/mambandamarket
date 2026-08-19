import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

/// Settings the server decides and the app obeys.
///
/// Some product behaviour has to be changeable without an app release — whether
/// sign-up asks what kind of account somebody wants, how much a plain buyer may
/// post. An APK takes days to reach people and reverting one takes another
/// release, so those decisions live on the server and are read from here.
///
/// Three layers, in order: whatever the API last returned, then the last values cached
/// on this device, then the compile-time defaults below. A launch with no
/// network therefore behaves exactly as the last one did rather than snapping
/// back to a default the operator may have changed months ago.
class RemoteConfig {
  RemoteConfig._();
  static final RemoteConfig instance = RemoteConfig._();

  static const _kCacheKey = 'remote_config_v1';

  /// Matches what the 0026 migration seeds, so a first launch that cannot reach
  /// the API still behaves the way production is configured rather than the way
  /// the app happened to be written.
  static const _defaults = <String, dynamic>{
    'role_selection_enabled': false,
    'default_role': 'buyer',
    'buyer_listing_limit': 3,
  };

  Map<String, dynamic> _values = Map.of(_defaults);

  /// Whether sign-up asks the user to choose an account type. When false the
  /// step is skipped entirely and [defaultSignupRole] is applied silently.
  bool get roleSelectionEnabled =>
      _values['role_selection_enabled'] as bool? ?? false;

  /// The role given to a new account when the question is not asked.
  String get defaultSignupRole =>
      _values['default_role'] as String? ?? 'buyer';

  /// How many listings an account with no subscription may have. Advisory only
  /// — the server enforces the real limit — but it keeps the app from offering
  /// a form that is going to be rejected.
  int get buyerListingLimit => _values['buyer_listing_limit'] as int? ?? 3;

  /// Load the cache, then refresh from the API.
  ///
  /// Never throws and never blocks startup on the network: the splash screen
  /// awaits this, and a marketplace that will not open because a settings
  /// endpoint is slow is worse than one running on yesterday's settings.
  Future<void> load() async {
    await _readCache();
    try {
      final json = await ApiClient.instance.get('/config') as Map<String, dynamic>;
      final signup = (json['signup'] as Map?)?.cast<String, dynamic>() ?? {};
      final limits = (json['limits'] as Map?)?.cast<String, dynamic>() ?? {};

      _values = {
        'role_selection_enabled':
            signup['role_selection_enabled'] as bool? ?? _defaults['role_selection_enabled'],
        'default_role': signup['default_role'] as String? ?? _defaults['default_role'],
        'buyer_listing_limit':
            (limits['buyer_listing_limit'] as num?)?.toInt() ?? _defaults['buyer_listing_limit'],
      };
      await _writeCache();
    } catch (_) {
      // Offline, or the endpoint is unhappy. Whatever _readCache found stands.
    }
  }

  Future<void> _readCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCacheKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        _values = {..._defaults, ...decoded.cast<String, dynamic>()};
      }
    } catch (_) {
      // A corrupt or unavailable cache is not worth failing a launch over.
    }
  }

  Future<void> _writeCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCacheKey, jsonEncode(_values));
    } catch (_) {
      // Storage unavailable — the values still apply for this session.
    }
  }
}
