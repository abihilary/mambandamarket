import 'dart:async';

import 'package:cross_file/cross_file.dart';

// `hide Category`: foundation exports a `Category` annotation that would clash
// with our marketplace Category model.
import 'package:flutter/foundation.dart' hide Category;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/l10n.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'cache_rules.dart';
import 'chat_store.dart';
import 'chat_sync.dart';
import 'location_share.dart';
import 'models.dart';
import 'offline_cache.dart';

String? _uid() {
  try {
    return AuthService.instance.userId;
  } catch (_) {
    return null;
  }
}

/// The listings in a body's [key] list.
List<Listing> _listingsOf(Object? json, {String key = 'items'}) =>
    ((json is Map ? json[key] : null) as List? ?? const [])
        .whereType<Map>()
        .map((m) => Listing.fromJson(m.cast<String, dynamic>()))
        .toList();

/// A saved list as it may be shown: without the listings the network has
/// since said are gone, and without any the saved copy itself shows as not
/// live. Only for saved answers; a network answer is shown as it is.
List<Listing> _liveOnly(List<Listing> items) =>
    [for (final l in items) if (!OfflineCache.isGone(l.id) && l.status == 'active') l];

/// A stamp for a filtered list: the body's own, plus how many were left out,
/// so the same body filtered differently still repaints.
String _stampMinus(String stamp, int removed) => removed == 0 ? stamp : '$stamp:$removed';

/// The network showed these live: whatever was remembered as gone (sold,
/// then relisted) is not any more.
void _noteActive(Iterable<Listing> items) {
  for (final l in items) {
    if (l.status == 'active') OfflineCache.unGone(l.id);
  }
}

/// Browse, publish and manage listings.
class ListingsRepository {
  ListingsRepository._();
  static final ListingsRepository instance = ListingsRepository._();

  final _api = ApiClient.instance;

  /// Bumped whenever this device changes the catalogue.
  ///
  /// Screens that hold a list of listings watch this instead of each caller
  /// remembering to refresh whatever else might be showing the same data. The
  /// two dashboards did reload themselves after publishing, but the home feed
  /// — which lives in an IndexedStack and is built once at launch — did not,
  /// so a seller published an item and then could not find it in the app.
  ///
  /// Deliberately a counter and not the listing: a watcher's job is to refetch,
  /// not to splice one object into a list it did not build.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// The one place the browse query is built, so the saved-first paint and
  /// the read that follows ask for exactly the same address. `near` is
  /// rounded to about 100 m: a GPS fix that wobbles in the fifth decimal
  /// would otherwise make every launch a new address with nothing saved.
  Map<String, dynamic> _browseQuery({
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
    Map<String, String> attrs = const {},
  }) =>
      {
        for (final e in attrs.entries) 'attr.${e.key}': e.value,
        'q': query,
        'category': categorySlug,
        'min': minCents,
        'max': maxCents,
        'condition': condition,
        if (lat != null && lng != null) 'near': '${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}',
        'radius': radiusMeters,
        'sort': sort,
        'limit': limit,
        'offset': offset,
      };

  /// The saved copy of this browse, for a first paint, or null. Listings the
  /// network has since said are gone are left out.
  Saved<List<Listing>>? savedBrowse({
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
    Map<String, String> attrs = const {},
  }) =>
      _savedListings(_api.saved('/listings',
          query: _browseQuery(
            query: query,
            categorySlug: categorySlug,
            minCents: minCents,
            maxCents: maxCents,
            condition: condition,
            lat: lat,
            lng: lng,
            radiusMeters: radiusMeters,
            sort: sort,
            limit: limit,
            offset: offset,
            attrs: attrs,
          )));

  /// Browse / search. Every filter is optional; the server applies full-text
  /// search, category/price filters and PostGIS radius in one query.
  Future<Fetched<List<Listing>>> fetchBrowse({
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
    // A detail of [categorySlug]'s template to match, e.g. {'sizes': 'M'}.
    Map<String, String> attrs = const {},
  }) async =>
      _fetchedListings(await _api.read('/listings',
          query: _browseQuery(
            query: query,
            categorySlug: categorySlug,
            minCents: minCents,
            maxCents: maxCents,
            condition: condition,
            lat: lat,
            lng: lng,
            radiusMeters: radiusMeters,
            sort: sort,
            limit: limit,
            offset: offset,
            attrs: attrs,
          )));

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
    // A detail of [categorySlug]'s template to match, e.g. {'sizes': 'M'}.
    Map<String, String> attrs = const {},
  }) async =>
      (await fetchBrowse(
        query: query,
        categorySlug: categorySlug,
        minCents: minCents,
        maxCents: maxCents,
        condition: condition,
        lat: lat,
        lng: lng,
        radiusMeters: radiusMeters,
        sort: sort,
        limit: limit,
        offset: offset,
        attrs: attrs,
      ))
          .value;

  /// A saved listing, for a first paint: null when the network has said it is
  /// gone, when the saved copy is not live (unless it is the caller's own),
  /// or when it is too old to show before the network answers.
  Listing? savedDetail(String id) {
    if (OfflineCache.isGone(id)) return null;
    final s = _api.saved('/listings/$id');
    final m = s?.body is Map ? (s!.body as Map)['listing'] : null;
    if (m is! Map) return null;
    final listing = Listing.fromJson(m.cast<String, dynamic>());
    return _showableSaved(listing) ? listing : null;
  }

  /// Whether a listing from the device may be shown: not one the network has
  /// since said is gone, and live unless it is the caller's own.
  bool _showableSaved(Listing l) =>
      !OfflineCache.isGone(l.id) && (l.status == 'active' || l.sellerId == _uid());

  /// [card] (from a feed) filled in with what only the saved detail has. The
  /// card keeps its title, price, mode, status, quantity and primary image:
  /// it is the fresher of the two.
  Listing? savedDetailFor(Listing card) {
    final saved = savedDetail(card.id);
    return saved == null ? null : card.withDetailFrom(saved);
  }

  /// The listing in full. Throws [ApiException] with `isGone` on 404/410, and
  /// then remembers it is gone so no saved copy shows it as live again.
  ///
  /// With no network it may answer from the device ([Fetched.isSaved]): not
  /// fresh, so nothing may be bought from it. A saved copy of a listing the
  /// network has since said is gone never stands in; the failure is thrown
  /// instead, as if nothing were saved.
  Future<Fetched<Listing>> fetchDetail(String id) async {
    try {
      final r = await _api.read('/listings/$id');
      final listing = Listing.fromJson(((r.body as Map)['listing'] as Map).cast<String, dynamic>());
      if (r.isSaved) {
        if (!_showableSaved(listing)) {
          throw r.savedReason == SavedReason.offline
              ? ApiException(0, 'network', l10nNow.connectionError)
              : ApiException(503, 'http_503', l10nNow.errorServer);
        }
      } else if (r.isCurrent && listing.status == 'active') {
        OfflineCache.unGone(id);
      }
      return Fetched.of(r, listing);
    } on ApiException catch (e) {
      if (e.isGone) {
        OfflineCache.markGone(id);
        unawaited(OfflineCache.drop(prefixes: ['/listings/$id']));
      }
      rethrow;
    }
  }

  Future<Listing> detail(String id) async => (await fetchDetail(id)).value;

  static List<Category> _categoriesOf(Object? json) =>
      ((json is Map ? json['items'] : null) as List? ?? const [])
          .whereType<Map>()
          .map((m) => Category.fromJson(m.cast<String, dynamic>()))
          .toList();

  /// The saved categories, and the ten-minute memo seeded from them when it
  /// is empty (so [cachedCategories] answers at once on a cold start).
  Saved<List<Category>>? savedCategories() {
    final s = _api.saved('/categories');
    if (s == null) return null;
    final list = _categoriesOf(s.body);
    if (list.isEmpty) return null;
    if (_categoriesCache == null) {
      _categoriesCache = list;
      _categoriesAt = DateTime.now();
    }
    return Saved(value: list, stamp: s.stamp, validatedAt: s.validatedAt);
  }

  final Inflight<List<Category>> _categoriesInflight = Inflight<List<Category>>();

  Future<List<Category>> categories() => _categoriesInflight.run(() async {
        // Served by the API rather than read from Supabase directly, so the
        // client depends on one contract instead of also knowing the table.
        final r = await _api.read('/categories');
        final list = _categoriesOf(r.body);
        _categoriesCache = list;
        _categoriesAt = DateTime.now();
        return list;
      });

  List<Category>? _categoriesCache;
  DateTime? _categoriesAt;

  /// The categories: from memory when fetched in the last ten minutes, else
  /// from the device (refreshed in the background), else from the network.
  /// For screens that only need names and detail templates to draw a listing.
  Future<List<Category>> cachedCategories() async {
    final at = _categoriesAt;
    final cached = _categoriesCache;
    if (cached != null &&
        at != null &&
        DateTime.now().difference(at) < const Duration(minutes: 10)) {
      return cached;
    }
    final saved = savedCategories();
    if (saved != null) {
      unawaited(categories().then((_) {}, onError: (_) {}));
      return saved.value;
    }
    return categories();
  }

  Saved<List<Listing>>? savedRelated(String id, {int limit = 8}) =>
      _savedListings(_api.saved('/listings/$id/related', query: {'limit': limit}));

  /// "More like this" for the detail screen — same seller first, then category.
  Future<List<Listing>> related(String id, {int limit = 8}) async =>
      _fetchedListings(await _api.read('/listings/$id/related', query: {'limit': limit})).value;

  /// The seller's own feed — includes sold and hidden items, and carries
  /// `inquiry_count` per listing for the hub's "N chats" line.
  Future<List<Listing>> sellerListings(
    String sellerId, {
    String status = 'all',
    int limit = 50,
    int offset = 0,
  }) async {
    final json = await _api.get('/sellers/$sellerId/listings',
            query: {'status': status, 'limit': limit, 'offset': offset})
        as Map<String, dynamic>;
    return (json['items'] as List? ?? [])
        .whereType<Map>()
        .map((m) => Listing.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  Future<({List<Sale> items, int totalCents})> sales(String sellerId,
      {int limit = 50}) async {
    final json = await _api.get('/sellers/$sellerId/sales', query: {'limit': limit})
        as Map<String, dynamic>;
    return (
      items: (json['items'] as List? ?? [])
          .whereType<Map>()
          .map((m) => Sale.fromJson(m.cast<String, dynamic>()))
          .toList(),
      totalCents: (json['total_cents'] as num?)?.toInt() ?? 0,
    );
  }

  // ── Images on an existing listing ──────────────────────────────────────────

  Future<List<ListingImage>> images(String listingId) async {
    final json = await _api.get('/listings/$listingId/images') as Map<String, dynamic>;
    return (json['items'] as List? ?? [])
        .whereType<Map>()
        .map((m) => ListingImage.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  /// Appends after the current last image; the server enforces the 12 cap.
  Future<List<ListingImage>> addImages(String listingId, List<String> storagePaths) async {
    final json = await _api.post('/listings/$listingId/images', {
      'images': [for (final p in storagePaths) {'storage_path': p}],
    }) as Map<String, dynamic>;
    _noteReview(json);
    revision.value++;
    return (json['items'] as List? ?? [])
        .whereType<Map>()
        .map((m) => ListingImage.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  Future<void> removeImage(String listingId, String imageId) async {
    await _api.delete('/listings/$listingId/images/$imageId');
    revision.value++;
  }

  /// [orderedIds] must list every image on the listing exactly once.
  Future<void> reorderImages(String listingId, List<String> orderedIds) async {
    await _api.patch('/listings/$listingId/images', {'order': orderedIds});
    revision.value++;
  }

  // ── Seller reputation ──────────────────────────────────────────────────────

  Future<ReviewSummary> sellerReviews(String sellerId) async {
    final json = await _api.get('/sellers/$sellerId/reviews') as Map<String, dynamic>;
    return ReviewSummary.fromJson(json);
  }

  Future<void> reviewSeller(String sellerId, {required int rating, String? comment}) =>
      _api.post('/sellers/$sellerId/reviews', {
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      });

  /// Publish. Throws [ApiException] with `isListingLimit` when the plan quota
  /// is exhausted — surface that as an upgrade prompt.
  Future<Listing> create({
    required String title,
    String? description,
    required int priceCents,
    String currency = 'XAF',
    int quantity = 1,
    required String categorySlug,
    String kind = 'product',
    String priceMode = 'fixed',
    String? condition,
    bool hasGuarantee = false,
    String? city,
    double? lat,
    double? lng,
    List<String> imagePaths = const [],
    // Always sent by this build, even empty: that is what tells the server to
    // check the category's required details.
    Map<String, dynamic> attributes = const {},
  }) async {
    final json =
        await _api.post('/listings', {
              'attributes': attributes,
              'title': title,
              if (description != null && description.isNotEmpty)
                'description': description,
              'price_cents': priceCents,
              'currency': currency,
              'quantity': quantity,
              'category_slug': categorySlug,
              'kind': kind,
              'price_mode': priceMode,
              if (condition != null) 'condition': condition,
              'has_guarantee': hasGuarantee,
              if (city != null && city.isNotEmpty) 'city': city,
              if (lat != null && lng != null) 'location': [lng, lat],
              if (imagePaths.isNotEmpty)
                'images': [
                  for (var i = 0; i < imagePaths.length; i++)
                    {'storage_path': imagePaths[i], 'position': i},
                ],
            })
            as Map<String, dynamic>;
    final listing = Listing.fromJson(
      (json['listing'] as Map).cast<String, dynamic>(),
    );
    revision.value++;
    return listing;
  }

  Future<void> update(String id, Map<String, dynamic> fields) async {
    final json = await _api.patch('/listings/$id', fields);
    _noteReview(json);
    revision.value++;
  }

  /// What the server said after the latest edit of a listing Mambanda had
  /// asked the seller to fix: `state` is 'resubmitted' (live again) or
  /// 'changes_requested' (still hidden), and `remaining` holds the points
  /// still to fix, as sentences per language. Null when the edit was not of
  /// a flagged listing. Read once by the edit screen right after saving.
  Map<String, dynamic>? lastReview;

  void _noteReview(Object? json) {
    final r = json is Map ? json['review'] : null;
    if (r is Map) lastReview = r.cast<String, dynamic>();
  }

  /// Close a sale. The server verifies ownership and records it in `sales`.
  Future<void> markSold(String id, {int? soldPriceCents, String? buyerId}) async {
    await _api.patch('/listings/$id', {
      'action': 'mark_sold',
      if (soldPriceCents != null) 'sold_price_cents': soldPriceCents,
      if (buyerId != null) 'buyer_id': buyerId,
    });
    revision.value++;
  }

  Future<void> delete(String id) async {
    await _api.delete('/listings/$id');
    revision.value++;
  }

  Saved<SellerDashboard>? savedDashboard(String sellerId) {
    final s = _api.saved('/sellers/$sellerId/dashboard');
    final body = s?.body;
    if (s == null || body is! Map) return null;
    return Saved(
      value: SellerDashboard.fromJson(body.cast<String, dynamic>()),
      stamp: s.stamp,
      validatedAt: s.validatedAt,
    );
  }

  Future<Fetched<SellerDashboard>> fetchDashboard(String sellerId) async {
    final r = await _api.read('/sellers/$sellerId/dashboard');
    return Fetched.of(r, SellerDashboard.fromJson((r.body as Map).cast<String, dynamic>()));
  }

  Future<SellerDashboard> dashboard(String sellerId) async =>
      (await fetchDashboard(sellerId)).value;

  /// A saved list of listings for a first paint, minus the ones the network
  /// has since said are gone or that the saved copy shows as not live.
  Saved<List<Listing>>? _savedListings(SavedRead? s, {String key = 'items'}) {
    if (s == null) return null;
    final all = _listingsOf(s.body, key: key);
    final live = _liveOnly(all);
    return Saved(value: live, stamp: _stampMinus(s.stamp, all.length - live.length), validatedAt: s.validatedAt);
  }

  Fetched<List<Listing>> _fetchedListings(ApiRead r, {String key = 'items'}) {
    final all = _listingsOf(r.body, key: key);
    if (r.isSaved) {
      final live = _liveOnly(all);
      return Fetched.of(r, live, stamp: _stampMinus(r.stamp, all.length - live.length));
    }
    if (r.isCurrent) _noteActive(all);
    return Fetched.of(r, all);
  }

  /// Upload an image straight to Supabase Storage using a short-lived signed
  /// URL from the API, and return the storage path.
  ///
  /// [bucket] selects the destination — listing photos, avatars, or store
  /// banners/logos. The server namespaces every path under the caller's user
  /// id, so one user can never write into another's folder.
  /// Takes an [XFile] rather than a `dart:io` File, and uploads its bytes.
  /// A browser has no filesystem — `File` exists there only as a stub that
  /// throws — so bytes are the one currency both platforms share. The
  /// extension comes from [XFile.name] because on web `path` is a `blob:` URL
  /// with no extension at all.
  Future<String> uploadImage(
    XFile file, {
    String? listingId,
    String bucket = 'listing-images',
  }) async {
    // Read first: the extension is decided by what the bytes actually are, not
    // by what the file is called. Every picker here passes imageQuality, which
    // makes image_picker re-encode to JPEG while leaving the name alone — so
    // trusting the name filed camera photos as `photo.png` and served them as
    // image/png, which is simply a lie about the content.
    final bytes = await file.readAsBytes();
    final ext = _sniffExtension(bytes) ?? _extensionOf(file);

    final signed = await _api.post('/uploads/sign', {
      'bucket': bucket,
      'ext': ['jpg', 'jpeg', 'png', 'webp', 'gif', 'heic'].contains(ext)
          ? ext
          : 'jpg',
      if (listingId != null) 'listing_id': listingId,
    }) as Map<String, dynamic>;

    final path = signed['path'].toString();
    await Supabase.instance.client.storage
        .from(bucket)
        .uploadBinaryToSignedUrl(path, signed['token'].toString(), bytes);
    return path;
  }

  /// The image format the bytes really are, or null if it is not one we know.
  ///
  /// Magic numbers, because the storage object's Content-Type is derived from
  /// the extension and a wrong one follows the picture everywhere it is served.
  static String? _sniffExtension(Uint8List b) {
    bool at(int i, List<int> sig) {
      if (b.length < i + sig.length) return false;
      for (var k = 0; k < sig.length; k++) {
        if (b[i + k] != sig[k]) return false;
      }
      return true;
    }

    if (at(0, [0xFF, 0xD8, 0xFF])) return 'jpg';
    if (at(0, [0x89, 0x50, 0x4E, 0x47])) return 'png';
    if (at(0, [0x47, 0x49, 0x46])) return 'gif';
    // WEBP and HEIC both sit inside a container, identified a few bytes in.
    if (at(0, [0x52, 0x49, 0x46, 0x46]) && at(8, [0x57, 0x45, 0x42, 0x50])) return 'webp';
    if (at(4, [0x66, 0x74, 0x79, 0x70])) return 'heic';
    return null;
  }

  /// Lower-cased extension of a picked file, without the dot.
  ///
  /// Reads the name rather than the path: on web the path is a blob URL, and
  /// on both platforms the name is what the user actually chose. Only a
  /// fallback now — the bytes are the better authority.
  static String _extensionOf(XFile file) {
    final name = file.name.isNotEmpty ? file.name : file.path;
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  /// Upload a chat attachment — a photo *or* a document — and return its
  /// storage path, ready to hand to `ChatRepository.send(attachmentPath:)`.
  ///
  /// Unlike [uploadImage] this keeps the original file name, which the API
  /// stores as the last path segment so the recipient sees "contrat.pdf".
  /// [filename] is what the recipient will see. Pass the picker's original name:
  /// a document is staged in the cache under a uniquified name
  /// (`chat-doc-<millis>-facture.pdf`), so deriving it from the path would show
  /// that machine prefix instead of the file the sender actually chose.
  Future<String> uploadChatFile(XFile file, {String? filename}) async {
    final bytes = await file.readAsBytes();
    var name = (filename == null || filename.trim().isEmpty)
        ? (file.name.isNotEmpty ? file.name : file.path.split('/').last)
        : filename.trim();
    var dot = name.lastIndexOf('.');
    var ext = dot < 0 ? 'jpg' : name.substring(dot + 1).toLowerCase();

    // Same correction as uploadImage, for the same reason: the picker
    // re-encodes to JPEG when imageQuality is set but leaves the name alone, so
    // a gallery photo arrived as `scaled_242.png` and was then served as
    // image/png. Only applied when the bytes are a recognisable image — a PDF
    // matches nothing here, so a document keeps exactly the name the sender
    // chose, which is the whole point of carrying the name through.
    final sniffed = _sniffExtension(bytes);
    if (sniffed != null && sniffed != ext && !(sniffed == 'jpg' && ext == 'jpeg')) {
      name = '${dot < 0 ? name : name.substring(0, dot)}.$sniffed';
      ext = sniffed;
    }

    final signed = await _api.post('/uploads/sign', {
      'bucket': 'chat-attachments',
      'ext': ext,
      'filename': name,
    }) as Map<String, dynamic>;

    final path = signed['path'].toString();
    await Supabase.instance.client.storage
        .from('chat-attachments')
        .uploadBinaryToSignedUrl(path, signed['token'].toString(), bytes);
    return path;
  }
}

/// Saved items. Keeps a local set of ids so cards can render instantly while
/// the server stays the source of truth.
///
/// Restored from the device at launch; [refresh] revalidates (usually a 304)
/// and only reassigns the lists when the answer changed.
class FavoritesRepository {
  FavoritesRepository._();
  static final FavoritesRepository instance = FavoritesRepository._();

  final _api = ApiClient.instance;

  final ValueNotifier<List<Listing>> favorites = ValueNotifier([]);
  final ValueNotifier<Set<String>> favoriteIds = ValueNotifier({});

  /// Why the list on screen came from the device, or null when it came from
  /// the server.
  final ValueNotifier<SavedReason?> savedReason = ValueNotifier(null);

  bool _loadedOnce = false;
  String? _stamp;
  final Inflight<void> _inflight = Inflight<void>();

  /// True once a list (saved or fresh) has been shown: an empty list then
  /// means "none", not "not loaded".
  bool get loadedOnce => _loadedOnce;

  /// Parses a /favorites body. A row whose listing is gone (deleted, or no
  /// longer visible) marks it gone when the body came from the network; a
  /// saved body also leaves out what is gone or not live.
  (List<Listing>, int) _parse(Object? json, {required bool saved}) {
    final items = <Listing>[];
    var removed = 0;
    for (final row in ((json is Map ? json['items'] : null) as List? ?? const []).whereType<Map>()) {
      final m = row['listing'];
      if (m is! Map) {
        final id = row['listing_id']?.toString();
        if (!saved && id != null && id.isNotEmpty) {
          OfflineCache.markGone(id);
          unawaited(OfflineCache.drop(prefixes: ['/listings/$id']));
        }
        continue;
      }
      final listing = Listing.fromJson(m.cast<String, dynamic>());
      if (saved && (OfflineCache.isGone(listing.id) || listing.status != 'active')) {
        removed++;
        continue;
      }
      if (!saved && listing.status == 'active') OfflineCache.unGone(listing.id);
      items.add(listing);
    }
    return (items, removed);
  }

  void _assign(List<Listing> items, String stamp) {
    favorites.value = items;
    favoriteIds.value = items.map((l) => l.id).toSet();
    _stamp = stamp;
    _loadedOnce = true;
  }

  /// The list from the device, at launch.
  void restore() {
    final s = _api.saved('/favorites');
    if (s == null) return;
    final (items, removed) = _parse(s.body, saved: true);
    _assign(items, _stampMinus(s.stamp, removed));
  }

  /// Another account: nothing of this one's stays.
  void reset() {
    favorites.value = [];
    favoriteIds.value = {};
    savedReason.value = null;
    _loadedOnce = false;
    _stamp = null;
    _inflight.reset();
  }

  Future<void> refresh() {
    if (AuthService.instance.session == null) {
      favorites.value = [];
      favoriteIds.value = {};
      return Future.value();
    }
    return _inflight.run(_refresh);
  }

  Future<void> _refresh() async {
    final r = await _api.read('/favorites');
    if (!r.isCurrent) return;
    savedReason.value = r.savedReason;
    final (items, removed) = _parse(r.body, saved: r.isSaved);
    final stamp = _stampMinus(r.stamp, removed);
    if (_loadedOnce && stamp == _stamp) return;
    _assign(items, stamp);
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

/// Business storefronts.
class StoresRepository {
  StoresRepository._();
  static final StoresRepository instance = StoresRepository._();

  final _api = ApiClient.instance;

  /// The caller's own store, or null when they haven't opened one.
  ///
  /// The API deliberately returns null rather than 404 so onboarding can tell
  /// "no store yet" apart from a failure.
  Future<Store?> mine() async {
    final json = await _api.get('/stores/mine') as Map<String, dynamic>;
    final s = (json['store'] as Map?)?.cast<String, dynamic>();
    return s == null ? null : Store.fromJson(s);
  }

  Future<Store> create({
    required String shopName,
    String? description,
    String? bannerUrl,
    String? logoUrl,
    String? supportPhone,
  }) async {
    final json = await _api.post('/stores', {
      'shop_name': shopName,
      if (description != null && description.isNotEmpty) 'description': description,
      if (bannerUrl != null) 'banner_url': bannerUrl,
      if (logoUrl != null) 'logo_url': logoUrl,
      if (supportPhone != null && supportPhone.isNotEmpty) 'support_phone': supportPhone,
    }) as Map<String, dynamic>;
    return Store.fromJson((json['store'] as Map).cast<String, dynamic>());
  }

  Future<Store> update(String id, Map<String, dynamic> fields) async {
    final json = await _api.patch('/stores/$id', fields) as Map<String, dynamic>;
    return Store.fromJson((json['store'] as Map).cast<String, dynamic>());
  }

  /// Public storefront: the store plus its active listings.
  Future<({Store store, List<Listing> listings})> publicStore(String id) async {
    final r = await _api.read('/stores/$id');
    final json = r.body as Map<String, dynamic>;
    final listings = _listingsOf(json, key: 'listings');
    return (
      store: Store.fromJson((json['store'] as Map).cast<String, dynamic>()),
      // From the device (offline), a storefront leaves out what has since gone.
      listings: r.isSaved ? _liveOnly(listings) : listings,
    );
  }

  Future<List<Review>> reviews(String storeId) async {
    final json = await _api.get('/stores/$storeId/reviews') as Map<String, dynamic>;
    return (json['reviews'] as List? ?? [])
        .whereType<Map>()
        .map((m) => Review.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  Future<void> review(String storeId, {required int rating, String? comment}) =>
      _api.post('/stores/$storeId/reviews', {
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      });
}

/// Somebody else's public profile.
///
/// One call covers every kind of account, because the app does not know which
/// it is looking at before it asks — you tap a name in a conversation, not a
/// role. A buyer comes back with an empty shop and no store; a company comes
/// back with its storefront, its logo and its support line.
class UsersRepository {
  UsersRepository._();
  static final UsersRepository instance = UsersRepository._();

  final _api = ApiClient.instance;

  Future<PublicProfile> profile(String userId) async {
    final r = await _api.read('/users/$userId');
    final json = r.body as Map<String, dynamic>;
    final store = (json['store'] as Map?)?.cast<String, dynamic>();
    final rating = (json['rating'] as Map?)?.cast<String, dynamic>();
    final listings = _listingsOf(json, key: 'listings');
    if (!r.isSaved && r.isCurrent) _noteActive(listings);
    return PublicProfile(
      profile: Profile.fromJson((json['profile'] as Map).cast<String, dynamic>()),
      store: store == null ? null : Store.fromJson(store),
      // From the device (offline), a shop leaves out what has since gone.
      listings: r.isSaved ? _liveOnly(listings) : listings,
      ratingAverage: (rating?['average'] as num?)?.toDouble() ?? 0,
      ratingCount: (rating?['count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// What a thread's sync came back with.
class ThreadSync {
  const ThreadSync({required this.messages, this.changed = false, this.added = 0, this.newestIsMine = false});

  /// Oldest first, server rows only.
  final List<Message> messages;

  /// Something on screen would look different: repaint.
  final bool changed;

  /// New server rows since the last sync.
  final int added;
  final bool newestIsMine;
}

class _SyncJob {
  bool rerun = false;
  Completer<ThreadSync>? waiter;
}

/// Chat threads and message history.
///
/// The inbox is restored from the device at launch and revalidated (a 304
/// when nothing changed). Each conversation's messages live in [ChatStore]:
/// a room paints them at once and [syncThread] asks only for what is newer
/// than the newest stored one, falling back to a full page when the counts
/// say something further back changed.
class ChatRepository {
  ChatRepository._();
  static final ChatRepository instance = ChatRepository._();

  final _api = ApiClient.instance;

  /// Inbox threads plus the badge total, kept here so the shell can watch it.
  final ValueNotifier<List<Conversation>> threads = ValueNotifier([]);
  final ValueNotifier<int> totalUnread = ValueNotifier(0);

  /// Bumped every time the server says one of the caller's threads changed.
  /// Kept for screens that only need "something changed" (shipments); rooms
  /// listen to [changedThreads] instead.
  final ValueNotifier<int> pulse = ValueNotifier(0);

  /// Why the inbox on screen came from the device, or null.
  final ValueNotifier<SavedReason?> savedReason = ValueNotifier(null);

  /// Both realtime channels are subscribed. While true, the polls back off.
  final ValueNotifier<bool> liveHealthy = ValueNotifier(false);

  bool _loadedOnce = false;
  bool get loadedOnce => _loadedOnce;

  DateTime? _lastInboxRefreshAt;

  /// The last time the inbox was answered by the server (200 or 304).
  DateTime? get lastInboxRefreshAt => _lastInboxRefreshAt;

  final StreamController<String> _changed = StreamController<String>.broadcast();

  /// Ids of conversations that changed: from an inbox refresh that moved
  /// them, and from realtime events (which also fire for changes that leave
  /// the inbox body as it was, such as a moderation decision).
  Stream<String> get changedThreads => _changed.stream;

  String? _stamp;
  Map<String, String> _rawSig = {};
  final Set<String> _liveIds = {};
  final Map<String, RealtimeSubscribeStatus> _status = {};
  final Map<String, _SyncJob> _syncs = {};
  final Inflight<List<Conversation>> _inflight = Inflight<List<Conversation>>();

  RealtimeChannel? _liveBuyer;
  RealtimeChannel? _liveSeller;
  Timer? _debounce;

  /// Listen for changes to the caller's own threads.
  ///
  /// The subscription is on `conversations`, not `messages`: every new message
  /// touches its thread row through the on_new_message trigger, so one row per
  /// thread is enough to know something arrived, and no message text travels
  /// over the socket. Bodies still come back over the authenticated REST call,
  /// which is where the read rules already are.
  ///
  /// Two channels rather than one because a postgres filter matches a single
  /// column, and the caller is the buyer in some threads and the seller in
  /// others. Safe to call more than once.
  void startLive() {
    final uid = AuthService.instance.userId;
    if (uid == null || _liveBuyer != null) return;
    final client = Supabase.instance.client;
    _status.clear();
    final token = ++_liveToken;
    _liveBuyer = _watch(client, 'buyer_id', uid, token);
    _liveSeller = _watch(client, 'seller_id', uid, token);
  }

  /// Which start the channels belong to. Bumped by [startLive] and
  /// [stopLive], so a late event from a channel being removed (a `closed`
  /// arriving after an account switch already started new ones) cannot
  /// overwrite the new channels' status or trigger a refresh.
  int _liveToken = 0;

  RealtimeChannel _watch(SupabaseClient client, String column, String uid, int token) =>
      client
          .channel('conversations:$column:$uid')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'conversations',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: column,
              value: uid,
            ),
            callback: (p) {
              if (token == _liveToken) _onLiveChange(p);
            },
          )
          .subscribe((status, _) {
            if (token != _liveToken) return;
            _status[column] = status;
            liveHealthy.value = _status.length == 2 &&
                _status.values.every((s) => s == RealtimeSubscribeStatus.subscribed);
          });

  /// One message can arrive as more than one event — the thread's timestamp
  /// and its unread counter are separate column writes. Collapse them so the
  /// inbox is fetched once (a 304 when the body did not change).
  void _onLiveChange(PostgresChangePayload p) {
    final id = p.newRecord['id'] ?? p.oldRecord['id'];
    if (id != null) _liveIds.add(id.toString());
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        await refresh();
        pulse.value++;
      } catch (_) {
        // A dropped refresh is not worth interrupting anybody over: the
        // periodic sweep and the next tab switch both try again.
      }
    });
  }

  Future<void> stopLive() async {
    _liveToken++;
    _debounce?.cancel();
    _debounce = null;
    liveHealthy.value = false;
    _status.clear();
    final channels = [_liveBuyer, _liveSeller];
    _liveBuyer = null;
    _liveSeller = null;
    final client = Supabase.instance.client;
    for (final channel in channels) {
      if (channel != null) await client.removeChannel(channel);
    }
  }

  static String _sigOf(Map row) =>
      '${row['last_message_at']}|${row['buyer_unread']}|${row['seller_unread']}';

  void _assign(Map<String, dynamic> body, String stamp, {required bool fromNetwork}) {
    final rows = (body['items'] as List? ?? const []).whereType<Map>().toList();
    if (fromNetwork) {
      for (final row in rows) {
        // A listing thread whose listing no longer comes back: it is gone.
        final kind = row['kind']?.toString();
        final listingId = row['listing_id']?.toString();
        if ((kind == null || kind == 'listing') && row['listing'] == null && listingId != null && listingId.isNotEmpty) {
          OfflineCache.markGone(listingId);
        }
      }
    }
    final items = rows.map((m) => Conversation.fromJson(m.cast<String, dynamic>())).toList();
    final sig = {for (final row in rows) row['id'].toString(): _sigOf(row)};
    final moved = {for (final e in sig.entries) if (_rawSig[e.key] != e.value) e.key};
    threads.value = items;
    totalUnread.value = (body['total_unread'] as num?)?.toInt() ?? items.fold<int>(0, (s, t) => s + t.unread);
    _stamp = stamp;
    _rawSig = sig;
    _loadedOnce = true;
    _emitChanged(moved);
  }

  void _emitChanged(Set<String> ids) {
    final all = {...ids, ..._liveIds};
    _liveIds.clear();
    for (final id in all) {
      _changed.add(id);
    }
  }

  /// The inbox from the device, at launch. Not "offline": the network has
  /// simply not been asked yet.
  void restore() {
    final s = _api.saved('/conversations');
    final body = s?.body;
    if (s == null || body is! Map) return;
    final rows = (body['items'] as List? ?? const []).whereType<Map>().toList();
    threads.value = rows.map((m) => Conversation.fromJson(m.cast<String, dynamic>())).toList();
    totalUnread.value = (body['total_unread'] as num?)?.toInt() ?? 0;
    _stamp = s.stamp;
    _rawSig = {for (final row in rows) row['id'].toString(): _sigOf(row)};
    _loadedOnce = true;
  }

  /// Another account: nothing of this one's stays, in memory or on the socket.
  Future<void> reset() async {
    _debounce?.cancel();
    _debounce = null;
    _liveIds.clear();
    _rawSig = {};
    _syncs.clear();
    _stamp = null;
    _inflight.reset();
    threads.value = [];
    totalUnread.value = 0;
    savedReason.value = null;
    _loadedOnce = false;
    _lastInboxRefreshAt = null;
    await stopLive();
  }

  /// The inbox. Calls made while one is in flight share it.
  Future<List<Conversation>> refresh() {
    if (AuthService.instance.session == null) {
      threads.value = [];
      totalUnread.value = 0;
      return Future.value(const <Conversation>[]);
    }
    return _inflight.run(_refresh);
  }

  Future<List<Conversation>> _refresh() async {
    final uid = AuthService.instance.userId;
    final r = await _api.read('/conversations');
    if (!r.isCurrent) return threads.value;
    savedReason.value = r.savedReason;
    if (!r.isSaved) _lastInboxRefreshAt = DateTime.now();
    if (_loadedOnce && r.stamp == _stamp) {
      _emitChanged(const {});
      return threads.value;
    }
    final body = (r.body as Map).cast<String, dynamic>();
    _assign(body, r.stamp, fromNetwork: !r.isSaved);
    final items = threads.value;
    // A complete inbox from the server: a thread no longer in it is not kept.
    if (!r.isSaved && uid != null && items.length < 100) {
      unawaited(ChatStore.retainOnly(uid, {for (final t in items) t.id}));
    }
    return items;
  }

  /// Open (or reuse) the thread for a listing. Buyer-side action.
  Future<Conversation> start(String listingId) async {
    final json = await _api.post('/conversations', {'listing_id': listingId})
        as Map<String, dynamic>;
    return Conversation.fromJson((json['conversation'] as Map).cast<String, dynamic>());
  }

  /// The thread from the inbox already in memory, or null.
  Conversation? threadById(String id) {
    for (final t in threads.value) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<Conversation> thread(String id) async {
    final json = await _api.get('/conversations/$id') as Map<String, dynamic>;
    return Conversation.fromJson((json['conversation'] as Map).cast<String, dynamic>());
  }

  /// One page of messages, as the server sent it. [after] asks for what is
  /// newer than a raw created_at (with a few seconds of overlap); [sync] asks
  /// for the counts that tell whether anything further back changed. Never
  /// saved by ApiClient: ChatStore keeps the messages.
  Future<ChatPage> messagesPage(
    String conversationId, {
    int limit = 50,
    String? before,
    String? after,
    bool sync = false,
  }) async {
    final json = await _api.get('/conversations/$conversationId/messages', query: {
      'limit': limit,
      'before': before,
      'after': after,
      'sync': sync ? '1' : null,
    }) as Map<String, dynamic>;
    return ChatPage.fromJson(json);
  }

  /// Message history, oldest first. Pass [before] to page further back.
  Future<({List<Message> items, String? nextBefore})> messages(
    String conversationId, {
    int limit = 50,
    String? before,
  }) async {
    final page = await messagesPage(conversationId, limit: limit, before: before);
    return (items: page.items.map(Message.fromJson).toList(), nextBefore: page.nextBefore);
  }

  /// The messages stored for this thread, synchronously, for a room's first
  /// paint. Null when nothing is stored.
  List<Message>? storedMessages(String conversationId) {
    final uid = AuthService.instance.userId;
    if (uid == null) return null;
    final t = ChatStore.read(uid, conversationId);
    if (t == null) return null;
    ChatStore.noteOpened(uid, conversationId);
    return t.items.map(Message.fromJson).toList();
  }

  /// Bring the stored thread up to date and return it. A call while one is
  /// running for the same thread waits for one more run after it, so nothing
  /// that arrived in between is missed. Throws [ApiException] (and, on 404,
  /// forgets the thread); a [StateError] when the account changed meanwhile.
  Future<ThreadSync> syncThread(String conversationId) {
    final running = _syncs[conversationId];
    if (running != null) {
      running.rerun = true;
      return (running.waiter ??= Completer<ThreadSync>()).future;
    }
    final job = _SyncJob();
    _syncs[conversationId] = job;
    return _runSync(conversationId, job);
  }

  Future<ThreadSync> _runSync(String cid, _SyncJob job) async {
    try {
      return await _syncOnce(cid);
    } finally {
      if (job.rerun && identical(_syncs[cid], job)) {
        final waiter = job.waiter!;
        final next = _SyncJob();
        _syncs[cid] = next;
        _runSync(cid, next).then(waiter.complete, onError: waiter.completeError);
      } else {
        job.waiter?.completeError(StateError('session changed'));
        if (identical(_syncs[cid], job)) _syncs.remove(cid);
      }
    }
  }

  static bool _hasAttachment(Map m) => (m['attachment_path']?.toString() ?? '').isNotEmpty;

  Future<ThreadSync> _syncOnce(String cid, {bool forceFull = false}) async {
    final uid = AuthService.instance.userId;
    if (uid == null) throw StateError('signed out');
    final gen = OfflineCache.generation;
    final stored = ChatStore.read(uid, cid);
    var mode = forceFull
        ? ChatFetch.full
        : chooseFetch(stored, myUid: uid, nowMs: DateTime.now().millisecondsSinceEpoch);
    try {
      if (mode == ChatFetch.incremental) {
        var retried = false;
        while (true) {
          final cursor = (ChatStore.read(uid, cid) ?? stored)?.cursor;
          final page = await messagesPage(cid, after: cursor);
          MergeOutcome? outcome;
          final t = await ChatStore.update(uid, cid, (cur) {
            final base = cur ?? stored;
            if (base == null) return null;
            final o = mergeIncremental(base, page,
                myUid: uid, nowMs: DateTime.now().millisecondsSinceEpoch, retried: retried);
            outcome = o;
            return o.thread;
          }, generation: gen);
          if (OfflineCache.generation != gen) throw StateError('session changed');
          final o = outcome;
          if (o == null || o.needFull) {
            mode = ChatFetch.full;
            break;
          }
          if (o.retryIncremental) {
            retried = true;
            continue;
          }
          if (t == null) {
            mode = ChatFetch.full;
            break;
          }
          return ThreadSync(
            messages: t.items.map(Message.fromJson).toList(),
            changed: o.changed,
            added: o.added,
            newestIsMine: o.newestIsMine,
          );
        }
      }
      final page = await messagesPage(cid, sync: true);
      StoredThread? before;
      final t = await ChatStore.update(uid, cid, (cur) {
        before = cur;
        return applyFull(page, nowMs: DateTime.now().millisecondsSinceEpoch, previous: cur);
      }, generation: gen);
      if (t == null) throw StateError('session changed');
      final had = {for (final m in before?.items ?? const <Map<String, dynamic>>[]) m['id']?.toString()};
      final added = [for (final m in t.items) if (!had.contains(m['id']?.toString())) m];
      return ThreadSync(
        messages: t.items.map(Message.fromJson).toList(),
        // A full fetch re-signs attachment URLs: a room showing them repaints.
        changed: signature(before?.items ?? const []) != signature(t.items) || t.items.any(_hasAttachment),
        added: added.length,
        newestIsMine: added.isNotEmpty && added.last['sender_id']?.toString() == uid,
      );
    } on ApiException catch (e) {
      if (e.isGone) await _forgetThread(uid, cid);
      rethrow;
    }
  }

  /// The server says the thread is gone: off the device, out of the inbox.
  Future<void> _forgetThread(String uid, String cid) async {
    await ChatStore.remove(uid, cid);
    threads.value = [for (final t in threads.value) if (t.id != cid) t];
    totalUnread.value = threads.value.fold(0, (s, t) => s + t.unread);
    _rawSig.remove(cid);
    _stamp = null;
    unawaited(OfflineCache.patch(
      '/conversations',
      (json) => json is Map ? CacheRules.patchInbox(json.cast<String, dynamic>(), cid, remove: true) : json,
      uids: {uid},
    ));
  }

  /// A URL for an attachment that will still open: the stored one while its
  /// signature is young, else a fresh one from a full sync. Null when the
  /// message is not stored or cannot be fetched.
  Future<String?> freshAttachmentUrl(String conversationId, String messageId) async {
    final uid = AuthService.instance.userId;
    if (uid == null) return null;
    String? find(StoredThread? t) {
      for (final m in t?.items ?? const <Map<String, dynamic>>[]) {
        if (m['id']?.toString() == messageId) return m['attachment_url']?.toString();
      }
      return null;
    }

    final t = ChatStore.read(uid, conversationId);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (t != null && now - t.signedAt <= chatResignMinutes * 60 * 1000) {
      final url = find(t);
      if (url != null) return url;
    }
    try {
      await _syncOnce(conversationId, forceFull: true);
    } catch (_) {
      return null;
    }
    return find(ChatStore.read(uid, conversationId));
  }

  Future<void> _patchStored(String cid, bool Function(Map<String, dynamic>) where,
      void Function(Map<String, dynamic>) edit) async {
    final uid = AuthService.instance.userId;
    if (uid == null) return;
    try {
      await ChatStore.update(uid, cid, (cur) => cur == null ? null : patchWhere(cur, where, edit),
          generation: OfflineCache.generation);
    } catch (e) {
      debugPrint('[chat] stored patch failed: $e');
    }
  }

  static bool _isShare(Map<String, dynamic> m, String shareId) =>
      m['location_share_id']?.toString() == shareId ||
      (m['location'] is Map && (m['location'] as Map)['id']?.toString() == shareId);

  /// A share moved or stopped (from the share channel): the stored message
  /// follows, so the room's next paint from the device is not behind.
  Future<void> patchStoredShare(String conversationId, Map<String, dynamic> shareRecord) async {
    final id = shareRecord['id']?.toString();
    if (id == null || id.isEmpty) return;
    await _patchStored(conversationId, (m) => _isShare(m, id), (m) {
      final loc = m['location'] is Map ? Map<String, dynamic>.from(m['location'] as Map) : <String, dynamic>{};
      m['location'] = {...loc, ...shareRecord};
    });
  }

  /// Ask a person to look again at one of my messages that was held or not
  /// delivered. One open request per message; a second answers 409.
  Future<void> appeal(String messageId, {String? note, String? conversationId}) async {
    await _api.post('/compliance/appeals', {
      'message_id': messageId,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    if (conversationId != null) {
      await _patchStored(conversationId, (m) => m['id']?.toString() == messageId, (m) {
        final mod = m['moderation'] is Map ? Map<String, dynamic>.from(m['moderation'] as Map) : <String, dynamic>{};
        m['moderation'] = {...mod, 'appealed': true};
      });
    }
  }

  /// Keep what the server confirmed: the room paints it from the device next
  /// time, and the cursor stays where it was (see upsertLocal).
  Future<void> _storeSent(String? uid, int gen, String cid, Map<String, dynamic> raw) async {
    if (uid == null) return;
    try {
      await ChatStore.update(uid, cid,
          (cur) => upsertLocal(cur, raw, nowMs: DateTime.now().millisecondsSinceEpoch),
          generation: gen);
    } catch (e) {
      debugPrint('[chat] could not store a sent message: $e');
    }
  }

  Future<Message> send(String conversationId, {String? body, String? attachmentPath}) async {
    final uid = AuthService.instance.userId;
    final gen = OfflineCache.generation;
    final json = await _api.post('/conversations/$conversationId/messages', {
      if (body != null && body.isNotEmpty) 'body': body,
      if (attachmentPath != null) 'attachment_path': attachmentPath,
    }) as Map<String, dynamic>;
    final raw = (json['message'] as Map).cast<String, dynamic>();
    await _storeSent(uid, gen, conversationId, raw);
    return Message.fromJson(raw);
  }

  // ── Location sharing ──────────────────────────────────────────────────────

  /// Drop a pin, or start sharing live for [minutes].
  ///
  /// Returns the message so the caller can put the bubble on screen at once,
  /// exactly as sending text does.
  Future<Message> shareLocation(
    String conversationId, {
    required double lat,
    required double lng,
    double? accuracyM,
    bool live = false,
    int minutes = 60,
    String locale = 'en',
  }) async {
    final uid = AuthService.instance.userId;
    final gen = OfflineCache.generation;
    final json = await _api.post('/conversations/$conversationId/location', {
      'mode': live ? 'live' : 'pin',
      'lat': lat,
      'lng': lng,
      if (accuracyM != null) 'accuracy_m': accuracyM,
      if (live) 'minutes': minutes,
      'locale': locale,
    }) as Map<String, dynamic>;
    final raw = (json['message'] as Map).cast<String, dynamic>();
    await _storeSent(uid, gen, conversationId, raw);
    return Message.fromJson(raw);
  }

  /// The share moved. Returns null when the server says it is no longer
  /// running — expired, or stopped from somewhere else — which is the signal
  /// to stop the timer rather than an error worth showing anybody.
  Future<LocationShare?> moveShare(
    String conversationId,
    String shareId, {
    required double lat,
    required double lng,
    double? accuracyM,
  }) async {
    try {
      final json = await _api.patch(
        '/conversations/$conversationId/location/$shareId',
        {
          'lat': lat,
          'lng': lng,
          if (accuracyM != null) 'accuracy_m': accuracyM,
        },
      ) as Map<String, dynamic>;
      final share = (json['share'] as Map?)?.cast<String, dynamic>();
      if (share != null) {
        unawaited(_patchStored(conversationId, (m) => _isShare(m, shareId), (m) {
          final loc = m['location'] is Map ? Map<String, dynamic>.from(m['location'] as Map) : <String, dynamic>{};
          m['location'] = {...loc, ...share};
        }));
      }
      return LocationShare.fromJson(share);
    } catch (e) {
      debugPrint('[location] could not move share ($e)');
      return null;
    }
  }

  Future<void> stopShare(String conversationId, String shareId) async {
    await _api.post('/conversations/$conversationId/location/$shareId/stop');
    final at = DateTime.now().toUtc().toIso8601String();
    await _patchStored(conversationId, (m) => _isShare(m, shareId), (m) {
      final loc = m['location'] is Map ? Map<String, dynamic>.from(m['location'] as Map) : <String, dynamic>{};
      m['location'] = {...loc, 'stopped_at': at};
    });
  }

  /// Clears the caller's unread and stamps read_at on the other side.
  Future<void> markRead(String conversationId) async {
    await _api.post('/conversations/$conversationId/read');
    // Reflect it locally so the badge updates without a full refresh.
    threads.value = [
      // copyWith, not a rebuild. Listing every field by hand meant that
      // anything added to Conversation later was quietly dropped the moment a
      // thread was opened — which turned a shipping thread back into a listing
      // one with no listing.
      for (final t in threads.value)
        if (t.id == conversationId) t.copyWith(unread: 0) else t,
    ];
    totalUnread.value = threads.value.fold(0, (s, t) => s + t.unread);
  }
}

/// On-platform buying, settled through escrow.
///
/// Only a verified company's listing can be ordered — the API rejects anything
/// else — because escrow needs a merchant it can hold accountable. The money
/// flow is: buyer pays → platform holds → buyer confirms delivery (or the
/// auto-release window passes) → company is credited.
class OrdersRepository {
  OrdersRepository._();
  static final OrdersRepository instance = OrdersRepository._();

  final _api = ApiClient.instance;

  /// Places an order. Every line must belong to [companyId]; the server prices
  /// the order itself from the listings, so the client never sends amounts.
  Future<Order> create({
    required String companyId,
    required List<({String listingId, int quantity})> items,
    required String deliveryName,
    required String deliveryPhone,
    required String deliveryAddress,
    required String deliveryCity,
    String? note,
  }) async {
    final json = await _api.post('/orders', {
      'company_id': companyId,
      'items': [
        for (final i in items)
          {'listing_id': i.listingId, 'quantity': i.quantity}
      ],
      'delivery': {
        'name': deliveryName,
        'phone': deliveryPhone,
        'address': deliveryAddress,
        'city': deliveryCity,
      },
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    }) as Map<String, dynamic>;
    return Order.fromJson((json['order'] as Map).cast<String, dynamic>());
  }

  /// [role] picks the side of the table: `buyer` for "my purchases", `company`
  /// for the merchant's incoming orders. Pass [before] to page further back.
  Future<({List<Order> items, String? nextBefore})> list({
    String role = 'buyer',
    String? status,
    int limit = 20,
    String? before,
  }) async {
    final json = await _api.get('/orders', query: {
      'role': role,
      'status': status,
      'limit': limit,
      'before': before,
    }) as Map<String, dynamic>;
    return (
      items: (json['items'] as List? ?? [])
          .whereType<Map>()
          .map((m) => Order.fromJson(m.cast<String, dynamic>()))
          .toList(),
      nextBefore: ((json['page'] as Map?)?['next_before'])?.toString(),
    );
  }

  /// One order, with where it came from: a copy from the device (offline)
  /// is shown with its actions switched off.
  Future<Fetched<Order>> fetchDetail(String id) async {
    final r = await _api.read('/orders/$id');
    return Fetched.of(r, Order.fromJson(((r.body as Map)['order'] as Map).cast<String, dynamic>()));
  }

  Future<Order> detail(String id) async => (await fetchDetail(id)).value;

  /// Starts payment. [provider] is the payment processor (`campay`) and
  /// [method] the wallet (`mtn_momo` | `orange_money`).
  ///
  /// A non-null `redirectUrl` means the user finishes the payment in a browser;
  /// without one the processor pushes a prompt to [phone] and the order stays
  /// pending until the webhook confirms it. Either way the client must not
  /// treat "started" as "paid".
  Future<({String status, String? redirectUrl})> pay(
    String id, {
    required String provider,
    String? method,
    String? phone,
  }) async {
    final json = await _api.post('/orders/$id/pay', {
      'provider': provider,
      if (method != null) 'method': method,
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
    }) as Map<String, dynamic>;
    final payment = (json['payment'] as Map?)?.cast<String, dynamic>();
    return (
      status: payment?['status']?.toString() ?? 'pending',
      redirectUrl: json['redirect_url']?.toString(),
    );
  }

  /// Buyer confirms delivery — this is what releases the escrowed money to the
  /// company, so callers must confirm intent before calling it.
  Future<void> confirm(String id) => _api.post('/orders/$id/confirm');

  /// Buyer cancels, only while the order is still `pending_payment`.
  Future<void> cancel(String id) => _api.post('/orders/$id/cancel');

  /// Company marks the order sent/handed over.
  Future<void> fulfil(String id) => _api.post('/orders/$id/fulfil');
}

/// The company's money: available balance, escrow, ledger and payouts.
class WalletRepository {
  WalletRepository._();
  static final WalletRepository instance = WalletRepository._();

  final _api = ApiClient.instance;

  Future<WalletSummary> summary() async {
    final json = await _api.get('/wallet') as Map<String, dynamic>;
    return WalletSummary.fromJson(json);
  }

  Future<({List<WalletEntry> items, String? nextBefore})> entries({
    int limit = 30,
    String? before,
  }) async {
    final json = await _api.get('/wallet/entries',
        query: {'limit': limit, 'before': before}) as Map<String, dynamic>;
    return (
      items: (json['items'] as List? ?? [])
          .whereType<Map>()
          .map((m) => WalletEntry.fromJson(m.cast<String, dynamic>()))
          .toList(),
      nextBefore: ((json['page'] as Map?)?['next_before'])?.toString(),
    );
  }

  Future<List<Payout>> payouts({int limit = 30}) async {
    final json =
        await _api.get('/payouts', query: {'limit': limit}) as Map<String, dynamic>;
    return (json['items'] as List? ?? [])
        .whereType<Map>()
        .map((m) => Payout.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  /// Requests a withdrawal. The server re-checks the balance — the client-side
  /// cap is only there to fail fast with a clear message.
  Future<Payout> requestPayout({
    required int amountCents,
    required String method,
    required String destination,
    String? destinationName,
  }) async {
    final json = await _api.post('/payouts', {
      'amount_cents': amountCents,
      'method': method,
      'destination': destination,
      if (destinationName != null && destinationName.trim().isNotEmpty)
        'destination_name': destinationName.trim(),
    }) as Map<String, dynamic>;
    final p = (json['payout'] as Map?)?.cast<String, dynamic>() ?? json;
    return Payout.fromJson(p);
  }
}

/// User-submitted reports (an account, store, or listing). Lands in the admin
/// moderation queue. The API rejects reports from restricted accounts (they
/// can't write), which surfaces as an [ApiException].
class ReportsRepository {
  ReportsRepository._();
  static final ReportsRepository instance = ReportsRepository._();

  final _api = ApiClient.instance;

  Future<void> report({
    required String targetType, // 'user' | 'store' | 'listing' | 'message' | 'shipping_request'
    required String targetId,
    required String reason,
    String? detail,
  }) =>
      _api.post('/reports', {
        'targetType': targetType,
        'targetId': targetId,
        'reason': reason,
        if (detail != null && detail.trim().isNotEmpty) 'detail': detail.trim(),
      });
}

/// A message to the team.
///
/// Goes through the API, which attaches the caller's user_id from the bearer
/// and rate-limits per address, so the app sends only what the person typed
/// plus who they are.
class SupportRepository {
  SupportRepository._();
  static final SupportRepository instance = SupportRepository._();

  final _api = ApiClient.instance;

  Future<void> send({
    required String email,
    String? name,
    required String subject,
    required String message,
    required String locale,
  }) =>
      _api.post('/support', {
        'email': email,
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        'subject': subject.trim(),
        'message': message.trim(),
        'locale': locale,
        'source': 'app',
      });

  /// Open — or come back to — this person's support conversation.
  ///
  /// One thread per person, so a second question next month lands in the same
  /// place as the first and whoever answers can see what was already said.
  Future<Conversation?> openThread() async {
    final json = await _api.post('/support/thread', const {}) as Map<String, dynamic>;
    final conv = (json['conversation'] as Map?)?.cast<String, dynamic>();
    return conv == null ? null : Conversation.fromJson(conv);
  }
}

/// Referrals: the caller's own code and claiming someone else's.
///
/// Claiming deliberately goes through the API rather than writing the profile
/// directly. `profiles` lets a user update their own row, so a client-side
/// write would let the person being referred name any referrer they liked —
/// including themselves. The server is the only thing allowed to decide.
class ReferralsRepository {
  ReferralsRepository._();
  static final ReferralsRepository instance = ReferralsRepository._();

  final _api = ApiClient.instance;

  Future<ReferralSummary> me() async {
    final json = await _api.get('/referrals/me') as Map<String, dynamic>;
    return ReferralSummary.fromJson(json);
  }

  /// Throws [ApiException] with a specific code the caller can show verbatim:
  /// `unknown_code`, `self_referral`, `already_referred`, `empty_code`.
  Future<void> apply(String code) =>
      _api.post('/referrals/apply', {'code': code.trim().toUpperCase()});
}
