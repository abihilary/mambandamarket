import 'dart:ui' show Locale;

import 'package:intl/intl.dart';

/// One answer a field offers ("M", "Maths", "At the client's").
class AttrOption {
  final String value;
  final String labelEn;
  final String labelFr;

  /// The compact form for cards, chips and the suggested title, when the full
  /// label is a sentence ("Unlocked, any network" → "Unlocked"). Migration 0066.
  final String? shortEn;
  final String? shortFr;

  const AttrOption({
    required this.value,
    required this.labelEn,
    required this.labelFr,
    this.shortEn,
    this.shortFr,
  });

  String label(Locale locale) =>
      locale.languageCode == 'fr' ? labelFr : labelEn;

  /// The compact form, or the label when the option has none.
  String short(Locale locale) => locale.languageCode == 'fr'
      ? (shortFr ?? labelFr)
      : (shortEn ?? labelEn);

  factory AttrOption.fromJson(Map<String, dynamic> j) => AttrOption(
    value: j['value'].toString(),
    labelEn: j['label_en']?.toString() ?? j['value'].toString(),
    labelFr:
        j['label_fr']?.toString() ??
        j['label_en']?.toString() ??
        j['value'].toString(),
    shortEn: _text(j['short_en']),
    shortFr: _text(j['short_fr']),
  );
}

/// A non-empty string, or null: display keys are optional and a template that
/// sends `""` means the same as one that leaves the key out.
String? _text(dynamic v) {
  if (v is! String) return null;
  final s = v.trim();
  return s.isEmpty ? null : v;
}

/// A detail a category asks for — sizes for clothes, subjects for tutoring.
///
/// The templates live on the server (`categories.attribute_schema`, migration
/// 0059), arrive with `/categories`, and are checked there again on save; this
/// only draws them. A type this build does not know is skipped rather than
/// guessed at.
///
/// 0066 added display keys (units, short forms, card and title positions,
/// checklists, sections). The server ignores them, and an older build simply
/// never reads them, so every one is optional here too.
class AttrField {
  /// single | multi | number | bool | text
  final String type;
  final String key;
  final String labelEn;
  final String labelFr;
  final String? hintEn;
  final String? hintFr;
  final List<AttrOption> options;
  final bool required;
  final bool filterable;
  final num? min;
  final num? max;

  /// Written after a number ("km", "%", "mois"), and shown as the input's
  /// suffix while typing.
  final String? unitEn;
  final String? unitFr;

  /// Thousands dots, the way prices read (145.000 km). Years leave it off.
  final bool grouped;

  /// The compact pattern for cards, chips and the title: `{}` stands for the
  /// formatted value ("Batt. {}"). On a bool it is the text shown when true.
  final String? shortEn;
  final String? shortFr;

  /// 1–3: the field's place on the card's spec line and in the key facts.
  final int? card;

  /// Order in the suggested title. Parts sharing a whole number join with a
  /// space, different ones with " · " (1 make, 1.1 model, 2 mileage).
  final num? titlePart;

  /// `checklist` on a multi: drawn as a ticked list of what is true.
  final String? display;

  /// A sub-head shown once over consecutive fields sharing it ("Papiers").
  final String? sectionEn;
  final String? sectionFr;

  /// Not required, but worth asking for: labelled and counted in progress.
  final bool recommended;

  const AttrField({
    required this.type,
    required this.key,
    required this.labelEn,
    required this.labelFr,
    this.hintEn,
    this.hintFr,
    this.options = const [],
    this.required = false,
    this.filterable = false,
    this.min,
    this.max,
    this.unitEn,
    this.unitFr,
    this.grouped = false,
    this.shortEn,
    this.shortFr,
    this.card,
    this.titlePart,
    this.display,
    this.sectionEn,
    this.sectionFr,
    this.recommended = false,
  });

  static const types = {'single', 'multi', 'number', 'bool', 'text'};

  String label(Locale locale) =>
      locale.languageCode == 'fr' ? labelFr : labelEn;
  String? hint(Locale locale) =>
      locale.languageCode == 'fr' ? (hintFr ?? hintEn) : hintEn;
  String? unit(Locale locale) =>
      locale.languageCode == 'fr' ? (unitFr ?? unitEn) : unitEn;
  String? section(Locale locale) =>
      locale.languageCode == 'fr' ? (sectionFr ?? sectionEn) : sectionEn;

  bool get isChecklist => type == 'multi' && display == 'checklist';

  String optionLabel(String value, Locale locale) {
    for (final o in options) {
      if (o.value == value) return o.label(locale);
    }
    return value;
  }

  static AttrField? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final j = raw.cast<String, dynamic>();
    final type = j['type']?.toString();
    final key = j['key']?.toString();
    if (type == null || key == null || !types.contains(type)) return null;
    return AttrField(
      type: type,
      key: key,
      labelEn: j['label_en']?.toString() ?? key,
      labelFr: j['label_fr']?.toString() ?? j['label_en']?.toString() ?? key,
      hintEn: j['hint_en']?.toString(),
      hintFr: j['hint_fr']?.toString(),
      options: [
        for (final o in (j['options'] as List? ?? const []))
          if (o is Map) AttrOption.fromJson(o.cast<String, dynamic>()),
      ],
      required: j['required'] == true,
      filterable: j['filterable'] == true,
      min: j['min'] as num?,
      max: j['max'] as num?,
      unitEn: _text(j['unit_en']),
      unitFr: _text(j['unit_fr']),
      grouped: j['grouped'] == true,
      shortEn: _text(j['short_en']),
      shortFr: _text(j['short_fr']),
      card: j['card'] is num ? (j['card'] as num).toInt() : null,
      titlePart: j['title_part'] is num ? j['title_part'] as num : null,
      display: _text(j['display']),
      sectionEn: _text(j['section_en']),
      sectionFr: _text(j['section_fr']),
      recommended: j['recommended'] == true,
    );
  }

  static List<AttrField> listFromJson(dynamic raw) => [
    for (final f in (raw is List ? raw : const []))
      if (AttrField.fromJson(f) case final AttrField field) field,
  ];

  /// An answer as words, for the detail screen: "M, L", "145.000 km", "Yes".
  ///
  /// Answers in the order they were given, and keeps a value the template no
  /// longer lists. [format] is the template-ordered form newer screens use.
  String? describe(dynamic value, Locale locale, {required String yes}) {
    if (value == null) return null;
    switch (type) {
      case 'multi':
        final list = value is List ? value : [value];
        if (list.isEmpty) return null;
        return list.map((v) => optionLabel(v.toString(), locale)).join(', ');
      case 'single':
        return optionLabel(value.toString(), locale);
      case 'bool':
        return value == true ? yes : null;
      case 'number':
        final n = value is num ? value : num.tryParse(value.toString());
        return n == null ? value.toString() : _withUnit(n, locale);
      default:
        final s = value.toString().trim();
        return s.isEmpty ? null : s;
    }
  }

  /// An answer formatted for reading (§2.3 of the category-native listings
  /// spec; the site ports the same rules to JS).
  ///
  /// The long form is for the details table. [short] is for cards, key-fact
  /// chips and the suggested title: a single's short option label, a contiguous
  /// size run as "38–43", more than two colours as "Noir, Blanc +2", all
  /// wrapped in the field's `{}` pattern. A false bool is never shown — when
  /// "no" matters, a template asks with a two-option single instead.
  String? format(
    dynamic value,
    Locale locale, {
    bool short = false,
    required String yes,
  }) {
    if (!AttrField.answered(value)) return null;
    final fr = locale.languageCode == 'fr';
    final pattern = fr ? (shortFr ?? shortEn) : shortEn;
    String wrap(String s) => short && pattern != null && pattern.contains('{}')
        ? pattern.replaceAll('{}', s)
        : s;
    switch (type) {
      case 'bool':
        if (value != true) return null;
        if (!short) return yes;
        return pattern ?? label(locale);
      case 'single':
        AttrOption? o;
        for (final x in options) {
          if (x.value == value.toString()) o = x;
        }
        if (o == null) return wrap(value.toString());
        return wrap(short ? o.short(locale) : o.label(locale));
      case 'multi':
        final picked = {
          for (final x in (value is List ? value : [value])) x.toString(),
        };
        final idx = [
          for (var i = 0; i < options.length; i++)
            if (picked.contains(options[i].value)) i,
        ];
        // A value the template has since dropped still reads, after the rest.
        final known = {for (final i in idx) options[i].value};
        final stray = [for (final v in picked) if (!known.contains(v)) v];
        // Full option labels even when short, as the site's formatValue does:
        // the short form of a multi comes from the run and the "+n".
        final labels = [
          for (final i in idx) options[i].label(locale),
          ...stray,
        ];
        if (labels.isEmpty) return null;
        if (!short) return labels.join(', ');
        final contiguous = stray.isEmpty &&
            idx.length >= 3 &&
            idx.last - idx.first == idx.length - 1;
        if (contiguous) return wrap('${labels.first}–${labels.last}');
        return wrap(labels.length > 2
            ? '${labels.take(2).join(', ')} +${labels.length - 2}'
            : labels.join(', '));
      case 'number':
        final n = value is num ? value : num.tryParse(value.toString());
        if (n == null) return null;
        return wrap(_withUnit(n, locale));
      default:
        final s = value.toString().trim();
        return s.isEmpty ? null : s;
    }
  }

  /// A number with its grouping and unit: "145.000 km", "88 %", EN "88%".
  ///
  /// Grouped numbers use de_DE dots in both languages, the way prices already
  /// read; ungrouped ones stay plain so a year is 2012, with a French decimal
  /// comma. English writes % and ″ against the number; everything else gets a
  /// no-break space so "145.000" and "km" never land on different lines.
  String _withUnit(num n, Locale locale) {
    final fr = locale.languageCode == 'fr';
    final text = grouped
        ? NumberFormat.decimalPattern('de_DE').format(n)
        : n % 1 == 0
        ? n.toInt().toString()
        : fr
        ? n.toString().replaceAll('.', ',')
        : n.toString();
    final u = unit(locale);
    if (u == null) return text;
    return !fr && (u.startsWith('%') || u.startsWith('″'))
        ? '$text$u'
        : '$text\u00A0$u';
  }

  /// Whether [value] counts as an answer (empty lists and strings do not).
  static bool answered(dynamic value) =>
      value != null &&
      !(value is List && value.isEmpty) &&
      !(value is String && value.trim().isEmpty);
}
