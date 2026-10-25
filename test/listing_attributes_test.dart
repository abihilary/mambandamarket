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

  test('a leaf asks its own questions first, then its group\'s; a leaf field replaces the group\'s', () {
    final keys = attributeFieldsFor(categories, 'tutoring').map((f) => '${f.key}:${f.type}').toList();
    expect(keys, ['subjects:multi', 'where:single', 'experience_years:number']);
  });

  test('the 0066 display keys are read', () {
    final f = AttrField.fromJson({
      'key': 'battery_health', 'type': 'number', 'label_en': 'Battery health', 'label_fr': 'État de la batterie',
      'min': 50, 'max': 100, 'unit_en': '%', 'unit_fr': '%', 'short_en': 'Batt. {}', 'short_fr': 'Batt. {}',
      'card': 2, 'title_part': 1.1, 'grouped': true, 'section_en': 'Papers', 'section_fr': 'Papiers',
      'recommended': true, 'some_future_key': 'ignored',
    })!;
    expect(f.unit(const Locale('fr')), '%');
    expect(f.shortFr, 'Batt. {}');
    expect(f.card, 2);
    expect(f.titlePart, 1.1);
    expect(f.grouped, isTrue);
    expect(f.section(const Locale('fr')), 'Papiers');
    expect(f.section(const Locale('en')), 'Papers');
    expect(f.recommended, isTrue);
    expect(f.isChecklist, isFalse);

    final checklist = AttrField.fromJson({
      'key': 'in_box', 'type': 'multi', 'label_en': 'In the box', 'label_fr': 'Dans la boîte', 'display': 'checklist',
      'options': [
        {'value': 'unlocked', 'label_en': 'Unlocked, any network', 'label_fr': 'Débloqué tout opérateur',
         'short_en': 'Unlocked', 'short_fr': 'Débloqué'},
        _opt('box', 'Boîte'),
      ],
    })!;
    expect(checklist.isChecklist, isTrue);
    expect(checklist.options.first.short(const Locale('fr')), 'Débloqué');
    expect(checklist.options.last.short(const Locale('fr')), 'Boîte', reason: 'falls back to the label');
    // Only a multi can be a checklist.
    expect(AttrField.fromJson({'key': 'x', 'type': 'single', 'display': 'checklist'})!.isChecklist, isFalse);
  });

  test('a template from before 0066 parses exactly as it did', () {
    final f = AttrField.fromJson({'key': 'experience_years', 'type': 'number', 'label_en': 'Years', 'label_fr': 'Années'})!;
    expect(f.unit(const Locale('fr')), isNull);
    expect(f.grouped, isFalse);
    expect(f.card, isNull);
    expect(f.titlePart, isNull);
    expect(f.display, isNull);
    expect(f.section(const Locale('fr')), isNull);
    expect(f.recommended, isFalse);
    expect(f.describe(5, const Locale('fr'), yes: 'Oui'), '5');
    expect(f.describe(2.5, const Locale('en'), yes: 'Yes'), '2.5');
    // Wrongly typed display keys are dropped rather than thrown on.
    final odd = AttrField.fromJson({'key': 'k', 'type': 'number', 'card': 'two', 'title_part': '1', 'unit_fr': 3})!;
    expect(odd.card, isNull);
    expect(odd.titlePart, isNull);
    expect(odd.unit(const Locale('fr')), isNull);
  });

  test('describe keeps its signature and gains units and grouping', () {
    final km = AttrField.fromJson({'key': 'mileage_km', 'type': 'number', 'unit_en': 'km', 'unit_fr': 'km', 'grouped': true})!;
    expect(km.describe(145000, const Locale('fr'), yes: 'Oui'), '145.000\u00A0km');
    final pct = AttrField.fromJson({'key': 'battery', 'type': 'number', 'unit_en': '%', 'unit_fr': '%'})!;
    expect(pct.describe(88, const Locale('en'), yes: 'Yes'), '88%');
    expect(pct.describe(88, const Locale('fr'), yes: 'Oui'), '88\u00A0%');
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

  test('the detail embed\'s seller facts are kept', () {
    final l = Listing.fromJson({'id': '1', 'seller_id': 's', 'title': 'Phone', 'price_cents': 5000,
      'seller': {'id': 's', 'display_name': 'Raswar', 'city': 'Akwa, Douala', 'role': 'individual_seller',
        'created_at': '2025-03-14T10:00:00Z'},
      'store': {'shop_name': 'RASWAR', 'is_verified': false, 'rating_avg': '4.6', 'rating_count': 12},
      'seller_stats': {'active_listings': 11}});
    expect(l.sellerCity, 'Akwa, Douala');
    expect(l.sellerCreatedAt, DateTime.utc(2025, 3, 14, 10));
    expect(l.sellerActiveListings, 11);
    expect(l.storeRatingAvg, 4.6);
    expect(l.storeRatingCount, 12);

    final bare = Listing.fromJson({'id': '2', 'seller_id': 's', 'title': 'Old'});
    expect(bare.sellerCity, isNull);
    expect(bare.sellerCreatedAt, isNull);
    expect(bare.sellerActiveListings, isNull, reason: 'not counted is not the same as none');
    expect(bare.storeRatingAvg, isNull);
    expect(bare.storeRatingCount, 0);

    expect(Profile.fromJson({'id': 'p', 'created_at': '2025-03-14T10:00:00Z'}).createdAt, DateTime.utc(2025, 3, 14, 10));
    expect(Profile.fromJson({'id': 'p'}).createdAt, isNull);
  });
}
