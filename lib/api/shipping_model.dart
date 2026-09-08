import 'dart:ui' show Locale;

import 'board_model.dart' show pickLocalised;
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
  });

  final String code;
  final Map<String, String> label;
  final Map<String, String> hint;
  final double? kgMin;
  final double? kgMax;

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
    );
  }
}

/// Somewhere a shipment can start or end.
class ShippingPlace {
  const ShippingPlace({required this.code, required this.label});

  final String code;
  final Map<String, String> label;

  String labelFor(Locale locale) => pickLocalised(label, locale) ?? code;

  static ShippingPlace? fromJson(Map<String, dynamic> json) {
    final code = json['code']?.toString();
    final label = _localised(json, 'label');
    if (code == null || code.isEmpty || label.isEmpty) return null;
    return ShippingPlace(code: code, label: label);
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
  });

  final bool enabled;
  final Map<String, ShippingSize> sizes;
  final List<String> defaultSizes;
  final Map<String, List<String>> byCategory;
  final List<ShippingPlace> from;
  final List<ShippingPlace> to;

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
    this.createdAt,
  });

  final String id;
  final String status;
  final String source;
  final String? itemTitle;
  final String fromLocation;
  final String toLocation;
  final int quantity;
  final int? quotedTotalCents;
  final String currency;
  final String? conversationId;
  final DateTime? createdAt;

  String? get quotedPrice =>
      quotedTotalCents == null ? null : formatPrice(quotedTotalCents!, currency: currency);

  static ShippingRequest? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = json['id']?.toString();
    if (id == null || id.isEmpty) return null;
    final conv = (json['conversation'] as Map?)?.cast<String, dynamic>();
    return ShippingRequest(
      id: id,
      status: json['status']?.toString() ?? 'new',
      source: json['source']?.toString() ?? 'external',
      itemTitle: json['item_title']?.toString(),
      fromLocation: json['from_location']?.toString() ?? '',
      toLocation: json['to_location']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      quotedTotalCents: (json['quoted_total_cents'] as num?)?.toInt(),
      currency: json['currency']?.toString() ?? 'XAF',
      conversationId: conv?['id']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

Map<String, String> _localised(Map<String, dynamic> json, String prefix) {
  final out = <String, String>{};
  for (final lang in const ['en', 'fr']) {
    final v = json['${prefix}_$lang'];
    if (v is String && v.trim().isNotEmpty) out[lang] = v;
  }
  return out;
}
