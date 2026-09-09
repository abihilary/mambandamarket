import 'dart:ui' show Locale;

import 'board_model.dart' show pickLocalised;
import 'package:flutter/material.dart' show IconData, Icons;

import '../l10n/l10n.dart';
import 'models.dart';

/// One size somebody can pick, as the server describes it.
///
/// The label is what they choose; the hint is the physical object they picture.
/// "Medium box" alone means nothing — "medium box, about a microwave" is a
/// decision somebody can make in two seconds.
class ShippingSize {
  const ShippingSize({
    required this.code,
    required this.label,
    this.hint = const {},
    this.kgMin,
    this.kgMax,
    this.band,
  });

  final String code;
  final Map<String, String> label;
  final Map<String, String> hint;
  final double? kgMin;
  final double? kgMax;

  /// Which price band this size is in. Null means the desk quotes it.
  final String? band;

  String labelFor(Locale locale) => pickLocalised(label, locale) ?? code;
  String? hintFor(Locale locale) => pickLocalised(hint, locale);

  /// Null when there is nothing to show, so a malformed entry is one fewer
  /// option rather than a blank row in the picker.
  static ShippingSize? fromJson(String code, Map<String, dynamic> json) {
    final label = _localised(json, 'label');
    if (code.isEmpty || label.isEmpty) return null;
    return ShippingSize(
      code: code,
      label: label,
      hint: _localised(json, 'hint'),
      kgMin: (json['kg_min'] as num?)?.toDouble(),
      kgMax: (json['kg_max'] as num?)?.toDouble(),
      band: _text(json['band']),
    );
  }
}

/// Somewhere a shipment can start or end.
class ShippingPlace {
  const ShippingPlace({required this.code, required this.label, this.zone});

  final String code;
  final Map<String, String> label;

  /// Which zone it is priced as. Null means the desk quotes routes through it.
  final String? zone;

  /// Whether the catalogue can put an instant price on a route through here.
  bool get isPriced => zone != null;

  String labelFor(Locale locale) => pickLocalised(label, locale) ?? code;

  /// What gets stored on the request, and therefore what the desk reads in the
  /// queue. English rather than the customer's language, because one person
  /// dispatches every request and a route that arrives half in French and half
  /// in English is harder to scan than one that is consistently either.
  String get storedLabel => label['en'] ?? label.values.firstOrNull ?? code;

  static ShippingPlace? fromJson(Map<String, dynamic> json) {
    final code = json['code']?.toString();
    final label = _localised(json, 'label');
    if (code == null || code.isEmpty || label.isEmpty) return null;
    return ShippingPlace(code: code, label: label, zone: _text(json['zone']));
  }
}

/// A service level: how fast, in words and in days.
class ShippingTier {
  const ShippingTier({
    required this.code,
    required this.label,
    this.etaDaysMin,
    this.etaDaysMax,
  });

  final String code;
  final Map<String, String> label;
  final int? etaDaysMin;
  final int? etaDaysMax;

  String labelFor(Locale locale) => pickLocalised(label, locale) ?? code;

  static ShippingTier? fromJson(Map<String, dynamic> json) {
    final code = json['code']?.toString();
    final label = _localised(json, 'label');
    if (code == null || code.isEmpty || label.isEmpty) return null;
    return ShippingTier(
      code: code,
      label: label,
      etaDaysMin: (json['eta_days_min'] as num?)?.toInt(),
      etaDaysMax: (json['eta_days_max'] as num?)?.toInt(),
    );
  }
}

/// One way to have it delivered, priced.
class ShippingQuoteOption {
  const ShippingQuoteOption({
    required this.tier,
    required this.label,
    required this.priceCents,
    this.etaDaysMin,
    this.etaDaysMax,
  });

  final String tier;
  final Map<String, String> label;
  final int priceCents;
  final int? etaDaysMin;
  final int? etaDaysMax;

  String labelFor(Locale locale) => pickLocalised(label, locale) ?? tier;

  static ShippingQuoteOption? fromJson(Map<String, dynamic> json) {
    final tier = json['tier']?.toString();
    final price = (json['price_cents'] as num?)?.toInt();
    // An option with no price is not an option.
    if (tier == null || tier.isEmpty || price == null) return null;
    return ShippingQuoteOption(
      tier: tier,
      label: _localised(json, 'label'),
      priceCents: price,
      etaDaysMin: (json['eta_days_min'] as num?)?.toInt(),
      etaDaysMax: (json['eta_days_max'] as num?)?.toInt(),
    );
  }
}

/// What the catalogue says a route costs — or that it cannot say.
///
/// Not being able to price a route is an answer, not an error: it is the
/// form's cue to say "we'll quote you in the chat", which is how every request
/// travelled before the rate card existed.
class ShippingQuote {
  const ShippingQuote({
    required this.quotable,
    this.currency = 'XAF',
    this.options = const [],
    this.reason,
  });

  /// The answer when the form already knows not to ask: "somewhere else" on
  /// either end, or a custom size.
  static const manual = ShippingQuote(quotable: false, reason: 'local');

  final bool quotable;
  final String currency;
  final List<ShippingQuoteOption> options;
  final String? reason;

  /// The one preselected: cheapest, first on a tie.
  ShippingQuoteOption? get cheapest {
    ShippingQuoteOption? best;
    for (final o in options) {
      if (best == null || o.priceCents < best.priceCents) best = o;
    }
    return best;
  }

  static ShippingQuote fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ShippingQuote(quotable: false, reason: 'empty');
    final options = (json['options'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => ShippingQuoteOption.fromJson(m.cast<String, dynamic>()))
        .whereType<ShippingQuoteOption>()
        .toList(growable: false);
    final quotable = json['quotable'] == true && options.isNotEmpty;
    return ShippingQuote(
      quotable: quotable,
      currency: json['currency']?.toString() ?? 'XAF',
      options: quotable ? options : const [],
      reason: quotable ? null : (_text(json['reason']) ?? 'no_options'),
    );
  }
}

/// The paperwork: a booking confirmation, and a receipt once delivered.
class ShippingDocument {
  const ShippingDocument({
    required this.kind,
    required this.number,
    required this.url,
    this.createdAt,
    this.emailedTo,
  });

  /// `confirmation` or `receipt`.
  final String kind;

  /// Stable across re-issues, e.g. `MB-10023-C`. Key any cache on this; the
  /// URL is signed and rotates.
  final String number;
  final Uri url;
  final DateTime? createdAt;
  final String? emailedTo;

  bool get isReceipt => kind == 'receipt';

  static ShippingDocument? fromJson(Map<String, dynamic> json) {
    final kind = _text(json['kind']);
    final number = _text(json['number']);
    final url = Uri.tryParse(json['url']?.toString() ?? '');
    if (kind == null || number == null || url == null || !url.hasScheme) return null;
    return ShippingDocument(
      kind: kind,
      number: number,
      url: url,
      createdAt: DateTime.tryParse(json['updated_at']?.toString() ?? json['created_at']?.toString() ?? ''),
      emailedTo: _text(json['emailed_to']),
    );
  }
}

enum EtaKind { today, range, late }

/// When a shipment should land, counted from now.
class EtaWindow {
  const EtaWindow({required this.kind, required this.minDays, required this.maxDays});

  final EtaKind kind;

  /// Whole days from now. Zero means today.
  final int minDays;
  final int maxDays;

  /// Null when the request carries no ETA, or no date to count from.
  static EtaWindow? of(ShippingRequest r, {DateTime? now}) {
    final base = r.acceptedAt ?? r.createdAt;
    final min = r.etaDaysMin;
    final max = r.etaDaysMax;
    if (base == null || min == null || max == null) return null;
    final at = (now ?? DateTime.now()).toLocal();
    final earliest = base.add(Duration(days: min)).toLocal();
    final latest = base.add(Duration(days: max)).toLocal();
    // Calendar days, not 24-hour chunks: something due at ten tonight is
    // arriving today, not "in up to one day".
    final today = DateTime(at.year, at.month, at.day);
    int dayDiff(DateTime d) => DateTime(d.year, d.month, d.day).difference(today).inDays;
    if (dayDiff(latest) < 0) {
      return const EtaWindow(kind: EtaKind.late, minDays: 0, maxDays: 0);
    }
    final lo = dayDiff(earliest).clamp(0, 1 << 20);
    final hi = dayDiff(latest);
    if (hi == 0) return const EtaWindow(kind: EtaKind.today, minDays: 0, maxDays: 0);
    return EtaWindow(kind: EtaKind.range, minDays: lo, maxDays: hi);
  }
}

/// The catalogue: what we ship, and between where.
///
/// [enabled] is the kill switch. False means the app shows no entry point at
/// all, which is how the feature can be turned off without an app release.
class ShippingOptions {
  const ShippingOptions({
    this.enabled = false,
    this.sizes = const {},
    this.defaultSizes = const [],
    this.byCategory = const {},
    this.from = const [],
    this.to = const [],
    this.tiers = const [],
    this.currency = 'XAF',
  });

  final bool enabled;
  final Map<String, ShippingSize> sizes;
  final List<String> defaultSizes;
  final Map<String, List<String>> byCategory;
  final List<ShippingPlace> from;
  final List<ShippingPlace> to;

  /// The service levels on offer. Empty on a catalogue from before the rate
  /// card existed — which a cached copy may well be — and the form copes.
  final List<ShippingTier> tiers;
  final String currency;

  ShippingTier? tier(String? code) =>
      code == null ? null : tiers.where((t) => t.code == code).firstOrNull;

  bool get isUsable => sizes.isNotEmpty && from.isNotEmpty && to.isNotEmpty;

  /// The sizes offered for a category: its own list, then its parent's, then
  /// the generic ladder.
  ///
  /// Operations will key most of the catalogue on roots, because there are
  /// eighty-eight categories and six of them genuinely need their own list. The
  /// parent step is what makes that work.
  List<ShippingSize> sizesFor(String? categorySlug, {String? parentSlug}) {
    final keys = (categorySlug == null ? null : byCategory[categorySlug]) ??
        (parentSlug == null ? null : byCategory[parentSlug]) ??
        defaultSizes;
    return [
      for (final key in keys)
        if (sizes[key] != null) sizes[key]!,
    ];
  }

  /// The escape hatch. Always offered, whatever the catalogue says, because a
  /// size list that does not fit is the one case where the form must not stop.
  ShippingSize? get custom => sizes['custom'];

  static ShippingOptions fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ShippingOptions();

    final sizes = <String, ShippingSize>{};
    final rawSizes = json['sizes'];
    if (rawSizes is Map) {
      for (final e in rawSizes.entries) {
        final value = e.value;
        if (value is! Map) continue;
        final size = ShippingSize.fromJson(e.key.toString(), value.cast<String, dynamic>());
        if (size != null) sizes[size.code] = size;
      }
    }

    final byCategory = <String, List<String>>{};
    final rawByCategory = json['by_category'];
    if (rawByCategory is Map) {
      for (final e in rawByCategory.entries) {
        final value = e.value;
        // A category whose value is not a list is one category with no
        // overrides, not a broken catalogue.
        if (value is! List) continue;
        final keys = value.map((v) => v.toString()).where(sizes.containsKey).toList();
        if (keys.isNotEmpty) byCategory[e.key.toString()] = keys;
      }
    }

    return ShippingOptions(
      enabled: json['enabled'] == true,
      sizes: sizes,
      defaultSizes: (json['default'] as List? ?? const [])
          .map((v) => v.toString())
          .where(sizes.containsKey)
          .toList(growable: false),
      byCategory: byCategory,
      from: _places(json['from_locations']),
      to: _places(json['to_locations']),
      tiers: (json['tiers'] is List ? json['tiers'] as List : const [])
          .whereType<Map>()
          .map((m) => ShippingTier.fromJson(m.cast<String, dynamic>()))
          .whereType<ShippingTier>()
          .toList(growable: false),
      currency: json['currency']?.toString() ?? 'XAF',
    );
  }

  static List<ShippingPlace> _places(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => ShippingPlace.fromJson(m.cast<String, dynamic>()))
        .whereType<ShippingPlace>()
        .toList(growable: false);
  }
}

/// One checkpoint on a shipment's journey.
///
/// [code] is deliberately a plain string. The server treats it the same way, so
/// a driver app inventing a checkpoint kind nobody has heard of shows up here
/// without either side needing a release — an unrecognised code falls back to
/// its own [note]. Everything about where is optional and independent: a
/// customs office has a name and no coordinates, a phone ping has coordinates
/// and no name, and a plain status change has neither.
class TrackingEvent {
  const TrackingEvent({
    required this.id,
    required this.code,
    required this.happenedAt,
    this.note,
    this.placeName,
    this.lat,
    this.lng,
    this.source = 'staff',
    this.carrierRef,
  });

  final String id;
  final String code;
  final DateTime happenedAt;
  final String? note;
  final String? placeName;
  final double? lat;
  final double? lng;
  final String source;
  final String? carrierRef;

  bool get hasPosition => lat != null && lng != null;

  /// Somewhere to show, whichever way it was given.
  String? get where => placeName ??
      (hasPosition ? '${lat!.toStringAsFixed(4)}, ${lng!.toStringAsFixed(4)}' : null);

  static TrackingEvent? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = json['id']?.toString();
    final code = json['code']?.toString();
    final at = DateTime.tryParse(json['happened_at']?.toString() ?? '');
    // Without a code or a time there is nothing to put on a timeline.
    if (id == null || code == null || code.isEmpty || at == null) return null;
    return TrackingEvent(
      id: id,
      code: code,
      happenedAt: at,
      note: _text(json['note']),
      placeName: _text(json['place_name']),
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      source: json['source']?.toString() ?? 'staff',
      carrierRef: _text(json['carrier_ref']),
    );
  }
}

/// A request the customer has already sent.
class ShippingRequest {
  const ShippingRequest({
    required this.id,
    required this.status,
    required this.source,
    this.itemTitle,
    this.fromLocation = '',
    this.toLocation = '',
    this.quantity = 1,
    this.quotedTotalCents,
    this.currency = 'XAF',
    this.conversationId,
    this.unread = 0,
    this.createdAt,
    this.lastEventCode,
    this.lastEventNote,
    this.lastPlaceName,
    this.lastLat,
    this.lastLng,
    this.lastEventAt,
    this.tracking = const [],
    this.reference,
    this.tier,
    this.etaDaysMin,
    this.etaDaysMax,
    this.quoteExpiresAt,
    this.acceptedAt,
    this.paidAt,
    this.collectedCents,
    this.deliveredAt,
    this.sizeKey,
    this.sizeCustom,
    this.itemDescription,
    this.pickupAddress,
    this.pickupContactName,
    this.pickupPhone,
    this.deliveryAddress,
    this.contactName,
    this.contactPhone,
    this.note,
    this.fromPlace,
    this.toPlace,
    this.locale,
  });

  final String id;
  final String status;
  final String source;
  final String? itemTitle;

  /// `MB-10023`. What a receipt, a phone call and a chat message all use.
  final String? reference;
  final String? tier;
  final int? etaDaysMin;
  final int? etaDaysMax;
  final DateTime? quoteExpiresAt;
  final DateTime? acceptedAt;
  final DateTime? paidAt;

  /// What the courier actually took at the door. Francs.
  final int? collectedCents;
  final DateTime? deliveredAt;
  final String? sizeKey;
  final String? sizeCustom;
  final String? itemDescription;
  final String? pickupAddress;
  final String? pickupContactName;
  final String? pickupPhone;
  final String? deliveryAddress;
  final String? contactName;
  final String? contactPhone;
  final String? note;
  final String? fromPlace;
  final String? toPlace;
  final String? locale;
  final String fromLocation;
  final String toLocation;
  final int quantity;
  final int? quotedTotalCents;
  final String currency;
  final String? conversationId;
  final int unread;
  final DateTime? createdAt;

  /// Where it was last seen, denormalised onto the request so a list of
  /// shipments needs one call and the live subscription has a row to fire on.
  final String? lastEventCode;
  final String? lastEventNote;
  final String? lastPlaceName;
  final double? lastLat;
  final double? lastLng;
  final DateTime? lastEventAt;

  /// The full journey. Only loaded on the detail call.
  final List<TrackingEvent> tracking;

  bool get isMoving => const {'in_transit', 'sourcing'}.contains(status);
  bool get isFinished =>
      const {'delivered', 'cancelled', 'declined'}.contains(status);
  bool get hasPosition => lastLat != null && lastLng != null;

  String? get lastSeen => lastPlaceName ??
      (hasPosition
          ? '${lastLat!.toStringAsFixed(4)}, ${lastLng!.toStringAsFixed(4)}'
          : null);

  String? get quotedPrice =>
      quotedTotalCents == null ? null : formatPrice(quotedTotalCents!, currency: currency);

  /// A price the desk has set that the customer has not yet said yes to.
  bool get isQuotePending {
    if (status != 'quoted') return false;
    final until = quoteExpiresAt;
    return until == null || until.isAfter(DateTime.now());
  }

  /// What is paid at the door: what was collected once it has been, else
  /// what was quoted.
  int? get codCents => collectedCents ?? quotedTotalCents;
  String? get codPrice => codCents == null ? null : formatPrice(codCents!, currency: currency);

  /// `#MB-10023`, or empty for a row from before references existed.
  String get displayRef => reference == null ? '' : '#$reference';

  EtaWindow? eta({DateTime? now}) => EtaWindow.of(this, now: now);

  static ShippingRequest? fromJson(Map<String, dynamic>? json, {List<dynamic>? tracking}) {
    if (json == null) return null;
    final id = json['id']?.toString();
    if (id == null || id.isEmpty) return null;
    final conv = (json['conversation'] as Map?)?.cast<String, dynamic>();
    return ShippingRequest(
      id: id,
      status: json['status']?.toString() ?? 'new',
      source: json['source']?.toString() ?? 'external',
      itemTitle: _text(json['item_title']),
      fromLocation: json['from_location']?.toString() ?? '',
      toLocation: json['to_location']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      quotedTotalCents: (json['quoted_total_cents'] as num?)?.toInt(),
      currency: json['currency']?.toString() ?? 'XAF',
      conversationId: conv?['id']?.toString(),
      unread: (conv?['buyer_unread'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      lastEventCode: _text(json['last_event_code']),
      lastEventNote: _text(json['last_event_note']),
      lastPlaceName: _text(json['last_place_name']),
      lastLat: (json['last_lat'] as num?)?.toDouble(),
      lastLng: (json['last_lng'] as num?)?.toDouble(),
      lastEventAt: DateTime.tryParse(json['last_event_at']?.toString() ?? ''),
      reference: _text(json['reference']),
      tier: _text(json['tier']),
      etaDaysMin: (json['eta_days_min'] as num?)?.toInt(),
      etaDaysMax: (json['eta_days_max'] as num?)?.toInt(),
      quoteExpiresAt: DateTime.tryParse(json['quote_expires_at']?.toString() ?? ''),
      acceptedAt: DateTime.tryParse(json['accepted_at']?.toString() ?? ''),
      paidAt: DateTime.tryParse(json['paid_at']?.toString() ?? ''),
      collectedCents: (json['collected_cents'] as num?)?.toInt(),
      deliveredAt: DateTime.tryParse(json['delivered_at']?.toString() ?? ''),
      sizeKey: _text(json['size_key']),
      sizeCustom: _text(json['size_custom']),
      itemDescription: _text(json['item_description']),
      pickupAddress: _text(json['pickup_address']),
      pickupContactName: _text(json['pickup_contact_name']),
      pickupPhone: _text(json['pickup_phone']),
      deliveryAddress: _text(json['delivery_address']),
      contactName: _text(json['contact_name']),
      contactPhone: _text(json['contact_phone']),
      note: _text(json['note']),
      fromPlace: _text(json['from_place']),
      toPlace: _text(json['to_place']),
      locale: _text(json['locale']),
      tracking: (tracking ?? const [])
          .whereType<Map>()
          .map((m) => TrackingEvent.fromJson(m.cast<String, dynamic>()))
          .whereType<TrackingEvent>()
          .toList(growable: false),
    );
  }
}

String? _text(dynamic value) {
  final s = value?.toString();
  return (s == null || s.isEmpty) ? null : s;
}

Map<String, String> _localised(Map<String, dynamic> json, String prefix) {
  final out = <String, String>{};
  for (final lang in const ['en', 'fr']) {
    final v = json['${prefix}_$lang'];
    if (v is String && v.trim().isNotEmpty) out[lang] = v;
  }
  return out;
}

/// The status, in words somebody who is not us would use.
///
/// Lives here rather than in a screen because both the inbox row and the thread
/// header show it, and two copies of a switch over ten statuses is two copies
/// that drift.
String shippingStatusLabel(AppLocalizations l10n, String? status) => switch (status) {
      'reviewing' => l10n.shipStatusReviewing,
      'quoted' => l10n.shipStatusQuoted,
      'accepted' => l10n.shipStatusAccepted,
      'sourcing' => l10n.shipStatusSourcing,
      'in_transit' => l10n.shipStatusInTransit,
      'delivered' => l10n.shipStatusDelivered,
      'cancelled' => l10n.shipStatusCancelled,
      'declined' => l10n.shipStatusDeclined,
      'expired' => l10n.shipStatusExpired,
      // Anything a later server invents reads as "we have it", which is true of
      // every state this list does not know about yet.
      _ => l10n.shipStatusNew,
    };

/// A checkpoint in words.
///
/// Only the codes this build knows are translated; anything else shows its own
/// note, and failing that the code itself. That is what lets a driver app add a
/// kind of checkpoint without waiting for an app release.
String trackingLabel(AppLocalizations l10n, TrackingEvent event) => switch (event.code) {
      'received' => l10n.trackReceived,
      'sourcing' => l10n.trackSourcing,
      'picked_up' => l10n.trackPickedUp,
      'in_transit' => l10n.trackInTransit,
      'customs' => l10n.trackCustoms,
      'arrived' => l10n.trackArrived,
      'out_for_delivery' => l10n.trackOutForDelivery,
      'delivered' => l10n.trackDelivered,
      'delayed' => l10n.trackDelayed,
      _ => event.note ?? event.code,
    };

/// The dot on the timeline.
IconData trackingIcon(String code) => switch (code) {
      'received' => Icons.inventory_2_outlined,
      'sourcing' => Icons.shopping_bag_outlined,
      'picked_up' => Icons.local_shipping_outlined,
      'in_transit' => Icons.local_shipping_outlined,
      'customs' => Icons.gavel_outlined,
      'arrived' => Icons.flight_land_outlined,
      'out_for_delivery' => Icons.directions_bike_outlined,
      'delivered' => Icons.check_circle_outline,
      'delayed' => Icons.schedule_outlined,
      _ => Icons.circle_outlined,
    };

/// An ETA range in words: "same day", "2 days", "1–2 days".
String etaText(AppLocalizations l10n, int? min, int? max) {
  if (min == null || max == null) return '';
  if (min == 0 && max == 0) return l10n.shipEtaSameDay;
  if (min == max) return l10n.shipEtaDaysOne(max);
  if (min == 0) return l10n.shipEtaUpTo(max);
  return l10n.shipEtaDays(min, max);
}
