import 'dart:async';

import 'package:cross_file/cross_file.dart';

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
    // Served by the API rather than read from Supabase directly, so the client
    // depends on one contract instead of also knowing the table shape.
    final json = await _api.get('/categories') as Map<String, dynamic>;
    return (json['items'] as List? ?? [])
        .whereType<Map>()
        .map((m) => Category.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  /// "More like this" for the detail screen — same seller first, then category.
  Future<List<Listing>> related(String id, {int limit = 8}) async {
    final json = await _api.get('/listings/$id/related', query: {'limit': limit})
        as Map<String, dynamic>;
    return (json['items'] as List? ?? [])
        .whereType<Map>()
        .map((m) => Listing.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

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
    return (json['items'] as List? ?? [])
        .whereType<Map>()
        .map((m) => ListingImage.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  Future<void> removeImage(String listingId, String imageId) =>
      _api.delete('/listings/$listingId/images/$imageId');

  /// [orderedIds] must list every image on the listing exactly once.
  Future<void> reorderImages(String listingId, List<String> orderedIds) =>
      _api.patch('/listings/$listingId/images', {'order': orderedIds});

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
    final listing =
        Listing.fromJson((json['listing'] as Map).cast<String, dynamic>());
    revision.value++;
    return listing;
  }

  Future<void> update(String id, Map<String, dynamic> fields) async {
    await _api.patch('/listings/$id', fields);
    revision.value++;
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

  Future<SellerDashboard> dashboard(String sellerId) async {
    final json =
        await _api.get('/sellers/$sellerId/dashboard') as Map<String, dynamic>;
    return SellerDashboard.fromJson(json);
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
    final json = await _api.get('/stores/$id') as Map<String, dynamic>;
    return (
      store: Store.fromJson((json['store'] as Map).cast<String, dynamic>()),
      listings: (json['listings'] as List? ?? [])
          .whereType<Map>()
          .map((m) => Listing.fromJson(m.cast<String, dynamic>()))
          .toList(),
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
    final json = await _api.get('/users/$userId') as Map<String, dynamic>;
    final store = (json['store'] as Map?)?.cast<String, dynamic>();
    final rating = (json['rating'] as Map?)?.cast<String, dynamic>();
    return PublicProfile(
      profile: Profile.fromJson((json['profile'] as Map).cast<String, dynamic>()),
      store: store == null ? null : Store.fromJson(store),
      listings: (json['listings'] as List? ?? [])
          .whereType<Map>()
          .map((m) => Listing.fromJson(m.cast<String, dynamic>()))
          .toList(),
      ratingAverage: (rating?['average'] as num?)?.toDouble() ?? 0,
      ratingCount: (rating?['count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Chat threads and message history.
///
/// Real-time delivery arrives later with the Socket.IO service; until then the
/// room screen polls. The shapes are identical either way, so swapping in live
/// push is a transport change, not a data change.
class ChatRepository {
  ChatRepository._();
  static final ChatRepository instance = ChatRepository._();

  final _api = ApiClient.instance;

  /// Inbox threads plus the badge total, kept here so the shell can watch it.
  final ValueNotifier<List<Conversation>> threads = ValueNotifier([]);
  final ValueNotifier<int> totalUnread = ValueNotifier(0);

  /// Bumped every time the server says one of the caller's threads changed.
  /// An open conversation watches this so a reply lands the moment it is sent
  /// rather than on the room's next poll.
  final ValueNotifier<int> pulse = ValueNotifier(0);

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
    _liveBuyer = _watch(client, 'buyer_id', uid);
    _liveSeller = _watch(client, 'seller_id', uid);
  }

  RealtimeChannel _watch(SupabaseClient client, String column, String uid) =>
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
            callback: (_) => _onLiveChange(),
          )
          .subscribe();

  /// One message can arrive as more than one event — the thread's timestamp
  /// and its unread counter are separate column writes. Collapse them so the
  /// inbox is fetched once.
  void _onLiveChange() {
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
    _debounce?.cancel();
    _debounce = null;
    final client = Supabase.instance.client;
    for (final channel in [_liveBuyer, _liveSeller]) {
      if (channel != null) await client.removeChannel(channel);
    }
    _liveBuyer = null;
    _liveSeller = null;
  }

  Future<List<Conversation>> refresh() async {
    if (AuthService.instance.session == null) {
      threads.value = [];
      totalUnread.value = 0;
      return [];
    }
    final json = await _api.get('/conversations') as Map<String, dynamic>;
    final items = (json['items'] as List? ?? [])
        .whereType<Map>()
        .map((m) => Conversation.fromJson(m.cast<String, dynamic>()))
        .toList();
    threads.value = items;
    totalUnread.value = (json['total_unread'] as num?)?.toInt() ?? 0;
    return items;
  }

  /// Open (or reuse) the thread for a listing. Buyer-side action.
  Future<Conversation> start(String listingId) async {
    final json = await _api.post('/conversations', {'listing_id': listingId})
        as Map<String, dynamic>;
    return Conversation.fromJson((json['conversation'] as Map).cast<String, dynamic>());
  }

  Future<Conversation> thread(String id) async {
    final json = await _api.get('/conversations/$id') as Map<String, dynamic>;
    return Conversation.fromJson((json['conversation'] as Map).cast<String, dynamic>());
  }

  /// Message history, oldest first. Pass [before] to page further back.
  Future<({List<Message> items, String? nextBefore})> messages(
    String conversationId, {
    int limit = 50,
    String? before,
  }) async {
    final json = await _api.get('/conversations/$conversationId/messages',
        query: {'limit': limit, 'before': before}) as Map<String, dynamic>;
    return (
      items: (json['items'] as List? ?? [])
          .whereType<Map>()
          .map((m) => Message.fromJson(m.cast<String, dynamic>()))
          .toList(),
      nextBefore: ((json['page'] as Map?)?['next_before'])?.toString(),
    );
  }

  Future<Message> send(String conversationId, {String? body, String? attachmentPath}) async {
    final json = await _api.post('/conversations/$conversationId/messages', {
      if (body != null && body.isNotEmpty) 'body': body,
      if (attachmentPath != null) 'attachment_path': attachmentPath,
    }) as Map<String, dynamic>;
    return Message.fromJson((json['message'] as Map).cast<String, dynamic>());
  }

  /// Clears the caller's unread and stamps read_at on the other side.
  Future<void> markRead(String conversationId) async {
    await _api.post('/conversations/$conversationId/read');
    // Reflect it locally so the badge updates without a full refresh.
    threads.value = [
      for (final t in threads.value)
        if (t.id == conversationId)
          Conversation(
            id: t.id,
            listingId: t.listingId,
            buyerId: t.buyerId,
            sellerId: t.sellerId,
            role: t.role,
            unread: 0,
            lastMessageAt: t.lastMessageAt,
            counterparty: t.counterparty,
            listing: t.listing,
          )
        else
          t,
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

  Future<Order> detail(String id) async {
    final json = await _api.get('/orders/$id') as Map<String, dynamic>;
    return Order.fromJson((json['order'] as Map).cast<String, dynamic>());
  }

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
    required String targetType, // 'user' | 'store' | 'listing'
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
