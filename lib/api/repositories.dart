import 'dart:io';

// `hide Category`: foundation exports a `Category` annotation that would clash
// with our marketplace Category model.
import 'package:flutter/foundation.dart' hide Category;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api_client.dart';
import 'auth_service.dart';
import 'models.dart';

/// Browse, publish and manage listings.
class ListingsRepository {
  ListingsRepository._();
  static final ListingsRepository instance = ListingsRepository._();

  final _api = ApiClient.instance;

  /// Browse / search. Every filter is optional; the server applies full-text
  /// search, category/price filters and PostGIS radius in one query.
  Future<List<Listing>> browse({
    String? query,
    String? categorySlug,
    int? minCents,
    int? maxCents,
    String? condition,
    double? lat,
    double? lng,
    int? radiusMeters,
    String sort = 'recent',
    int limit = 20,
    int offset = 0,
  }) async {
    final json = await _api.get('/listings', query: {
      'q': query,
      'category': categorySlug,
      'min': minCents,
      'max': maxCents,
      'condition': condition,
      if (lat != null && lng != null) 'near': '$lat,$lng',
      'radius': radiusMeters,
      'sort': sort,
      'limit': limit,
      'offset': offset,
    }) as Map<String, dynamic>;

    return (json['items'] as List? ?? [])
        .whereType<Map>()
        .map((m) => Listing.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  Future<Listing> detail(String id) async {
    final json = await _api.get('/listings/$id') as Map<String, dynamic>;
    return Listing.fromJson(
        (json['listing'] as Map).cast<String, dynamic>());
  }

  Future<List<Category>> categories() async {
    // Categories are seeded reference data, read straight from Supabase under
    // RLS (public read) — no need for an API round-trip.
    final rows = await Supabase.instance.client
        .from('categories')
        .select('slug,label,icon,sort_order')
        .order('sort_order');
    return (rows as List)
        .whereType<Map>()
        .map((m) => Category.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  /// Publish. Throws [ApiException] with `isListingLimit` when the plan quota
  /// is exhausted — surface that as an upgrade prompt.
  Future<Listing> create({
    required String title,
    String? description,
    required int priceCents,
    String currency = 'EUR',
    int quantity = 1,
    required String categorySlug,
    String? condition,
    bool hasGuarantee = false,
    String? city,
    double? lat,
    double? lng,
    List<String> imagePaths = const [],
  }) async {
    final json = await _api.post('/listings', {
      'title': title,
      if (description != null && description.isNotEmpty)
        'description': description,
      'price_cents': priceCents,
      'currency': currency,
      'quantity': quantity,
      'category_slug': categorySlug,
      if (condition != null) 'condition': condition,
      'has_guarantee': hasGuarantee,
      if (city != null && city.isNotEmpty) 'city': city,
      if (lat != null && lng != null) 'location': [lng, lat],
      if (imagePaths.isNotEmpty)
        'images': [
          for (var i = 0; i < imagePaths.length; i++)
            {'storage_path': imagePaths[i], 'position': i}
        ],
    }) as Map<String, dynamic>;
    return Listing.fromJson((json['listing'] as Map).cast<String, dynamic>());
  }

  Future<void> update(String id, Map<String, dynamic> fields) =>
      _api.patch('/listings/$id', fields);

  /// Close a sale. The server verifies ownership and records it in `sales`.
  Future<void> markSold(String id, {int? soldPriceCents, String? buyerId}) =>
      _api.patch('/listings/$id', {
        'action': 'mark_sold',
        if (soldPriceCents != null) 'sold_price_cents': soldPriceCents,
        if (buyerId != null) 'buyer_id': buyerId,
      });

  Future<void> delete(String id) => _api.delete('/listings/$id');

  Future<SellerDashboard> dashboard(String sellerId) async {
    final json =
        await _api.get('/sellers/$sellerId/dashboard') as Map<String, dynamic>;
    return SellerDashboard.fromJson(json);
  }

  /// Upload an image straight to Supabase Storage using a short-lived signed
  /// URL from the API, and return the storage path to attach to a listing.
  Future<String> uploadImage(File file, {String? listingId}) async {
    final ext = file.path.split('.').last.toLowerCase();
    final signed = await _api.post('/uploads/sign', {
      'bucket': 'listing-images',
      'ext': ['jpg', 'jpeg', 'png', 'webp', 'gif', 'heic'].contains(ext)
          ? ext
          : 'jpg',
      if (listingId != null) 'listing_id': listingId,
    }) as Map<String, dynamic>;

    final path = signed['path'].toString();
    await Supabase.instance.client.storage
        .from('listing-images')
        .uploadToSignedUrl(path, signed['token'].toString(), file);
    return path;
  }
}

/// Saved items. Keeps a local set of ids so cards can render instantly while
/// the server stays the source of truth.
class FavoritesRepository {
  FavoritesRepository._();
  static final FavoritesRepository instance = FavoritesRepository._();

  final _api = ApiClient.instance;

  final ValueNotifier<List<Listing>> favorites = ValueNotifier([]);
  final ValueNotifier<Set<String>> favoriteIds = ValueNotifier({});

  Future<void> refresh() async {
    if (AuthService.instance.session == null) {
      favorites.value = [];
      favoriteIds.value = {};
      return;
    }
    final json = await _api.get('/favorites') as Map<String, dynamic>;
    final items = (json['items'] as List? ?? [])
        .whereType<Map>()
        .map((m) => (m['listing'] as Map?)?.cast<String, dynamic>())
        .whereType<Map<String, dynamic>>()
        .map(Listing.fromJson)
        .toList();
    favorites.value = items;
    favoriteIds.value = items.map((l) => l.id).toSet();
  }

  bool isFavorite(String listingId) => favoriteIds.value.contains(listingId);

  /// Optimistic toggle — reverts if the server rejects it.
  Future<void> toggle(String listingId) async {
    final wasFavorite = isFavorite(listingId);
    final ids = Set<String>.from(favoriteIds.value);
    wasFavorite ? ids.remove(listingId) : ids.add(listingId);
    favoriteIds.value = ids;

    try {
      if (wasFavorite) {
        await _api.delete('/favorites/$listingId');
        favorites.value =
            favorites.value.where((l) => l.id != listingId).toList();
      } else {
        await _api.post('/favorites/$listingId');
        await refresh();
      }
    } catch (_) {
      final reverted = Set<String>.from(favoriteIds.value);
      wasFavorite ? reverted.add(listingId) : reverted.remove(listingId);
      favoriteIds.value = reverted;
      rethrow;
    }
  }
}
