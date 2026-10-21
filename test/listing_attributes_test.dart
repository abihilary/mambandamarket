import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:mambandamarket/api/listing_attributes.dart';
import 'package:mambandamarket/api/models.dart';

Map<String, dynamic> _opt(String v, [String? fr]) => {'value': v, 'label_en': v, 'label_fr': fr ?? v};

void main() {
  final categories = [
    Category.fromJson({'slug': 'mode', 'label': 'Mode'}),
    Category.fromJson({
      'slug': 'womens-fashion',
      'label': 'Mode femme',
      'parent_slug': 'mode',
      'attribute_schema': [
        {'key': 'sizes', 'type': 'multi', 'label_en': 'Sizes available', 'label_fr': 'Tailles disponibles',
         'required': true, 'filterable': true, 'options': [_opt('S'), _opt('M'), _opt('one_size', 'Taille unique')]},
      ],
    }),
    Category.fromJson({
      'slug': 'dienstleistungen',
      'label': 'Services',
      'attribute_schema': [
        {'key': 'where', 'type': 'multi', 'label_en': 'Where', 'label_fr': 'Où', 'options': [_opt('online')]},
        {'key': 'experience_years', 'type': 'number', 'label_en': 'Years', 'label_fr': 'Années'},
        {'key': 'future_kind', 'type': 'colour-wheel', 'label_en': 'Not known yet', 'label_fr': '?'},
      ],
    }),
    Category.fromJson({
      'slug': 'tutoring',
      'label': 'Cours',
      'parent_slug': 'dienstleistungen',
      'attribute_schema': [
        {'key': 'subjects', 'type': 'multi', 'label_en': 'Subjects', 'label_fr': 'Matières', 'options': [_opt('maths')]},
        {'key': 'where', 'type': 'single', 'label_en': 'Where (leaf)', 'label_fr': 'Où', 'options': [_opt('online')]},
      ],
    }),
  ];

  test('a leaf asks its group\'s questions, then its own; a leaf field replaces the group\'s', () {
    final keys = attributeFieldsFor(categories, 'tutoring').map((f) => '${f.key}:${f.type}').toList();
    expect(keys, ['where:single', 'experience_years:number', 'subjects:multi']);
  });

  test('a field type this build does not know is skipped, not guessed', () {
    expect(attributeFieldsFor(categories, 'dienstleistungen').map((f) => f.key), isNot(contains('future_kind')));
  });

  test('categories without a template ask nothing', () {
    expect(attributeFieldsFor(categories, 'mode'), isEmpty);
    expect(attributeFieldsFor(categories, null), isEmpty);
    expect(attributeFieldsFor(categories, 'nope'), isEmpty);
  });

  test('answers read as words, in the reader\'s language', () {
    final sizes = attributeFieldsFor(categories, 'womens-fashion').single;
    expect(sizes.describe(['S', 'one_size'], const Locale('fr'), yes: 'Oui'), 'S, Taille unique');
    expect(sizes.describe(const [], const Locale('en'), yes: 'Yes'), isNull);
    expect(AttrField.answered(const <String>[]), isFalse);
    expect(AttrField.answered(['M']), isTrue);
  });

  test('a listing keeps its details from the API', () {
    final l = Listing.fromJson({'id': '1', 'seller_id': 's', 'title': 'Dress', 'price_cents': 5000,
      'attributes': {'sizes': ['M']}});
    expect(l.attributes['sizes'], ['M']);
    expect(Listing.fromJson({'id': '2', 'seller_id': 's', 'title': 'Old'}).attributes, isEmpty);
  });
}
