import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api_client.dart';
import 'auth_service.dart';
import 'models.dart';
import 'shipping_model.dart';

/// Asking us to ship something.
///
/// The catalogue uses the same three layers as [BoardRepository] — whatever the
/// API last returned, then the device's copy, then nothing — because a list of
/// box sizes is exactly the kind of thing worth showing from yesterday. It is
/// fetched when the form opens rather than at launch: it is a few kilobytes
/// almost every session never needs, and the splash screen already waits on
/// enough.
///
/// Nothing here throws.
class ShippingRepository {
  ShippingRepository._();
  static final ShippingRepository instance = ShippingRepository._();

  static const _cacheKey = 'shipping_options_v1';

  final ValueNotifier<ShippingOptions> options = ValueNotifier(const ShippingOptions());

  bool _readCache = false;

  /// Whether the app should show any way in at all.
  bool get enabled => options.value.enabled;

  Future<void> loadOptions() async {
    if (!_readCache) {
      _readCache = true;
      await _readFromDisk();
    }
    try {
      final json = await ApiClient.instance.get('/shipping/options') as Map<String, dynamic>;
      options.value = ShippingOptions.fromJson(json);
      await _writeToDisk(json);
    } catch (e) {
      debugPrint('[shipping] could not refresh options, keeping what we had ($e)');
    }
  }

  /// Create a request. Returns the request and the conversation it opened, so
  /// the caller can go straight to the thread.
  Future<({ShippingRequest? request, Conversation? conversation})> create({
    required String source,
    String? listingId,
    String? itemTitle,
    String? productUrl,
    String? description,
    String? categorySlug,
    required String sizeKey,
    String? sizeCustom,
    int quantity = 1,
    int? budgetCents,
    required String fromLocation,
    required String toLocation,
    String? contactName,
    required String contactPhone,
    String? deliveryAddress,
    String? note,
    List<String> photoPaths = const [],
    String locale = 'en',
  }) async {
    final json = await ApiClient.instance.post('/shipping-requests', {
      'source': source,
      if (listingId != null) 'listing_id': listingId,
      if (itemTitle != null && itemTitle.isNotEmpty) 'item_title': itemTitle,
      if (productUrl != null && productUrl.isNotEmpty) 'item_url': productUrl,
      if (description != null && description.isNotEmpty) 'item_description': description,
      if (categorySlug != null && categorySlug.isNotEmpty) 'category_slug': categorySlug,
      'size_key': sizeKey,
      if (sizeCustom != null && sizeCustom.isNotEmpty) 'size_custom': sizeCustom,
      'quantity': quantity,
      if (budgetCents != null) 'budget_cents': budgetCents,
      'from_location': fromLocation,
      'to_location': toLocation,
      if (contactName != null && contactName.isNotEmpty) 'contact_name': contactName,
      'contact_phone': contactPhone,
      if (deliveryAddress != null && deliveryAddress.isNotEmpty) 'delivery_address': deliveryAddress,
      if (note != null && note.isNotEmpty) 'note': note,
      if (photoPaths.isNotEmpty) 'photo_paths': photoPaths,
      'locale': locale,
    }) as Map<String, dynamic>;

    final conv = (json['conversation'] as Map?)?.cast<String, dynamic>();
    return (
      request: ShippingRequest.fromJson((json['request'] as Map?)?.cast<String, dynamic>()),
      // A request that was created but whose thread did not come back is still
      // a success: never lose a submitted request to a secondary failure.
      conversation: conv == null ? null : Conversation.fromJson(conv),
    );
  }

  /// The caller's own shipments, newest first.
  final ValueNotifier<List<ShippingRequest>> shipments = ValueNotifier(const []);

  Future<void> refreshMine() async {
    try {
      final json = await ApiClient.instance.get('/shipping-requests') as Map<String, dynamic>;
      shipments.value = (json['items'] as List? ?? const [])
          .whereType<Map>()
          .map((m) => ShippingRequest.fromJson(m.cast<String, dynamic>()))
          .whereType<ShippingRequest>()
          .toList(growable: false);
    } catch (e) {
      debugPrint('[shipping] could not load shipments, keeping what we had ($e)');
    }
  }

  /// One shipment, with its whole journey.
  Future<ShippingRequest?> detail(String id) async {
    final json = await ApiClient.instance.get('/shipping-requests/$id') as Map<String, dynamic>;
    return ShippingRequest.fromJson(
      (json['request'] as Map?)?.cast<String, dynamic>(),
      tracking: json['tracking'] as List?,
    );
  }

  /// Follow the caller's shipments as they move.
  ///
  /// Subscribed to the request row rather than the checkpoint log, because a
  /// trigger touches the row on every checkpoint — so one row per shipment is
  /// enough to know something happened, and no location travels over the
  /// socket. The detail comes back over the authenticated call, where the read
  /// rules already are. Exactly the shape chat uses, for the same reasons.
  void startLive() {
    final uid = AuthService.instance.userId;
    if (uid == null || _live != null) return;
    _live = Supabase.instance.client
        .channel('shipping:$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shipping_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (_) => _onLiveChange(),
        )
        .subscribe();
  }

  Future<void> stopLive() async {
    final channel = _live;
    _live = null;
    _debounce?.cancel();
    if (channel != null) await Supabase.instance.client.removeChannel(channel);
  }

  RealtimeChannel? _live;
  Timer? _debounce;

  /// A single checkpoint writes several columns, which arrive as several
  /// events. Collapse them so the list is fetched once.
  void _onLiveChange() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      refreshMine();
      pulse.value++;
    });
  }

  /// Bumped whenever something moved, so an open detail screen can refetch.
  final ValueNotifier<int> pulse = ValueNotifier(0);

  Future<void> _readFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map) options.value = ShippingOptions.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {
      // A corrupt cache costs one fetch, not a broken form.
    }
  }

  Future<void> _writeToDisk(Map<String, dynamic> json) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(json));
    } catch (_) {
      // Storage unavailable — the value still applies for this session.
    }
  }
}
