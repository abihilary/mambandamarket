import 'dart:ui' show Locale;

/// How a category wants its listings asked for and shown, beyond the fields
/// themselves: the photo shot list, description prompts, buyer tips, a price
/// label and per-unit suffix ("Loyer", "/ mois"), and which of condition,
/// warranty and delivery mean anything here at all.
///
/// Lives in `categories.listing_guide` (migration 0066), so improving a
/// category is SQL rather than a release. Every key is optional and the
/// parser forgives anything it does not expect: a guide is advice, and a
/// malformed one must cost a hint, never a screen.
class ListingGuide {
  final String? titleExampleEn;
  final String? titleExampleFr;
  final String? descriptionHintEn;
  final String? descriptionHintFr;
  final String? priceLabelEn;
  final String? priceLabelFr;
  final String? pricePerEn;
  final String? pricePerFr;
  final String? noteEn;
  final String? noteFr;

  /// chat | quote | apply | visit, or null for the default "Message" button.
  /// Only the label changes; every one opens the same chat.
  final String? cta;

  /// The shot list: labels for the empty photo tiles, in order.
  final List<GuideTip> photoTips;

  /// "Before you pay" — at most three are shown.
  final List<GuideTip> buyerTips;
  final List<GuidePrompt> describePrompts;

  /// Advisory only; the form never blocks on it.
  final int? photoMin;

  /// Narrows the price-mode chips (intersected with the kind's). Null means
  /// no restriction. The server does not enforce it.
  final List<String>? priceModes;

  /// False switches the concept off for the category — no condition on land,
  /// no warranty on a job, no delivery for a flat. Default true.
  final bool condition;
  final bool warranty;
  final bool delivery;

  const ListingGuide({
    this.titleExampleEn,
    this.titleExampleFr,
    this.descriptionHintEn,
    this.descriptionHintFr,
    this.priceLabelEn,
    this.priceLabelFr,
    this.pricePerEn,
    this.pricePerFr,
    this.noteEn,
    this.noteFr,
    this.cta,
    this.photoTips = const [],
    this.buyerTips = const [],
    this.describePrompts = const [],
    this.photoMin,
    this.priceModes,
    this.condition = true,
    this.warranty = true,
    this.delivery = true,
  });

  /// No guide: everything on, nothing suggested. What every category reads as
  /// before 0066, and what a missing or broken guide falls back to.
  static const empty = ListingGuide();

  static const ctas = {'chat', 'quote', 'apply', 'visit'};

  String? titleExample(Locale l) => _pick(l, titleExampleEn, titleExampleFr);
  String? descriptionHint(Locale l) =>
      _pick(l, descriptionHintEn, descriptionHintFr);
  String? priceLabel(Locale l) => _pick(l, priceLabelEn, priceLabelFr);

  /// The unit a price is per ("mois"), without the slash.
  String? pricePer(Locale l) => _pick(l, pricePerEn, pricePerFr);
  String? note(Locale l) => _pick(l, noteEn, noteFr);

  factory ListingGuide.fromJson(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) return empty;
    final modes = raw['price_modes'];
    final priceModes = modes is List
        ? [for (final m in modes) if (m is String && m.isNotEmpty) m]
        : const <String>[];
    final cta = raw['cta'];
    final photoMin = raw['photo_min'];
    return ListingGuide(
      titleExampleEn: _str(raw['title_example_en']),
      titleExampleFr: _str(raw['title_example_fr']),
      descriptionHintEn: _str(raw['description_hint_en']),
      descriptionHintFr: _str(raw['description_hint_fr']),
      priceLabelEn: _str(raw['price_label_en']),
      priceLabelFr: _str(raw['price_label_fr']),
      pricePerEn: _str(raw['price_per_en']),
      pricePerFr: _str(raw['price_per_fr']),
      noteEn: _str(raw['note_en']),
      noteFr: _str(raw['note_fr']),
      cta: cta is String && ctas.contains(cta) ? cta : null,
      photoTips: GuideTip.listFromJson(raw['photo_tips']),
      buyerTips: GuideTip.listFromJson(raw['buyer_tips']),
      describePrompts: GuidePrompt.listFromJson(raw['describe_prompts']),
      photoMin: photoMin is num && photoMin > 0 ? photoMin.toInt() : null,
      priceModes: priceModes.isEmpty ? null : List.unmodifiable(priceModes),
      condition: !_isFalse(raw['condition']),
      warranty: !_isFalse(raw['warranty']),
      delivery: !_isFalse(raw['delivery']),
    );
  }

  /// The guide a listing in a leaf follows: the group's, with the leaf's own
  /// keys on top. The leaf wins per top-level key and a list replaces a list
  /// rather than adding to it, which is how the server resolves it too.
  static ListingGuide resolve(
    Map<String, dynamic>? root,
    Map<String, dynamic>? leaf,
  ) =>
      ListingGuide.fromJson({...?root, ...?leaf});
}

/// One line of advice in both languages: a photo to take, a check to make.
class GuideTip {
  final String en;
  final String fr;

  const GuideTip({required this.en, required this.fr});

  String text(Locale l) => _pick(l, en, fr) ?? '';

  /// Tips from a guide, skipping anything that is not one. A bare string is
  /// taken as the same text in both languages.
  static List<GuideTip> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    final out = <GuideTip>[];
    for (final t in raw) {
      if (t is String && t.trim().isNotEmpty) {
        out.add(GuideTip(en: t, fr: t));
      } else if (t is Map) {
        final en = _str(t['en']);
        final fr = _str(t['fr']);
        if (en != null || fr != null) {
          out.add(GuideTip(en: en ?? fr!, fr: fr ?? en!));
        }
      }
    }
    return List.unmodifiable(out);
  }
}

/// A question buyers ask, offered as a chip over the description. Tapping it
/// appends [starter] on a new line for the seller to finish.
class GuidePrompt {
  final String en;
  final String fr;
  final String starterEn;
  final String starterFr;

  const GuidePrompt({
    required this.en,
    required this.fr,
    required this.starterEn,
    required this.starterFr,
  });

  String label(Locale l) => _pick(l, en, fr) ?? '';
  String starter(Locale l) => _pick(l, starterEn, starterFr) ?? '';

  static List<GuidePrompt> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    final out = <GuidePrompt>[];
    for (final p in raw) {
      if (p is! Map) continue;
      final en = _str(p['en']);
      final fr = _str(p['fr']);
      if (en == null && fr == null) continue;
      // A prompt without a starter still works: the question itself, which
      // the seller answers after it.
      final starterEn = _str(p['starter_en'], trim: false);
      final starterFr = _str(p['starter_fr'], trim: false);
      out.add(GuidePrompt(
        en: en ?? fr!,
        fr: fr ?? en!,
        starterEn: starterEn ?? starterFr ?? '${en ?? fr} ',
        starterFr: starterFr ?? starterEn ?? '${fr ?? en} ',
      ));
    }
    return List.unmodifiable(out);
  }
}

/// A usable string, or null. [trim] off keeps a starter's trailing space
/// ("Repairs: "), which is what puts the cursor after the colon.
String? _str(dynamic v, {bool trim = true}) {
  if (v is! String || v.trim().isEmpty) return null;
  return trim ? v.trim() : v;
}

bool _isFalse(dynamic v) => v == false || v == 'false';

/// The reader's language, else the other one: a guide written in one
/// language still beats no guide.
String? _pick(Locale l, String? en, String? fr) {
  final a = l.languageCode == 'fr' ? fr : en;
  final b = l.languageCode == 'fr' ? en : fr;
  return (a != null && a.isNotEmpty) ? a : ((b != null && b.isNotEmpty) ? b : null);
}
