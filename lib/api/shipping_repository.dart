import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
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

  /// The caller's own requests.
  Future<List<ShippingRequest>> mine() async {
    try {
      final json = await ApiClient.instance.get('/shipping-requests') as Map<String, dynamic>;
      return (json['items'] as List? ?? const [])
          .whereType<Map>()
          .map((m) => ShippingRequest.fromJson(m.cast<String, dynamic>()))
          .whereType<ShippingRequest>()
          .toList();
    } catch (e) {
      debugPrint('[shipping] could not load requests ($e)');
      return const [];
    }
  }

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
