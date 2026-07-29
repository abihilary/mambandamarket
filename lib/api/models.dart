import 'package:intl/intl.dart';

import 'config.dart';

/// Domain models mirroring the Core API's JSON payloads.
///
/// Money crosses the wire as integer **cents** (`price_cents`) and is only
/// formatted for display — never stored or computed as a double.

String formatPrice(int cents, {String currency = 'EUR'}) {
  final symbols = {'EUR': '€', 'XAF': 'FCFA', 'USD': '\$'};
  final amount = cents / 100;
  // Whole amounts read better without decimals ("820 €" not "820,00 €").
  final pattern = amount == amount.roundToDouble() ? '#,##0' : '#,##0.00';
  final formatted = NumberFormat(pattern, 'de_DE').format(amount);
  return '$formatted ${symbols[currency] ?? currency}';
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

  const Listing({
    required this.id,
    required this.sellerId,
    this.storeId,
    required this.title,
    this.description,
    required this.priceCents,
    this.currency = 'EUR',
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
  });

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
      currency: json['currency']?.toString() ?? 'EUR',
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
    );
  }
}

class Category {
  final String slug;
  final String label;
  final String? icon;

  const Category({required this.slug, required this.label, this.icon});

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
