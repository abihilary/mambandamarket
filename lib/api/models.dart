import 'package:intl/intl.dart';

import 'config.dart';

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
  final String title;
  final String? description;
  final int priceCents;
  final String currency;
  final int quantity;
  final String categorySlug;
  final String? condition;
  final bool hasGuarantee;
  final String? city;
  final int viewCount;
  final DateTime? createdAt;
  final double? distanceMeters;
  final List<String> imagePaths;
  final bool isFavorited;

  /// Threads opened about this listing. Only the seller's own listing feed
  /// (`/sellers/:id/listings`) returns it; elsewhere it stays 0.
  final int inquiryCount;

  /// Present on the seller's own feed, where sold/hidden items are included.
  final String status;

  const Listing({
    required this.id,
    required this.sellerId,
    this.storeId,
    required this.title,
    this.description,
    required this.priceCents,
    this.currency = 'XAF',
    this.quantity = 1,
    required this.categorySlug,
    this.condition,
    this.hasGuarantee = false,
    this.city,
    this.viewCount = 0,
    this.createdAt,
    this.distanceMeters,
    this.imagePaths = const [],
    this.isFavorited = false,
    this.inquiryCount = 0,
    this.status = 'active',
  });

  bool get isSold => status == 'sold';
  bool get inStock => quantity > 0;

  String get displayPrice => formatPrice(priceCents, currency: currency);

  /// First image as a full CDN URL, or a neutral placeholder when the listing
  /// has no images yet.
  String get primaryImageUrl => imagePaths.isEmpty
      ? 'https://placehold.co/600x600/EEEEEE/999999/png?text=No+Image'
      : AppConfig.storagePublicUrl('listing-images', imagePaths.first);

  List<String> get imageUrls => imagePaths
      .map((p) => AppConfig.storagePublicUrl('listing-images', p))
      .toList();

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

    return Listing(
      id: json['id'].toString(),
      sellerId: json['seller_id']?.toString() ?? '',
      storeId: json['store_id']?.toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      priceCents: _asInt(json['price_cents']),
      currency: json['currency']?.toString() ?? 'XAF',
      quantity: _asInt(json['quantity'], 1),
      categorySlug: json['category_slug']?.toString() ?? '',
      condition: json['condition']?.toString(),
      hasGuarantee: json['has_guarantee'] == true,
      city: json['city']?.toString(),
      viewCount: _asInt(json['view_count']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      distanceMeters: (json['distance_m'] as num?)?.toDouble(),
      imagePaths: images,
      isFavorited: json['is_favorited'] == true,
      inquiryCount: _asInt(json['inquiry_count']),
      status: json['status']?.toString() ?? 'active',
    );
  }
}

class Category {
  final String slug;

  /// Label as stored in the database — currently German, inherited from the
  /// UI template the schema was seeded from.
  final String label;
  final String? icon;

  const Category({required this.slug, required this.label, this.icon});

  /// Display labels keyed by the stable slug.
  ///
  /// The marketplace serves francophone Cameroon, so the German labels sitting
  /// in `categories.label` are wrong for users. Translating here rather than
  /// rewriting the rows keeps the slug as the single identifier and is where
  /// the other locales (the site offers EN/FR/DE) will slot in.
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

  /// Falls back to whatever the API sent, so a category added later still
  /// renders instead of disappearing.
  String get displayLabel => _fr[slug] ?? label;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        slug: json['slug'].toString(),
        label: json['label']?.toString() ?? json['slug'].toString(),
        icon: json['icon']?.toString(),
      );
}

class Profile {
  final String id;
  final String role;
  final String? displayName;
  final String? phone;
  final String? bio;
  final String? avatarUrl;
  final String? city;

  const Profile({
    required this.id,
    required this.role,
    this.displayName,
    this.phone,
    this.bio,
    this.avatarUrl,
    this.city,
  });

  bool get isBusiness => role == 'business';
  bool get isSeller => role == 'business' || role == 'individual_seller';

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'].toString(),
        role: json['role']?.toString() ?? 'buyer',
        displayName: json['display_name']?.toString(),
        phone: json['phone']?.toString(),
        bio: json['bio']?.toString(),
        avatarUrl: json['avatar_url']?.toString(),
        city: json['city']?.toString(),
      );
}

/// `/me` — profile plus the entitlements that gate publishing.
class Me {
  final Profile? profile;
  final Map<String, dynamic>? subscription;

  /// `null` means unlimited (Pro/VIP).
  final int? listingLimit;
  final int activeListings;

  const Me({
    this.profile,
    this.subscription,
    this.listingLimit,
    this.activeListings = 0,
  });

  bool get canPublish => listingLimit == null || activeListings < listingLimit!;
  int? get remainingListings =>
      listingLimit == null ? null : (listingLimit! - activeListings);

  factory Me.fromJson(Map<String, dynamic> json) {
    final ent = (json['entitlements'] as Map?)?.cast<String, dynamic>() ?? {};
    final prof = (json['profile'] as Map?)?.cast<String, dynamic>();
    return Me(
      profile: prof == null ? null : Profile.fromJson(prof),
      subscription: (json['subscription'] as Map?)?.cast<String, dynamic>(),
      listingLimit: ent['listing_limit'] == null
          ? null
          : Listing._asInt(ent['listing_limit']),
      activeListings: Listing._asInt(ent['active_listings']),
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
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final cp = (json['counterparty'] as Map?)?.cast<String, dynamic>();
    final l = (json['listing'] as Map?)?.cast<String, dynamic>();
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
    );
  }
}

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String? body;
  final String? attachmentPath;
  final DateTime? createdAt;
  final DateTime? readAt;

  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.body,
    this.attachmentPath,
    this.createdAt,
    this.readAt,
  });

  bool get isRead => readAt != null;
  String? get attachmentUrl => attachmentPath == null
      ? null
      : AppConfig.storagePublicUrl('chat-attachments', attachmentPath!);

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'].toString(),
        conversationId: json['conversation_id']?.toString() ?? '',
        senderId: json['sender_id']?.toString() ?? '',
        body: json['body']?.toString(),
        attachmentPath: json['attachment_path']?.toString(),
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
        readAt: DateTime.tryParse(json['read_at']?.toString() ?? ''),
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
