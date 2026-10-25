import 'dart:ui' show Locale;

import '../Components/category_picker.dart' show foldForSearch;
import '../l10n/l10n.dart';
import 'listing_attributes.dart';
import 'listing_guide.dart';
import 'models.dart';

// How a listing reads, from the answers its seller gave — shared by the item
// page, the cards and the create form so the three never disagree.
//
// Pure functions only. The rule they all follow: nothing appears that the
// data cannot back. An unanswered field, a false bool and a condition that
// was never chosen render as nothing, never as a placeholder.

/// The stored condition in the reader's language, or null for none or one
/// this build does not know.
String? conditionLabel(AppLocalizations l10n, String? raw) => switch (raw) {
  'New' => l10n.createConditionNew,
  'Like New' => l10n.createConditionLikeNew,
  'Used' => l10n.createConditionUsed,
  'Refurbished' => l10n.createConditionRefurbished,
  _ => null,
};

/// [resolved] in form and table order: the fields, then every checklist,
/// which draw as blocks after the rows.
List<AttrField> displayFields(List<AttrField> resolved) => [
  for (final f in resolved)
    if (!f.isChecklist) f,
  for (final f in resolved)
    if (f.isChecklist) f,
];

/// "New" says almost nothing on a card: it was the form's default until
/// 1.0.46, and 45 of the first 53 products carry it. The other three are
/// something a seller chose to say.
const _cardConditions = {'Like New', 'Used', 'Refurbished'};

/// The short facts for a card's spec line (`forCard`) or the item page's
/// chips: the template's card fields in card order ("Batt. 88 %",
/// "145.000 km"), less any the title already says, then the condition if
/// there is room.
///
/// On a card the condition goes last and only when it is not "New"; on the
/// item page it goes first, whatever it is.
List<String> specParts(
  Listing x,
  List<AttrField> fields,
  ListingGuide g,
  AppLocalizations l10n,
  Locale l, {
  int max = 3,
  bool forCard = true,
}) {
  final carded = [
    for (final f in fields)
      if (f.card != null && f.card! >= 1 && f.card! <= 3) f,
  ]..sort((a, b) => a.card!.compareTo(b.card!));
  final title = _fold(x.title);
  final parts = <String>[
    for (final f in carded)
      if (f.format(x.attributes[f.key], l, short: true, yes: l10n.detailsYes)
          case final String s
          when !title.contains(_fold(s)))
        s,
  ];
  if (parts.length < max && x.isProduct && g.condition) {
    final raw = x.condition;
    final wanted = forCard ? _cardConditions.contains(raw) : raw != null;
    final label = wanted ? conditionLabel(l10n, raw) : null;
    if (label != null && forCard) {
      parts.add(label);
    } else if (label != null) {
      parts.insert(0, label);
    }
  }
  return parts.take(max).toList();
}

/// A title built from the answers ("Apple iPhone 13 Pro · 256 Go"), offered
/// to the seller and only ever applied on tap.
///
/// Fields with a `title_part`, in that order. A part another part already
/// contains is dropped, so a model typed as "Samsung Galaxy A54" does not
/// become "Samsung Samsung Galaxy A54". Parts sharing a whole number join with
/// a space, groups with " · ", and whole groups come off the end until it fits
/// [maxLen]. Null with fewer than two answers to build from, or when nothing
/// fits.
String? suggestTitle(
  Map<String, dynamic> answers,
  List<AttrField> fields,
  Locale l, {
  int maxLen = 70,
  required String yes,
}) {
  // With the template index, because List.sort is not stable and two equal
  // parts should keep the template's order.
  final titled = [
    for (var i = 0; i < fields.length; i++)
      if (fields[i].titlePart != null) (i, fields[i]),
  ]..sort((a, b) {
      final c = a.$2.titlePart!.compareTo(b.$2.titlePart!);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
  final parts = <(int, String)>[
    for (final (_, f) in titled)
      if (f.format(answers[f.key], l, short: true, yes: yes) case final String s)
        (f.titlePart!.floor(), s),
  ];
  if (parts.length < 2) return null;

  final folded = [for (final p in parts) _fold(p.$2)];
  final kept = <(int, String)>[];
  for (var i = 0; i < parts.length; i++) {
    var dropped = false;
    for (var j = 0; j < parts.length && !dropped; j++) {
      if (i == j || !folded[j].contains(folded[i])) continue;
      // Keep the longer; between two equal parts, the first.
      dropped = folded[j].length > folded[i].length || j < i;
    }
    if (!dropped) kept.add(parts[i]);
  }

  final groups = <List<String>>[];
  int? current;
  for (final (group, text) in kept) {
    if (group != current) {
      groups.add([]);
      current = group;
    }
    groups.last.add(text);
  }
  String joined() => groups.map((g) => g.join(' ')).join(' · ');
  while (groups.isNotEmpty && joined().length > maxLen) {
    groups.removeLast();
  }
  return groups.isEmpty ? null : joined();
}

/// The price as it should read on the item page or (`compact`) a card,
/// following the listing's price mode and the category's per-unit suffix
/// ("75.000 FCFA / mois").
///
/// [Listing.displayPrice] stays what chat, checkout and the share subject
/// read; this is the richer form the browsing surfaces use. `tail` is the
/// card's muted "nég."; `negotiableChip` asks the item page for its outline
/// chip instead.
({String main, String? tail, bool negotiableChip}) priceLine(
  Listing x,
  ListingGuide g,
  AppLocalizations l10n, {
  bool compact = false,
}) {
  final locale = Locale(l10n.localeName.split(RegExp('[_-]')).first);
  final unit = g.pricePer(locale);
  final per = unit == null ? '' : ' / $unit';
  final amount = formatPrice(x.priceCents, currency: x.currency);
  ({String main, String? tail, bool negotiableChip}) only(String main) =>
      (main: main, tail: null, negotiableChip: false);

  switch (x.priceMode) {
    case 'negotiable':
      if (x.priceCents <= 0) return only(l10n.priceNegotiable);
      return compact
          ? (main: '$amount$per', tail: l10n.priceNegShort, negotiableChip: false)
          : (main: '$amount$per', tail: null, negotiableChip: true);
    case 'on_request':
      return only(l10n.priceOnRequest);
    case 'free':
      return only(l10n.priceFree);
    case 'from':
      return only(compact
          ? l10n.priceFromShort('$amount$per')
          : l10n.priceFrom('$amount$per'));
    case 'hourly':
      return only(l10n.pricePerHour(amount));
    case 'daily':
      return only(l10n.pricePerDay(amount));
    default:
      return only('$amount$per');
  }
}

/// Folded for comparison: accents and case gone, and the no-break spaces the
/// formatter puts before units read as the plain spaces a seller types.
String _fold(String s) =>
    foldForSearch(s).replaceAll(RegExp('[  ]'), ' ').trim();
