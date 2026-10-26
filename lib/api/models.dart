import 'dart:ui' show Locale;

import 'package:intl/intl.dart';

import 'config.dart';
import 'location_share.dart';
import '../l10n/l10n.dart';
import 'listing_attributes.dart';
import 'listing_guide.dart';

/// Domain models mirroring the Core API's JSON payloads.
///
/// Money crosses the wire as integer **cents** (`price_cents`) and is only
/// formatted for display — never stored or computed as a double.

/// Currencies with no minor unit (ISO 4217 exponent 0).
///
/// The CFA franc is the important one here: 145000 XAF *is* 145,000 FCFA, not
/// 1,450. Dividing by 100 the way you would for euros understates every
/// Cameroonian price by 100x.
const Set<String> _zeroDecimalCurrencies = {
  'XAF', 'XOF', 'XPF', 'JPY', 'KRW', 'VND', 'CLP', 'ISK',
  'GNF', 'RWF', 'UGX', 'DJF', 'KMF', 'PYG', 'VUV', 'BIF',
};

/// Formats a minor-unit amount for display.
///
/// [amountMinor] is whatever the API stores in `price_cents`: hundredths for
/// euro-style currencies, whole units for zero-decimal ones.
/// Converts a price a human typed into the integer the API stores.
///
/// The exact inverse of [formatPrice], and it must stay that way: multiplying
/// by 100 unconditionally is what made a 50 000 FCFA listing publish as
/// 5 000 000 FCFA, because the CFA franc has no minor unit to scale into.
int toMinorUnits(num amount, {String currency = 'XAF'}) =>
    _zeroDecimalCurrencies.contains(currency.toUpperCase())
        ? amount.round()
        : (amount * 100).round();

/// Turns a stored amount back into the number a human types into a price box.
///
/// The inverse of [toMinorUnits]. The edit screen needs this: prefilling a
/// 145 000 FCFA listing by dividing by 100 puts 1450 in the box, and saving
/// then quietly rewrites the price.
num fromMinorUnits(int amountMinor, {String currency = 'XAF'}) =>
    _zeroDecimalCurrencies.contains(currency.toUpperCase())
        ? amountMinor
        : amountMinor / 100;

String formatPrice(int amountMinor, {String currency = 'XAF'}) {
  final symbols = {'EUR': '€', 'XAF': 'FCFA', 'XOF': 'FCFA', 'USD': '\$'};
  final isZeroDecimal = _zeroDecimalCurrencies.contains(currency.toUpperCase());
  final amount = isZeroDecimal ? amountMinor.toDouble() : amountMinor / 100;
  // Whole amounts read better without decimals ("820 €" not "820,00 €").
  final pattern = amount == amount.roundToDouble() ? '#,##0' : '#,##0.00';
  final formatted = NumberFormat(pattern, 'de_DE').format(amount);
  return '$formatted ${symbols[currency.toUpperCase()] ?? currency}';
}

class Listing {
  final String id;
  final String sellerId;
  final String? storeId;

  /// Set when the listing belongs to an admin-verified company. That is the
  /// single condition that makes an item buyable in-app: everything else is a
  /// classified ad the buyer arranges over chat.
  final String? companyId;

  /// Whether this company's sales are held in escrow. An admin can switch it
  /// off per company, and when it is off the app must stop telling the buyer
  /// their payment is protected — the promise would simply be untrue.
  ///
  /// Defaults to true: only the listing *detail* embeds the company, so browse
  /// results assume the protected case rather than advertising the risky one.
  final bool companyEscrow;
  final String title;
  final String? description;
  final int priceCents;
  final String currency;
  final int quantity;
  final String categorySlug;

  /// product | service | job. Decides whether this is a physical good at all —
  /// and therefore whether quantity, condition, stock, delivery and shipping
  /// mean anything for it. See migration 0048.
  final String kind;

  /// How to read [priceCents]: fixed | from | hourly | daily | negotiable |
  /// on_request | free. The amount-less modes store 0 and are rendered from
  /// the mode, which is what lets `price_cents` stay non-nullable all the way
  /// down through orders and sales.
  final String priceMode;

  /// The category's details, as answered: {"sizes": ["M", "L"]}. Keys come
  /// from the category's template (Category.attributeSchema); empty when the
  /// category has none or the listing predates them.
  final Map<String, dynamic> attributes;
  final String? condition;
  final bool hasGuarantee;
  final String? city;
  final int viewCount;

  /// How many people have saved it. Only present on trending rows, which are
  /// the one place a count of other people's favourites is worth the join.
  final int favoriteCount;
  final DateTime? createdAt;
  final double? distanceMeters;

  /// Whether this row carries a coordinate at all.
  ///
  /// Only meaningful where the payload includes the column — the seller's own
  /// feed, which selects `*`. The browse RPC does not return `location`, so
  /// this is false on the buyer's feed and nothing there reads it. The value
  /// itself is PostGIS's own encoding and the app has no use for it; all that
  /// matters is whether a buyer could be told how far away this is.
  final bool hasLocation;
  final List<String> imagePaths;
  final bool isFavorited;

  /// Threads opened about this listing. Only the seller's own listing feed
  /// (`/sellers/:id/listings`) returns it; elsewhere it stays 0.
  final int inquiryCount;

  /// Present on the seller's own feed, where sold/hidden items are included.
  final String status;

  /// Set when Mambanda asked the seller to fix this listing
  /// ('changes_requested'), or after they did ('resubmitted'). Only ever
  /// present on the seller's own listings.
  final String? reviewState;

  /// What to fix, as the server wrote it, in each language. Sentences rather
  /// than codes, so a reason added later needs no app update.
  final List<String> reviewMessagesEn;
  final List<String> reviewMessagesFr;
  final String? reviewNote;

  /// Hidden by the team: the seller cannot switch it back on themselves.
  final bool moderationLocked;

  bool get needsChanges => reviewState == 'changes_requested';
  bool get hiddenByTeam => moderationLocked && status == 'hidden' && !needsChanges;
  List<String> reviewMessagesFor(String languageCode) =>
      languageCode == 'fr' && reviewMessagesFr.isNotEmpty ? reviewMessagesFr : reviewMessagesEn;

  // ── Who is selling ────────────────────────────────────────────────────────
  //
  // The API embeds the seller and their store on the browse feed and the
  // detail; these were being parsed away, which is why a listing could not say
  // who it belonged to. Null wherever the caller didn't ask for the embed.
  final String? sellerName;
  final String? sellerAvatarUrl;

  /// The seller's account type. `company` is the admin-provisioned, verified
  /// kind, so this is half of whether a listing may show the verified mark.
  final String? sellerRole;
  final String? storeName;
  final String? storeLogoUrl;
  final bool storeVerified;

  /// The store's review average and count, from the detail embed. Null and 0
  /// for a private seller, and wherever the embed is absent. A rating is only
  /// worth showing with a few reviews behind it — see the seller card.
  final double? storeRatingAvg;
  final int storeRatingCount;

  /// Where the seller says they are, which can differ from the listing's city.
  final String? sellerCity;

  /// When the seller joined ("Membre depuis …"). Detail only.
  final DateTime? sellerCreatedAt;

  /// How many active listings the seller has, counted by the detail route.
  /// Null when the server did not count — not the same as none.
  final int? sellerActiveListings;

  /// Has this seller actually been checked? True for an admin-provisioned
  /// company, or a storefront an admin marked verified.
  bool get sellerVerified => sellerRole == 'company' || storeVerified;

  /// What to call the seller on a listing: the shop name when there is one,
  /// because a storefront trades under its brand, not its owner's name.
  String? get sellerLabel =>
      (storeName?.isNotEmpty ?? false) ? storeName : sellerName;

  /// Logo first, for the same reason.
  String? get sellerImageUrl =>
      (storeLogoUrl?.isNotEmpty ?? false) ? storeLogoUrl : sellerAvatarUrl;

  const Listing({
    required this.id,
    required this.sellerId,
    this.storeId,
    this.companyId,
    this.companyEscrow = true,
    required this.title,
    this.description,
    required this.priceCents,
    this.currency = 'XAF',
    this.quantity = 1,
    required this.categorySlug,
    this.kind = 'product',
    this.priceMode = 'fixed',
    this.attributes = const {},
    this.condition,
    this.hasGuarantee = false,
    this.city,
    this.viewCount = 0,
    this.favoriteCount = 0,
    this.createdAt,
    this.distanceMeters,
    this.hasLocation = false,
    this.imagePaths = const [],
    this.isFavorited = false,
    this.inquiryCount = 0,
    this.status = 'active',
    this.reviewState,
    this.reviewMessagesEn = const [],
    this.reviewMessagesFr = const [],
    this.reviewNote,
    this.moderationLocked = false,
    this.sellerName,
    this.sellerAvatarUrl,
    this.sellerRole,
    this.storeName,
    this.storeLogoUrl,
    this.storeVerified = false,
    this.storeRatingAvg,
    this.storeRatingCount = 0,
    this.sellerCity,
    this.sellerCreatedAt,
    this.sellerActiveListings,
  });

  bool get isSold => status == 'sold';
  bool get inStock => quantity > 0;

  /// A physical good: the only kind with stock, a condition, delivery or
  /// shipping. Services and jobs are arranged in chat.
  bool get isProduct => kind == 'product';

  /// True when [priceCents] is a placeholder rather than an amount, so nothing
  /// should render it, filter on it or add it up.
  ///
  /// Negotiable may carry an amount since 0062 ("50.000 FCFA, open to
  /// offers"); only a negotiable listing left at 0 has none.
  bool get hasNoAmount =>
      priceMode == 'on_request' || (priceMode == 'negotiable' && priceCents <= 0);

  /// Can this be ordered and paid for inside the app? Only a verified
  /// company's listing can, because only a company can be held to escrow —
  /// and only a product, because checkout takes a quantity and a delivery
  /// address, neither of which means anything for a job.
  ///
  /// Negotiable stays out even with an amount: checkout charges the listed
  /// price, which is the one thing a negotiable seller has said is not final.
  bool get isBuyable => isProduct &&
      !hasNoAmount &&
      priceMode != 'negotiable' &&
      companyId != null &&
      companyId!.isNotEmpty &&
      !isSold &&
      inStock;

  /// The price as it should be read, which depends on [priceMode].
  ///
  /// Deliberately still a plain non-nullable String. Roughly thirty call sites
  /// render this — cards, detail, checkout, chat headers, share text — and two
  /// of them take it as a required non-nullable parameter. Changing the body
  /// rather than the signature is what let "Negotiable" reach all of them
  /// without touching any.
  String get displayPrice {
    final l10n = l10nNow;
    switch (priceMode) {
      case 'negotiable':
        return priceCents > 0
            ? l10n.priceNegotiableAmount(formatPrice(priceCents, currency: currency))
            : l10n.priceNegotiable;
      case 'on_request':
        return l10n.priceOnRequest;
      case 'free':
        return l10n.priceFree;
    }
    final amount = formatPrice(priceCents, currency: currency);
    switch (priceMode) {
      case 'from':
        return l10n.priceFrom(amount);
      case 'hourly':
        return l10n.pricePerHour(amount);
      case 'daily':
        return l10n.pricePerDay(amount);
      default:
        return amount;
    }
  }

  /// First image as a full CDN URL, or a neutral placeholder when the listing
  /// has no images yet.
  ///
  /// The placeholder's caption is drawn into the image by the service, so it
  /// is the one piece of user-facing text no source sweep can find — it read
  /// "No Image" in English on a French phone until this was localized.
  String get primaryImageUrl => imagePaths.isEmpty
      ? 'https://placehold.co/600x600/EEEEEE/999999/png'
          '?text=${Uri.encodeComponent(l10nNow.imagePlaceholder)}'
      : AppConfig.storagePublicUrl('listing-images', imagePaths.first);

  List<String> get imageUrls => imagePaths
      .map((p) => AppConfig.storagePublicUrl('listing-images', p))
      .toList();

  static String? _orElse(String? mine, String? other) =>
      (mine == null || mine.isEmpty) ? other : mine;

  /// This listing (a card from a feed) with what only [saved] (an earlier
  /// detail of the same listing, from the device) has: the description, the
  /// details, the seller and store. The card always keeps what it has of its
  /// own and what can change between the two (title, price, mode, quantity,
  /// status), and its primary image unless [saved] has the same one and more.
  Listing withDetailFrom(Listing saved) {
    final sameFirst = imagePaths.isNotEmpty &&
        saved.imagePaths.isNotEmpty &&
        imagePaths.first == saved.imagePaths.first;
    final images = imagePaths.isEmpty || (sameFirst && saved.imagePaths.length > imagePaths.length)
        ? saved.imagePaths
        : imagePaths;
    return Listing(
      id: id,
      sellerId: sellerId.isEmpty ? saved.sellerId : sellerId,
      storeId: storeId ?? saved.storeId,
      companyId: companyId,
      // Only the detail embeds the company; a card assumes escrow.
      companyEscrow: companyId != null && companyId == saved.companyId ? saved.companyEscrow : companyEscrow,
      title: title,
      description: _orElse(description, saved.description),
      priceCents: priceCents,
      currency: currency,
      quantity: quantity,
      categorySlug: categorySlug,
      kind: kind,
      priceMode: priceMode,
      attributes: attributes.isEmpty ? saved.attributes : attributes,
      condition: _orElse(condition, saved.condition),
      hasGuarantee: hasGuarantee || saved.hasGuarantee,
      city: _orElse(city, saved.city),
      viewCount: viewCount,
      favoriteCount: favoriteCount,
      createdAt: createdAt,
      distanceMeters: distanceMeters,
      hasLocation: hasLocation || saved.hasLocation,
      imagePaths: images,
      isFavorited: isFavorited,
      inquiryCount: inquiryCount,
      status: status,
      reviewState: reviewState,
      reviewMessagesEn: reviewMessagesEn,
      reviewMessagesFr: reviewMessagesFr,
      reviewNote: reviewNote,
      moderationLocked: moderationLocked,
      sellerName: _orElse(sellerName, saved.sellerName),
      sellerAvatarUrl: _orElse(sellerAvatarUrl, saved.sellerAvatarUrl),
      sellerRole: _orElse(sellerRole, saved.sellerRole),
      storeName: _orElse(storeName, saved.storeName),
      storeLogoUrl: _orElse(storeLogoUrl, saved.storeLogoUrl),
      storeVerified: storeVerified || saved.storeVerified,
      storeRatingAvg: storeRatingAvg ?? saved.storeRatingAvg,
      storeRatingCount: storeRatingCount == 0 ? saved.storeRatingCount : storeRatingCount,
      sellerCity: _orElse(sellerCity, saved.sellerCity),
      sellerCreatedAt: sellerCreatedAt ?? saved.sellerCreatedAt,
      sellerActiveListings: sellerActiveListings ?? saved.sellerActiveListings,
    );
  }

  static int _asInt(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  factory Listing.fromJson(Map<String, dynamic> json) {
    // Browse results expose `primary_image`; detail responses embed an ordered
    // `images` array. Support both so one model serves every screen.
    final images = <String>[];
    final raw = json['images'];
    if (raw is List) {
      final sorted = raw.whereType<Map>().toList()
        ..sort((a, b) => _asInt(a['position']).compareTo(_asInt(b['position'])));
      images.addAll(
        sorted.map((m) => m['storage_path']?.toString()).whereType<String>(),
      );
    } else if (json['primary_image'] != null) {
      images.add(json['primary_image'].toString());
    }

    final seller = (json['seller'] as Map?)?.cast<String, dynamic>();
    final store = (json['store'] as Map?)?.cast<String, dynamic>();
    final stats = json['seller_stats'] is Map ? json['seller_stats'] as Map : null;
    final ratingAvg = store?['rating_avg'];
    final activeListings = stats?['active_listings'];

    return Listing(
      id: json['id'].toString(),
      sellerId: json['seller_id']?.toString() ?? '',
      storeId: json['store_id']?.toString(),
      companyId: json['company_id']?.toString(),
      companyEscrow: json['company'] is Map
          ? (json['company'] as Map)['escrow_enabled'] != false
          : true,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      priceCents: _asInt(json['price_cents']),
      currency: json['currency']?.toString() ?? 'XAF',
      quantity: _asInt(json['quantity'], 1),
      categorySlug: json['category_slug']?.toString() ?? '',
      // Defaulted rather than required: both endpoints were returning rows
      // before these columns existed, and an older cached response has to go
      // on parsing as the product it was.
      kind: json['kind']?.toString() ?? 'product',
      priceMode: json['price_mode']?.toString() ?? 'fixed',
      attributes: json['attributes'] is Map
          ? (json['attributes'] as Map).cast<String, dynamic>()
          : const {},
      condition: json['condition']?.toString(),
      hasGuarantee: json['has_guarantee'] == true,
      city: json['city']?.toString(),
      viewCount: _asInt(json['view_count']),
      favoriteCount: _asInt(json['favorite_count']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      distanceMeters: (json['distance_m'] as num?)?.toDouble(),
      hasLocation: json['location'] != null,
      imagePaths: images,
      isFavorited: json['is_favorited'] == true,
      inquiryCount: _asInt(json['inquiry_count']),
      status: json['status']?.toString() ?? 'active',
      reviewState: json['review_state']?.toString(),
      reviewMessagesEn: _stringList((json['review_messages'] as Map?)?['en']),
      reviewMessagesFr: _stringList((json['review_messages'] as Map?)?['fr']),
      reviewNote: json['review_note']?.toString(),
      moderationLocked: json['moderation_locked'] == true,
      sellerName: seller?['display_name']?.toString(),
      sellerAvatarUrl: seller?['avatar_url']?.toString(),
      sellerRole: seller?['role']?.toString(),
      storeName: store?['shop_name']?.toString(),
      storeLogoUrl: store?['logo_url']?.toString(),
      storeVerified: store?['is_verified'] == true,
      // numeric columns can arrive as strings through PostgREST.
      storeRatingAvg: ratingAvg is num
          ? ratingAvg.toDouble()
          : double.tryParse(ratingAvg?.toString() ?? ''),
      storeRatingCount: _asInt(store?['rating_count']),
      sellerCity: seller?['city']?.toString(),
      sellerCreatedAt: DateTime.tryParse(seller?['created_at']?.toString() ?? ''),
      sellerActiveListings: activeListings == null ? null : _asInt(activeListings),
    );
  }
}

class Category {
  final String slug;

  /// Label as stored in the database — historically German, inherited from the
  /// UI template the schema was seeded from.
  final String label;

  /// Per-language names, once the API has them. Null on an older server.
  final String? labelEn;
  final String? labelFr;
  final String? icon;

  /// The category this one sits under, or null for a top-level group.
  ///
  /// The tree is exactly two levels deep. A listing may be filed on either a
  /// root or a leaf — the twelve original categories became roots and every
  /// listing published before the tree existed still points at one — so
  /// nothing here may assume a category is a leaf.
  final String? parentSlug;

  /// Which listing kind this category normally holds — 'service' for repairs
  /// and tutoring, 'job' for vacancies, null (meaning product) for the vast
  /// majority. Set in migration 0048 so the create form can pre-select rather
  /// than carrying a slug list in the client that goes stale whenever a
  /// category is added.
  final String? defaultKind;

  /// The details a listing here is asked for (0059). Use [attributeFieldsFor]
  /// for the full list, which adds the group's fields after the leaf's own.
  final List<AttrField> attributeSchema;

  /// This category's own `listing_guide` (0066), unparsed: a guide is resolved
  /// over the group's raw map before it is read. Use [guideFor].
  final Map<String, dynamic>? listingGuideRaw;

  const Category({
    this.defaultKind,
    this.attributeSchema = const [],
    this.listingGuideRaw,
    required this.slug,
    required this.label,
    this.labelEn,
    this.labelFr,
    this.icon,
    this.parentSlug,
  });

  bool get isRoot => parentSlug == null;

  /// Names keyed by the stable slug, as a fallback for a server that hasn't
  /// been taught the per-language columns yet.
  ///
  /// These used to be French-only, which meant an English speaker browsing the
  /// app got "Livres & Musique" no matter what language they had chosen. The
  /// slug stays the single identifier either way.
  static const Map<String, String> _fr = {
    'auto-rad': 'Auto & Moto',
    'elektronik': 'Électronique',
    'mode': 'Mode',
    'familie': 'Famille & Enfant',
    'real-estate': 'Immobilier',
    'sport': 'Sport & Loisirs',
    'jobs': 'Emplois',
    'moebel': 'Maison & Jardin',
    'haustiere': 'Animaux',
    'dienstleistungen': 'Services',
    'buecher-musik': 'Livres & Musique',
    'verschenken': 'À donner',
  };

  static const Map<String, String> _en = {
    'auto-rad': 'Cars & bikes',
    'elektronik': 'Electronics',
    'mode': 'Fashion',
    'familie': 'Family & kids',
    'real-estate': 'Property',
    'sport': 'Sport & leisure',
    'jobs': 'Jobs',
    'moebel': 'Home & garden',
    'haustiere': 'Pets',
    'dienstleistungen': 'Services',
    'buecher-musik': 'Books & music',
    'verschenken': 'Free to a good home',
  };

  /// The category's name in [locale].
  ///
  /// The server's own translation wins when it has one, then this file's
  /// fallback, then whatever the API sent — so a category added tomorrow still
  /// renders a word rather than disappearing or showing its slug.
  String displayLabel(Locale locale) {
    final french = locale.languageCode == 'fr';
    final fromApi = french ? (labelFr ?? labelEn) : (labelEn ?? labelFr);
    if (fromApi != null && fromApi.isNotEmpty) return fromApi;
    return (french ? _fr[slug] : _en[slug]) ?? label;
  }

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    slug: json['slug'].toString(),
    label: json['label']?.toString() ?? json['slug'].toString(),
    labelEn: json['label_en']?.toString(),
    labelFr: json['label_fr']?.toString(),
    icon: json['icon']?.toString(),
    parentSlug: json['parent_slug']?.toString(),
    defaultKind: json['default_kind']?.toString(),
    attributeSchema: AttrField.listFromJson(json['attribute_schema']),
    listingGuideRaw: json['listing_guide'] is Map
        ? (json['listing_guide'] as Map).cast<String, dynamic>()
        : null,
  );
}

/// [slug]'s category and the group it sits under. The group is null for a
/// root; both are null for an unknown slug.
(Category?, Category?) _leafAndRoot(List<Category> categories, String? slug) {
  if (slug == null) return (null, null);
  Category? leaf;
  for (final c in categories) {
    if (c.slug == slug) leaf = c;
  }
  if (leaf == null) return (null, null);
  Category? root;
  if (leaf.parentSlug != null) {
    for (final c in categories) {
      if (c.slug == leaf.parentSlug) root = c;
    }
  }
  return (leaf, root);
}

/// The details a listing in [slug] answers: the leaf's own first, in its
/// order, then the group's fields the leaf does not replace.
///
/// Leaf first because the leaf's fields are what the item is — a phone reads
/// Brand, Model, Storage before the group's Colour; a tutor's subjects come
/// before the shared Where. The server resolves group-then-leaf, but only to
/// validate, and order does not matter there.
List<AttrField> attributeFieldsFor(List<Category> categories, String? slug) {
  final (leaf, root) = _leafAndRoot(categories, slug);
  if (leaf == null) return const [];
  final leafKeys = {for (final f in leaf.attributeSchema) f.key};
  return [
    ...leaf.attributeSchema,
    for (final f in root?.attributeSchema ?? const <AttrField>[])
      if (!leafKeys.contains(f.key)) f,
  ];
}

/// The guide a listing in [slug] follows: the group's, overridden key by key
/// by the leaf's. [ListingGuide.empty] for an unknown slug or no guide.
ListingGuide guideFor(List<Category> categories, String? slug) {
  final (leaf, root) = _leafAndRoot(categories, slug);
  if (leaf == null) return ListingGuide.empty;
  return ListingGuide.resolve(root?.listingGuideRaw, leaf.listingGuideRaw);
}

/// One top-level category and the leaves filed under it.
///
/// Built on the client rather than asked of the API, because /categories
/// already returns the whole list in one cached response and turning it into a
/// tree is cheaper than a second round trip.
class CategoryGroup {
  final Category root;
  final List<Category> children;

  const CategoryGroup({required this.root, required this.children});

  /// Group a flat category list, preserving the server's sort order.
  ///
  /// A child whose parent is missing from the list is promoted to a root
  /// instead of being dropped. That should not happen — parent_slug is a
  /// foreign key — but a filtered or partial response should cost the user a
  /// slightly odd heading, not an item they can never file anything under.
  static List<CategoryGroup> from(List<Category> all) {
    final roots = all.where((c) => c.isRoot).toList();
    final known = {for (final c in all) c.slug};
    final orphans = all.where(
      (c) => c.parentSlug != null && !known.contains(c.parentSlug),
    );

    final byParent = <String, List<Category>>{};
    for (final c in all) {
      final parent = c.parentSlug;
      if (parent != null && known.contains(parent)) {
        byParent.putIfAbsent(parent, () => []).add(c);
      }
    }

    return [
      for (final root in [...roots, ...orphans])
        CategoryGroup(root: root, children: byParent[root.slug] ?? const []),
    ];
  }
}

class Profile {
  final String id;
  final String role;
  final String? displayName;
  final String? phone;
  final String? bio;
  final String? avatarUrl;
  final String? city;

  /// The language notifications arrive in, when chosen. Null follows the phone.
  final String? locale;

  /// Offers and news. Transactional notifications ignore this — a parcel that
  /// moved is the product, not marketing.
  final bool notifyMarketing;

  /// When the account was made, for "Membre depuis …" on the seller page.
  final DateTime? createdAt;

  const Profile({
    required this.id,
    required this.role,
    this.displayName,
    this.phone,
    this.bio,
    this.avatarUrl,
    this.city,
    this.locale,
    this.notifyMarketing = true,
    this.createdAt,
  });

  bool get isBusiness => role == 'business';
  bool get isSeller => role == 'business' || role == 'individual_seller';

  /// An admin-verified merchant. Companies are provisioned by an admin — never
  /// self-selected at sign-up — and are the only sellers whose listings can be
  /// bought (and escrowed) inside the app.
  bool get isCompany => role == 'company';

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'].toString(),
        role: json['role']?.toString() ?? 'buyer',
        displayName: json['display_name']?.toString(),
        phone: json['phone']?.toString(),
        bio: json['bio']?.toString(),
        avatarUrl: json['avatar_url']?.toString(),
        city: json['city']?.toString(),
        locale: json['locale']?.toString(),
        notifyMarketing: json['notify_marketing'] != false,
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      );
}

/// One row of the inbox — what the platform told this person, kept so a push
/// that was swiped away is not gone. `data` is the same map the push carried;
/// a tap here routes exactly like a tap in the shade.
class AppNotification {
  final String id;
  final String kind;
  final String title;
  final String body;
  final Map<String, String> data;
  final String? imageUrl;
  final DateTime? readAt;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.data,
    required this.createdAt,
    this.imageUrl,
    this.readAt,
  });

  bool get isUnread => readAt == null;

  AppNotification markRead() => AppNotification(
        id: id,
        kind: kind,
        title: title,
        body: body,
        data: data,
        createdAt: createdAt,
        imageUrl: imageUrl,
        readAt: readAt ?? DateTime.now(),
      );

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final raw = json['data'];
    final data = <String, String>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v != null) data[k.toString()] = v.toString();
      });
    }
    return AppNotification(
      id: json['id'].toString(),
      kind: json['kind']?.toString() ?? 'system',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      data: data,
      imageUrl: json['image_url']?.toString(),
      readAt: json['read_at'] == null ? null : DateTime.tryParse(json['read_at'].toString()),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

/// Everything shown on somebody else's profile, from `GET /users/:id`.
///
/// Note there is no phone here. A personal number is not public — the database
/// stopped serving `profiles.phone` to other users in 0022 — so the only number
/// on a profile is [Store.supportPhone], which a merchant publishes on purpose.
class PublicProfile {
  final Profile profile;

  /// Their storefront, or null for a buyer and for a seller who never opened
  /// one. This is what carries the logo, banner and support line.
  final Store? store;

  /// Their shop: active listings only.
  final List<Listing> listings;

  /// Computed on read by the API — `profiles` carries no rating columns.
  final double ratingAverage;
  final int ratingCount;

  const PublicProfile({
    required this.profile,
    this.store,
    this.listings = const [],
    this.ratingAverage = 0,
    this.ratingCount = 0,
  });

  /// A storefront worth showing as one: branded, rather than a bare person.
  bool get hasStorefront => store != null;
}

/// Account moderation state, as computed by `/me` (an expired suspension
/// already reads as `active` there, so the client can trust [status]).
class Moderation {
  /// 'active' | 'suspended' | 'blocked'.
  final String status;

  /// Admin-written message shown to the user on the blocker screen.
  final String? reason;

  /// When a suspension lifts (null = indefinite). Only set while suspended.
  final DateTime? suspendedUntil;

  const Moderation({this.status = 'active', this.reason, this.suspendedUntil});

  bool get isBlocked => status == 'blocked';
  bool get isSuspended => status == 'suspended';
  bool get isRestricted => isBlocked || isSuspended;

  factory Moderation.fromJson(Map<String, dynamic> json) => Moderation(
        status: json['status']?.toString() ?? 'active',
        reason: (json['reason']?.toString().isEmpty ?? true)
            ? null
            : json['reason'].toString(),
        suspendedUntil:
            DateTime.tryParse(json['suspended_until']?.toString() ?? ''),
      );
}

/// `/me` — profile plus the entitlements that gate publishing.
class Me {
  final Profile? profile;
  final Map<String, dynamic>? subscription;

  /// `null` means unlimited (Pro/VIP).
  final int? listingLimit;
  final int activeListings;

  /// Block/suspend state. Defaults to active when the field is absent.
  final Moderation moderation;

  const Me({
    this.profile,
    this.subscription,
    this.listingLimit,
    this.activeListings = 0,
    this.moderation = const Moderation(),
  });

  bool get canPublish => listingLimit == null || activeListings < listingLimit!;
  int? get remainingListings =>
      listingLimit == null ? null : (listingLimit! - activeListings);

  factory Me.fromJson(Map<String, dynamic> json) {
    final ent = (json['entitlements'] as Map?)?.cast<String, dynamic>() ?? {};
    final prof = (json['profile'] as Map?)?.cast<String, dynamic>();
    final mod = (json['moderation'] as Map?)?.cast<String, dynamic>();
    return Me(
      profile: prof == null ? null : Profile.fromJson(prof),
      subscription: (json['subscription'] as Map?)?.cast<String, dynamic>(),
      listingLimit: ent['listing_limit'] == null
          ? null
          : Listing._asInt(ent['listing_limit']),
      activeListings: Listing._asInt(ent['active_listings']),
      moderation: mod == null ? const Moderation() : Moderation.fromJson(mod),
    );
  }
}

class SellerDashboard {
  final int activeListings;
  final int soldListings;
  final int totalViews;
  final int inquiries;
  final int earningsCents;

  const SellerDashboard({
    this.activeListings = 0,
    this.soldListings = 0,
    this.totalViews = 0,
    this.inquiries = 0,
    this.earningsCents = 0,
  });

  String get displayEarnings => formatPrice(earningsCents);

  factory SellerDashboard.fromJson(Map<String, dynamic> json) =>
      SellerDashboard(
        activeListings: Listing._asInt(json['active_listings']),
        soldListings: Listing._asInt(json['sold_listings']),
        totalViews: Listing._asInt(json['total_views']),
        inquiries: Listing._asInt(json['inquiries']),
        earningsCents: Listing._asInt(json['earnings_cents']),
      );
}

/// A business storefront (`store_profiles`).
class Store {
  final String id;
  final String ownerId;
  final String shopName;
  final String? description;
  final String? bannerUrl;
  final String? logoUrl;
  final String? supportPhone;
  final bool isVerified;
  final double ratingAvg;
  final int ratingCount;

  const Store({
    required this.id,
    required this.ownerId,
    required this.shopName,
    this.description,
    this.bannerUrl,
    this.logoUrl,
    this.supportPhone,
    this.isVerified = false,
    this.ratingAvg = 0,
    this.ratingCount = 0,
  });

  factory Store.fromJson(Map<String, dynamic> json) => Store(
        id: json['id'].toString(),
        ownerId: json['owner_id']?.toString() ?? '',
        shopName: json['shop_name']?.toString() ?? '',
        description: json['description']?.toString(),
        bannerUrl: json['banner_url']?.toString(),
        logoUrl: json['logo_url']?.toString(),
        supportPhone: json['support_phone']?.toString(),
        isVerified: json['is_verified'] == true,
        ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0,
        ratingCount: Listing._asInt(json['rating_count']),
      );
}

/// One image attached to a listing.
class ListingImage {
  final String id;
  final String storagePath;
  final int position;

  const ListingImage({required this.id, required this.storagePath, this.position = 0});

  String get url => AppConfig.storagePublicUrl('listing-images', storagePath);

  factory ListingImage.fromJson(Map<String, dynamic> json) => ListingImage(
        id: json['id'].toString(),
        storagePath: json['storage_path']?.toString() ?? '',
        position: Listing._asInt(json['position']),
      );
}

/// A chat thread — one per (listing, buyer).
///
/// The API shapes this from the caller's side, so `counterparty` and `unread`
/// already mean "the other person" and "my unread" without the client having to
/// work out which side it is on.
/// What a thread is about.
///
/// A conversation used to be one thing: a buyer and a seller talking about a
/// listing. It can now also be somebody talking to the shipping desk about
/// something they asked us to ship. Anything a later server invents parses as
/// [listing], which is what an older build already assumed.
enum ConversationKind { listing, shipping, support }

/// The shipping request a thread is about, in the three fields a row needs.
///
/// Deliberately not the whole request: the inbox draws a title and a status,
/// and sending the rest on every /conversations response is payload nobody
/// reads.
class ShippingThread {
  const ShippingThread({required this.id, this.title, this.status = 'new'});

  final String id;
  final String? title;
  final String status;

  static ShippingThread? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = json['id']?.toString();
    if (id == null || id.isEmpty) return null;
    final title = json['item_title']?.toString();
    return ShippingThread(
      id: id,
      title: (title == null || title.isEmpty) ? null : title,
      status: json['status']?.toString() ?? 'new',
    );
  }
}

class Conversation {
  final String id;
  final String listingId;
  final String buyerId;
  final String sellerId;
  final String role; // buyer | seller
  final int unread;
  final DateTime? lastMessageAt;
  final Profile? counterparty;
  final Listing? listing;

  /// What the thread is about. Defaults to [ConversationKind.listing], so a
  /// response from a server that does not send it reads exactly as before.
  final ConversationKind kind;

  /// Set only on a shipping thread.
  final ShippingThread? shipping;

  /// What the thread is about in one string, as the server resolved it — the
  /// listing's title, or the shipping request's. Present so the row has
  /// something true to show even before this build knew about shipping.
  final String? subjectTitle;

  const Conversation({
    required this.id,
    required this.listingId,
    required this.buyerId,
    required this.sellerId,
    required this.role,
    this.unread = 0,
    this.lastMessageAt,
    this.counterparty,
    this.listing,
    this.kind = ConversationKind.listing,
    this.shipping,
    this.subjectTitle,
  });

  bool get isShipping => kind == ConversationKind.shipping;
  bool get isSupport => kind == ConversationKind.support;

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final cp = (json['counterparty'] as Map?)?.cast<String, dynamic>();
    final l = (json['listing'] as Map?)?.cast<String, dynamic>();
    final sh = (json['shipping'] as Map?)?.cast<String, dynamic>();
    final subject = json['subject_title']?.toString();
    return Conversation(
      id: json['id'].toString(),
      listingId: json['listing_id']?.toString() ?? '',
      buyerId: json['buyer_id']?.toString() ?? '',
      sellerId: json['seller_id']?.toString() ?? '',
      role: json['role']?.toString() ?? 'buyer',
      unread: Listing._asInt(json['unread']),
      lastMessageAt: DateTime.tryParse(json['last_message_at']?.toString() ?? ''),
      counterparty: cp == null ? null : Profile.fromJson(cp),
      listing: l == null ? null : Listing.fromJson(l),
      kind: switch (json['kind']) {
        'shipping' => ConversationKind.shipping,
        'support' => ConversationKind.support,
        // Anything a later server invents reads as a listing thread, which is
        // what every build before this one already assumed.
        _ => ConversationKind.listing,
      },
      shipping: ShippingThread.fromJson(sh),
      subjectTitle: (subject == null || subject.isEmpty) ? null : subject,
    );
  }

  /// A copy with some fields replaced.
  ///
  /// Exists because the alternative — rebuilding the object field by field —
  /// silently drops whatever was added since that code was written, and
  /// marking a thread read did exactly that.
  Conversation copyWith({
    int? unread,
    DateTime? lastMessageAt,
    Profile? counterparty,
    Listing? listing,
    ShippingThread? shipping,
  }) =>
      Conversation(
        id: id,
        listingId: listingId,
        buyerId: buyerId,
        sellerId: sellerId,
        role: role,
        unread: unread ?? this.unread,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        counterparty: counterparty ?? this.counterparty,
        listing: listing ?? this.listing,
        kind: kind,
        shipping: shipping ?? this.shipping,
        subjectTitle: subjectTitle,
      );
}

/// Delivery state of a chat message.
///
/// Rows that came from the server are always [sent]. [pending] and [failed]
/// exist only for messages this device just composed, so the bubble can appear
/// the instant Send is tapped instead of after the round-trip.
enum MessageSendState { sent, pending, failed }

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String? body;
  final String? attachmentPath;

  /// Temporary download URL minted by the API. `chat-attachments` is a private
  /// bucket, so there is no public URL to build — the server signs it for
  /// whichever participant asked.
  final String? attachmentUrl;
  final DateTime? createdAt;
  final DateTime? readAt;
  final MessageSendState sendState;

  /// Set when this message is somebody sharing where they are.
  final LocationShare? location;

  /// 'visible', or — only ever on the sender's own messages — 'held' (waiting
  /// for a person to review it) or 'rejected' (not delivered).
  final String moderationStatus;
  final String? moderationReasonEn;
  final String? moderationReasonFr;
  final String? moderationCaseId;
  final bool moderationAppealed;

  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.body,
    this.attachmentPath,
    this.attachmentUrl,
    this.createdAt,
    this.readAt,
    this.sendState = MessageSendState.sent,
    this.location,
    this.moderationStatus = 'visible',
    this.moderationReasonEn,
    this.moderationReasonFr,
    this.moderationCaseId,
    this.moderationAppealed = false,
  });

  bool get isHeld => moderationStatus == 'held';
  bool get isRejected => moderationStatus == 'rejected';
  String? moderationReasonFor(String languageCode) =>
      languageCode == 'fr' ? (moderationReasonFr ?? moderationReasonEn) : (moderationReasonEn ?? moderationReasonFr);

  bool get isRead => readAt != null;
  bool get isPending => sendState == MessageSendState.pending;
  bool get hasFailed => sendState == MessageSendState.failed;
  bool get hasAttachment => attachmentPath != null || attachmentUrl != null;

  static const _imageExt = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'heic'};

  /// The sender's original file name — stored as the last segment of the
  /// attachment path (`<uid>/<uuid>/contrat.pdf`).
  String? get attachmentName {
    final p = attachmentPath;
    if (p == null || p.isEmpty) return null;
    final name = p.split('/').last;
    return name.isEmpty ? null : name;
  }

  /// Images render inline; everything else gets a document chip.
  bool get attachmentIsImage {
    final name = attachmentName;
    if (name == null) return attachmentPath != null;
    final dot = name.lastIndexOf('.');
    if (dot < 0) return false;
    return _imageExt.contains(name.substring(dot + 1).toLowerCase());
  }

  Message copyWith({
    String? id,
    String? attachmentUrl,
    DateTime? createdAt,
    DateTime? readAt,
    MessageSendState? sendState,
    LocationShare? location,
    bool? moderationAppealed,
  }) =>
      Message(
        id: id ?? this.id,
        conversationId: conversationId,
        senderId: senderId,
        body: body,
        attachmentPath: attachmentPath,
        attachmentUrl: attachmentUrl ?? this.attachmentUrl,
        createdAt: createdAt ?? this.createdAt,
        readAt: readAt ?? this.readAt,
        sendState: sendState ?? this.sendState,
        location: location ?? this.location,
        moderationStatus: moderationStatus,
        moderationReasonEn: moderationReasonEn,
        moderationReasonFr: moderationReasonFr,
        moderationCaseId: moderationCaseId,
        moderationAppealed: moderationAppealed ?? this.moderationAppealed,
      );

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'].toString(),
        conversationId: json['conversation_id']?.toString() ?? '',
        senderId: json['sender_id']?.toString() ?? '',
        body: json['body']?.toString(),
        attachmentPath: json['attachment_path']?.toString(),
        attachmentUrl: json['attachment_url']?.toString(),
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
        readAt: DateTime.tryParse(json['read_at']?.toString() ?? ''),
        location: LocationShare.fromJson(
          (json['location'] as Map?)?.cast<String, dynamic>(),
        ),
        moderationStatus: json['moderation_status']?.toString() ??
            ((json['moderation'] as Map?)?['status'])?.toString() ??
            'visible',
        moderationReasonEn: (((json['moderation'] as Map?)?['reason']) as Map?)?['en']?.toString(),
        moderationReasonFr: (((json['moderation'] as Map?)?['reason']) as Map?)?['fr']?.toString(),
        moderationCaseId: ((json['moderation'] as Map?)?['case_id'])?.toString(),
        moderationAppealed: (json['moderation'] as Map?)?['appealed'] == true,
      );
}

class Review {
  final String id;
  final int rating;
  final String? comment;
  final DateTime? createdAt;
  final Profile? author;

  const Review({
    required this.id,
    required this.rating,
    this.comment,
    this.createdAt,
    this.author,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    final a = (json['author'] as Map?)?.cast<String, dynamic>();
    return Review(
      id: json['id'].toString(),
      rating: Listing._asInt(json['rating']),
      comment: json['comment']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      author: a == null ? null : Profile.fromJson(a),
    );
  }
}

/// Aggregate returned alongside a seller's reviews.
class ReviewSummary {
  final List<Review> reviews;
  final double ratingAvg;
  final int ratingCount;

  const ReviewSummary({this.reviews = const [], this.ratingAvg = 0, this.ratingCount = 0});

  factory ReviewSummary.fromJson(Map<String, dynamic> json) => ReviewSummary(
        reviews: (json['reviews'] as List? ?? [])
            .whereType<Map>()
            .map((m) => Review.fromJson(m.cast<String, dynamic>()))
            .toList(),
        ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0,
        ratingCount: Listing._asInt(json['rating_count']),
      );
}

/// A completed sale, as shown in the seller hub's sold tab.
class Sale {
  final String id;
  final int soldPriceCents;
  final DateTime? soldAt;
  final Profile? buyer;
  final Listing? listing;

  const Sale({
    required this.id,
    required this.soldPriceCents,
    this.soldAt,
    this.buyer,
    this.listing,
  });

  String get displayPrice => formatPrice(soldPriceCents);

  factory Sale.fromJson(Map<String, dynamic> json) {
    final b = (json['buyer'] as Map?)?.cast<String, dynamic>();
    final l = (json['listing'] as Map?)?.cast<String, dynamic>();
    return Sale(
      id: json['id'].toString(),
      soldPriceCents: Listing._asInt(json['sold_price_cents']),
      soldAt: DateTime.tryParse(json['sold_at']?.toString() ?? ''),
      buyer: b == null ? null : Profile.fromJson(b),
      listing: l == null ? null : Listing.fromJson(l),
    );
  }
}

/// One line of an [Order].
///
/// The title and unit price are snapshots taken when the order was placed, so
/// editing or deleting the listing afterwards never rewrites what was bought.
class OrderItem {
  final String id;
  final String listingId;
  final String titleSnapshot;
  final int unitPriceCents;
  final int quantity;
  final int lineTotalCents;

  /// Inherited from the parent order — the API prices a whole order in one
  /// currency, so lines don't carry their own.
  final String currency;

  const OrderItem({
    this.id = '',
    required this.listingId,
    required this.titleSnapshot,
    required this.unitPriceCents,
    this.quantity = 1,
    required this.lineTotalCents,
    this.currency = 'XAF',
  });

  String get displayUnitPrice =>
      formatPrice(unitPriceCents, currency: currency);
  String get displayLineTotal =>
      formatPrice(lineTotalCents, currency: currency);

  factory OrderItem.fromJson(
    Map<String, dynamic> json, {
    String currency = 'XAF',
  }) =>
      OrderItem(
        id: json['id']?.toString() ?? '',
        listingId: json['listing_id']?.toString() ?? '',
        titleSnapshot: json['title_snapshot']?.toString() ?? '',
        unitPriceCents: Listing._asInt(json['unit_price_cents']),
        quantity: Listing._asInt(json['quantity'], 1),
        lineTotalCents: Listing._asInt(json['line_total_cents']),
        currency: json['currency']?.toString() ?? currency,
      );
}

/// An on-platform purchase from a verified company, settled through escrow.
///
/// Two states matter and they move independently: [status] tracks the order
/// itself (paid, sent, done), while [escrowStatus] tracks *the money*. The
/// platform holds the buyer's payment from `held` until the buyer confirms
/// delivery (or [autoReleaseAt] passes), at which point it becomes `released`
/// and the company can be paid out. That gap is the whole trust promise, so
/// the UI must never blur the two.
class Order {
  final String id;
  final String buyerId;
  final String companyId;

  /// pending_payment | paid | fulfilled | completed | cancelled | refunded
  final String status;

  /// none | held | released | refunded
  final String escrowStatus;
  final String currency;
  final int subtotalCents;

  /// The platform's cut, taken from the company's side — never added on top of
  /// what the buyer pays.
  final int commissionCents;
  final int totalCents;
  final String? deliveryName;
  final String? deliveryPhone;
  final String? deliveryAddress;
  final String? deliveryCity;
  final String? note;
  final DateTime? paidAt;

  /// When the held money is released without the buyer acting. Shown to the
  /// buyer so the wait never feels open-ended.
  final DateTime? autoReleaseAt;
  final DateTime? confirmedAt;
  final DateTime? createdAt;
  final List<OrderItem> items;

  /// The physical dispatch, once the shop has sent the goods out. Null until
  /// then — there is nothing on the road to report.
  final Shipment? shipment;

  const Order({
    required this.id,
    required this.buyerId,
    required this.companyId,
    this.status = 'pending_payment',
    this.escrowStatus = 'none',
    this.currency = 'XAF',
    this.subtotalCents = 0,
    this.commissionCents = 0,
    this.totalCents = 0,
    this.deliveryName,
    this.deliveryPhone,
    this.deliveryAddress,
    this.deliveryCity,
    this.note,
    this.paidAt,
    this.autoReleaseAt,
    this.confirmedAt,
    this.createdAt,
    this.items = const [],
    this.shipment,
  });

  bool get isPendingPayment => status == 'pending_payment';
  bool get isPaid => status == 'paid';
  bool get isFulfilled => status == 'fulfilled';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  bool get isEscrowHeld => escrowStatus == 'held';
  bool get isEscrowReleased => escrowStatus == 'released';
  bool get isEscrowRefunded => escrowStatus == 'refunded';

  /// The buyer releases the money by confirming delivery — only possible while
  /// it is actually being held.
  bool get canConfirm => isEscrowHeld;

  /// Cancelling is only free before any money has moved.
  bool get canCancel => isPendingPayment;

  /// The company marks an order it has already been paid for.
  bool get canFulfil => isPaid;

  String get displaySubtotal => formatPrice(subtotalCents, currency: currency);
  String get displayCommission =>
      formatPrice(commissionCents, currency: currency);
  String get displayTotal => formatPrice(totalCents, currency: currency);

  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);

  /// Short reference the buyer can quote to support, e.g. "#3F5A9C2B".
  String get reference {
    final compact = id.replaceAll('-', '').toUpperCase();
    return '#${compact.length <= 8 ? compact : compact.substring(0, 8)}';
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    final currency = json['currency']?.toString() ?? 'XAF';
    // Delivery details arrive flattened (`delivery_name`) but a nested
    // `delivery` object is accepted too, so one model serves the create
    // response and the list/detail responses alike.
    final delivery = (json['delivery'] as Map?)?.cast<String, dynamic>();
    String? field(String flat, String nested) =>
        json[flat]?.toString() ?? delivery?[nested]?.toString();

    return Order(
      id: json['id'].toString(),
      buyerId: json['buyer_id']?.toString() ?? '',
      companyId: json['company_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending_payment',
      escrowStatus: json['escrow_status']?.toString() ?? 'none',
      currency: currency,
      subtotalCents: Listing._asInt(json['subtotal_cents']),
      commissionCents: Listing._asInt(json['commission_cents']),
      totalCents: Listing._asInt(json['total_cents']),
      deliveryName: field('delivery_name', 'name'),
      deliveryPhone: field('delivery_phone', 'phone'),
      deliveryAddress: field('delivery_address', 'address'),
      deliveryCity: field('delivery_city', 'city'),
      note: json['note']?.toString(),
      paidAt: DateTime.tryParse(json['paid_at']?.toString() ?? ''),
      autoReleaseAt:
          DateTime.tryParse(json['auto_release_at']?.toString() ?? ''),
      confirmedAt: DateTime.tryParse(json['confirmed_at']?.toString() ?? ''),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      items: (json['items'] as List? ?? [])
          .whereType<Map>()
          .map((m) =>
              OrderItem.fromJson(m.cast<String, dynamic>(), currency: currency))
          .toList(),
      // `shipment`, not `delivery` — the latter key is already the address
      // above, and reusing it would make the two silently collide.
      shipment: json['shipment'] is Map
          ? Shipment.fromJson((json['shipment'] as Map).cast<String, dynamic>())
          : null,
    );
  }
}

/// An order on its way: where the parcel is, and the code the buyer reads out
/// to the driver at the door.
///
/// The code is the buyer's half of the handover proof — the driver cannot close
/// the stop without it. The API sends it to the buyer alone, and stops sending
/// it once the stop is closed, so [proofCode] is null in every other case.
class Shipment {
  final String id;

  /// pending | assigned | picked_up | in_transit | delivered | failed | returned
  final String status;
  final String? proofCode;
  final String? recipientName;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final String? failureReason;

  const Shipment({
    required this.id,
    this.status = 'pending',
    this.proofCode,
    this.recipientName,
    this.pickedUpAt,
    this.deliveredAt,
    this.failureReason,
  });

  /// Out of the shop and in a driver's hands — the point at which the buyer
  /// should have the code ready.
  bool get isOnTheRoad => status == 'picked_up' || status == 'in_transit';
  bool get isDelivered => status == 'delivered';
  bool get isFailed => status == 'failed' || status == 'returned';

  /// Only worth putting on screen while it can still be used.
  bool get hasUsableCode => (proofCode?.isNotEmpty ?? false) && !isDelivered && !isFailed;

  factory Shipment.fromJson(Map<String, dynamic> json) => Shipment(
        id: json['id'].toString(),
        status: json['status']?.toString() ?? 'pending',
        proofCode: json['proof_code']?.toString(),
        recipientName: json['recipient_name']?.toString(),
        pickedUpAt: DateTime.tryParse(json['picked_up_at']?.toString() ?? ''),
        deliveredAt: DateTime.tryParse(json['delivered_at']?.toString() ?? ''),
        failureReason: json['failure_reason']?.toString(),
      );
}

/// A company's money, split into what it can actually take out and what is
/// still sitting in escrow.
///
/// [escrowHeldCents] is *not* spendable — it belongs to buyers until they
/// confirm delivery. The two figures must always be shown apart.
class WalletSummary {
  final int balanceCents;
  final int escrowHeldCents;
  final String currency;

  const WalletSummary({
    this.balanceCents = 0,
    this.escrowHeldCents = 0,
    this.currency = 'XAF',
  });

  String get displayBalance => formatPrice(balanceCents, currency: currency);
  String get displayEscrowHeld =>
      formatPrice(escrowHeldCents, currency: currency);

  factory WalletSummary.fromJson(Map<String, dynamic> json) => WalletSummary(
        balanceCents: Listing._asInt(json['balance_cents']),
        escrowHeldCents: Listing._asInt(json['escrow_held_cents']),
        currency: json['currency']?.toString() ?? 'XAF',
      );
}

/// One line of the company's wallet ledger. Credits are positive, debits
/// (payouts, refunds, commission) negative.
class WalletEntry {
  final String id;

  /// Machine-readable movement type, e.g. `escrow_release`, `commission`,
  /// `payout`, `refund`.
  final String kind;
  final int amountCents;
  final String currency;
  final String? description;
  final String? orderId;
  final DateTime? createdAt;

  const WalletEntry({
    required this.id,
    this.kind = '',
    this.amountCents = 0,
    this.currency = 'XAF',
    this.description,
    this.orderId,
    this.createdAt,
  });

  bool get isCredit => amountCents >= 0;

  /// Signed for the ledger, so a credit reads "+12.000 FCFA".
  String get displayAmount {
    final formatted = formatPrice(amountCents, currency: currency);
    return amountCents > 0 ? '+$formatted' : formatted;
  }

  factory WalletEntry.fromJson(Map<String, dynamic> json) => WalletEntry(
        id: json['id'].toString(),
        kind: (json['kind'] ?? json['type'] ?? json['entry_type'])?.toString() ??
            '',
        amountCents: Listing._asInt(json['amount_cents']),
        currency: json['currency']?.toString() ?? 'XAF',
        description:
            (json['description'] ?? json['note'] ?? json['memo'])?.toString(),
        orderId: json['order_id']?.toString(),
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      );
}

/// A withdrawal request from the company's available balance.
class Payout {
  final String id;
  final int amountCents;
  final String currency;

  /// pending | processing | paid | failed | cancelled
  final String status;

  /// mtn_momo | orange_money | bank
  final String method;
  final String destination;
  final String? destinationName;
  final DateTime? createdAt;
  final DateTime? processedAt;

  const Payout({
    required this.id,
    this.amountCents = 0,
    this.currency = 'XAF',
    this.status = 'pending',
    this.method = '',
    this.destination = '',
    this.destinationName,
    this.createdAt,
    this.processedAt,
  });

  String get displayAmount => formatPrice(amountCents, currency: currency);

  factory Payout.fromJson(Map<String, dynamic> json) => Payout(
        id: json['id'].toString(),
        amountCents: Listing._asInt(json['amount_cents']),
        currency: json['currency']?.toString() ?? 'XAF',
        status: json['status']?.toString() ?? 'pending',
        method: json['method']?.toString() ?? '',
        destination: json['destination']?.toString() ?? '',
        destinationName: json['destination_name']?.toString(),
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
        processedAt:
            DateTime.tryParse(json['processed_at']?.toString() ?? ''),
      );
}

/// The caller's referral standing: the code they share, and how their invites
/// are doing.
///
/// `qualified` is the number that matters — those invitees completed a
/// purchase, so the referral is earned rather than merely signed up.
class ReferralSummary {
  final String? code;
  final String? referredBy;
  final int total;
  final int pending;
  final int qualified;
  final int rewarded;

  const ReferralSummary({
    this.code,
    this.referredBy,
    this.total = 0,
    this.pending = 0,
    this.qualified = 0,
    this.rewarded = 0,
  });

  /// Whether this user already claimed someone else's code. Attribution is
  /// write-once, so the entry point should not be offered twice.
  bool get hasReferrer => referredBy != null && referredBy!.isNotEmpty;

  factory ReferralSummary.fromJson(Map<String, dynamic> json) {
    final stats = (json['stats'] as Map?)?.cast<String, dynamic>() ?? const {};
    int n(String k) => (stats[k] as num?)?.toInt() ?? 0;
    return ReferralSummary(
      code: json['code']?.toString(),
      referredBy: json['referred_by']?.toString(),
      total: n('total'),
      pending: n('pending'),
      qualified: n('qualified'),
      rewarded: n('rewarded'),
    );
  }
}

List<String> _stringList(Object? v) =>
    v is List ? v.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList() : const [];
