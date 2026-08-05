import 'dart:ui' show Locale;

import 'package:intl/intl.dart';

import 'config.dart';
import '../l10n/l10n.dart';

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
    this.companyId,
    this.companyEscrow = true,
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

  /// Can this be ordered and paid for inside the app? Only a verified
  /// company's listing can, because only a company can be held to escrow.
  bool get isBuyable =>
      companyId != null && companyId!.isNotEmpty && !isSold && inStock;

  String get displayPrice => formatPrice(priceCents, currency: currency);

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

  /// Label as stored in the database — historically German, inherited from the
  /// UI template the schema was seeded from.
  final String label;

  /// Per-language names, once the API has them. Null on an older server.
  final String? labelEn;
  final String? labelFr;
  final String? icon;

  const Category({
    required this.slug,
    required this.label,
    this.labelEn,
    this.labelFr,
    this.icon,
  });

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
      );
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
  });

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
