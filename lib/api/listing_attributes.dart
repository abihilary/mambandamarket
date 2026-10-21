import 'dart:ui' show Locale;

/// One answer a field offers ("M", "Maths", "At the client's").
class AttrOption {
  final String value;
  final String labelEn;
  final String labelFr;

  const AttrOption({
    required this.value,
    required this.labelEn,
    required this.labelFr,
  });

  String label(Locale locale) =>
      locale.languageCode == 'fr' ? labelFr : labelEn;

  factory AttrOption.fromJson(Map<String, dynamic> j) => AttrOption(
    value: j['value'].toString(),
    labelEn: j['label_en']?.toString() ?? j['value'].toString(),
    labelFr:
        j['label_fr']?.toString() ??
        j['label_en']?.toString() ??
        j['value'].toString(),
  );
}

/// A detail a category asks for — sizes for clothes, subjects for tutoring.
///
/// The templates live on the server (`categories.attribute_schema`, migration
/// 0059), arrive with `/categories`, and are checked there again on save; this
/// only draws them. A type this build does not know is skipped rather than
/// guessed at.
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
  });

  static const types = {'single', 'multi', 'number', 'bool', 'text'};

  String label(Locale locale) =>
      locale.languageCode == 'fr' ? labelFr : labelEn;
  String? hint(Locale locale) =>
      locale.languageCode == 'fr' ? (hintFr ?? hintEn) : hintEn;

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
    );
  }

  static List<AttrField> listFromJson(dynamic raw) => [
    for (final f in (raw is List ? raw : const []))
      if (AttrField.fromJson(f) case final AttrField field) field,
  ];

  /// An answer as words, for the detail screen: "M, L", "5", "Yes".
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
        return value is num
            ? (value % 1 == 0 ? value.toInt().toString() : value.toString())
            : value.toString();
      default:
        final s = value.toString().trim();
        return s.isEmpty ? null : s;
    }
  }

  /// Whether [value] counts as an answer (empty lists and strings do not).
  static bool answered(dynamic value) =>
      value != null &&
      !(value is List && value.isEmpty) &&
      !(value is String && value.trim().isEmpty);
}
