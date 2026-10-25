// How a listing reads from its answers (§2.3, §6.3 of the category-native
// listings spec): formatted values, the card spec line, the suggested title
// and the mode-aware price. Fixtures are cut from migration 0066's templates.
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:mambandamarket/api/listing_attributes.dart';
import 'package:mambandamarket/api/listing_guide.dart';
import 'package:mambandamarket/api/listing_presentation.dart';
import 'package:mambandamarket/api/models.dart';
import 'package:mambandamarket/l10n/gen/app_localizations.dart';

const _fr = Locale('fr');
const _en = Locale('en');
const _nb = ' ';

Map<String, dynamic> _o(String v, String en, [String? fr]) => {'value': v, 'label_en': en, 'label_fr': fr ?? en};

final _colours = [
  _o('black', 'Black', 'Noir'), _o('white', 'White', 'Blanc'), _o('grey', 'Grey', 'Gris'),
  _o('beige', 'Beige'), _o('brown', 'Brown', 'Marron'), _o('red', 'Red', 'Rouge'),
  _o('pink', 'Pink', 'Rose'), _o('orange', 'Orange'), _o('yellow', 'Yellow', 'Jaune'),
  _o('green', 'Green', 'Vert'), _o('blue', 'Blue', 'Bleu'), _o('purple', 'Purple', 'Violet'),
];

final _categories = [
  Category.fromJson({'slug': 'elektronik', 'label': 'Électronique', 'attribute_schema': [
    {'key': 'brand', 'type': 'text', 'label_en': 'Brand', 'label_fr': 'Marque'},
    {'key': 'model', 'type': 'text', 'label_en': 'Model', 'label_fr': 'Modèle'},
    {'key': 'colour', 'type': 'single', 'label_en': 'Colour', 'label_fr': 'Couleur', 'options': _colours},
  ]}),
  Category.fromJson({'slug': 'phones', 'label': 'Téléphones', 'parent_slug': 'elektronik', 'attribute_schema': [
    {'key': 'brand', 'type': 'single', 'label_en': 'Brand', 'label_fr': 'Marque', 'required': true, 'title_part': 1,
     'options': [_o('apple', 'Apple'), _o('samsung', 'Samsung'), _o('tecno', 'Tecno')]},
    {'key': 'model', 'type': 'text', 'label_en': 'Model', 'label_fr': 'Modèle', 'required': true, 'title_part': 1.1},
    {'key': 'storage_gb', 'type': 'single', 'label_en': 'Storage', 'label_fr': 'Stockage', 'required': true,
     'card': 1, 'title_part': 2,
     'options': [_o('128', '128 GB', '128 Go'), _o('256', '256 GB', '256 Go'), _o('512', '512 GB', '512 Go')]},
    {'key': 'battery_health', 'type': 'number', 'label_en': 'Battery health', 'label_fr': 'État de la batterie',
     'min': 50, 'max': 100, 'unit_en': '%', 'unit_fr': '%', 'short_en': 'Batt. {}', 'short_fr': 'Batt. {}', 'card': 2},
    {'key': 'unlocked', 'type': 'single', 'label_en': 'Carrier lock', 'label_fr': 'Opérateur', 'options': [
      {'value': 'unlocked', 'label_en': 'Unlocked, any network', 'label_fr': 'Débloqué tout opérateur',
       'short_en': 'Unlocked', 'short_fr': 'Débloqué'},
      _o('locked', 'Locked to one network', 'Bloqué sur un opérateur'),
    ]},
    {'key': 'accounts_removed', 'type': 'bool', 'label_en': 'Signed out of iCloud / Google', 'label_fr': "Déconnecté d'iCloud / Google"},
    {'key': 'in_box', 'type': 'multi', 'label_en': 'In the box', 'label_fr': 'Dans la boîte', 'display': 'checklist',
     'options': [_o('box', 'Box', 'Boîte'), _o('charger', 'Charger', 'Chargeur')]},
  ]}),
  Category.fromJson({'slug': 'tv-audio', 'label': 'TV', 'parent_slug': 'elektronik', 'attribute_schema': [
    {'key': 'smart', 'type': 'bool', 'label_en': 'Smart TV', 'label_fr': 'Smart TV', 'card': 3,
     'short_en': 'Smart TV', 'short_fr': 'Smart TV'},
    {'key': 'screen_in', 'type': 'number', 'label_en': 'Screen size', 'label_fr': "Taille d'écran",
     'unit_en': '″', 'unit_fr': 'pouces', 'card': 2},
  ]}),
  Category.fromJson({'slug': 'auto-rad', 'label': 'Auto & Moto'}),
  Category.fromJson({'slug': 'cars', 'label': 'Voitures', 'parent_slug': 'auto-rad', 'attribute_schema': [
    {'key': 'make', 'type': 'single', 'label_en': 'Make', 'label_fr': 'Marque', 'required': true, 'title_part': 1,
     'options': [_o('toyota', 'Toyota'), _o('hyundai', 'Hyundai')]},
    {'key': 'model', 'type': 'text', 'label_en': 'Model', 'label_fr': 'Modèle', 'required': true, 'title_part': 1.1},
    {'key': 'year', 'type': 'number', 'label_en': 'Year', 'label_fr': 'Année', 'required': true,
     'min': 1980, 'max': 2027, 'card': 1, 'title_part': 1.2},
    {'key': 'mileage_km', 'type': 'number', 'label_en': 'Mileage', 'label_fr': 'Kilométrage', 'min': 0, 'max': 999999,
     'unit_en': 'km', 'unit_fr': 'km', 'grouped': true, 'card': 2, 'title_part': 2},
    {'key': 'gearbox', 'type': 'single', 'label_en': 'Gearbox', 'label_fr': 'Boîte de vitesses', 'card': 3, 'title_part': 3,
     'options': [_o('manual', 'Manual', 'Manuelle'), _o('automatic', 'Automatic', 'Automatique')]},
    {'key': 'customs', 'type': 'single', 'label_en': 'Customs', 'label_fr': 'Dédouanement', 'required': true,
     'title_part': 4, 'section_en': 'Papers', 'section_fr': 'Papiers', 'options': [
       _o('cleared', 'Customs cleared', 'Dédouanée'), _o('in_progress', 'Clearance in progress', 'Dédouanement en cours'),
     ]},
  ]}),
  Category.fromJson({'slug': 'mode', 'label': 'Mode', 'attribute_schema': [
    {'key': 'brand', 'type': 'text', 'label_en': 'Brand', 'label_fr': 'Marque', 'title_part': 1.1},
    {'key': 'colours', 'type': 'multi', 'label_en': 'Colours available', 'label_fr': 'Couleurs disponibles',
     'card': 2, 'options': _colours},
  ]}),
  Category.fromJson({'slug': 'shoes', 'label': 'Chaussures', 'parent_slug': 'mode', 'attribute_schema': [
    {'key': 'type', 'type': 'single', 'label_en': 'Type', 'label_fr': 'Type', 'title_part': 1,
     'options': [_o('sneakers', 'Sneakers', 'Baskets'), _o('heels', 'Heels', 'Talons')]},
    {'key': 'shoe_sizes_eu', 'type': 'multi', 'label_en': 'Shoe sizes available (EU)', 'label_fr': 'Pointures disponibles (EU)',
     'required': true, 'card': 1, 'title_part': 2,
     'options': [for (var s = 35; s <= 46; s++) _o('$s', '$s')]},
  ]}),
  Category.fromJson({'slug': 'real-estate', 'label': 'Immobilier', 'listing_guide': {
    'condition': false, 'warranty': false, 'delivery': false, 'cta': 'visit'}}),
  Category.fromJson({'slug': 'property-rent', 'label': 'Location', 'parent_slug': 'real-estate',
    'listing_guide': {'price_label_en': 'Rent', 'price_label_fr': 'Loyer', 'price_per_en': 'month', 'price_per_fr': 'mois'},
    'attribute_schema': [
      {'key': 'bedrooms', 'type': 'number', 'label_en': 'Bedrooms', 'label_fr': 'Chambres', 'card': 2,
       'short_en': '{} bed', 'short_fr': '{} ch.'},
      {'key': 'advance_months', 'type': 'number', 'label_en': 'Advance required', 'label_fr': 'Avance exigée',
       'unit_en': 'months', 'unit_fr': 'mois', 'short_en': '{} upfront', 'short_fr': 'Avance {}'},
    ]}),
];

AttrField _field(String slug, String key) => attributeFieldsFor(_categories, slug).firstWhere((f) => f.key == key);

Listing _listing({
  String title = 't',
  String slug = 'phones',
  Map<String, dynamic> attributes = const {},
  String? condition,
  String kind = 'product',
  String priceMode = 'fixed',
  int priceCents = 5000,
}) =>
    Listing(
      id: 'l1',
      sellerId: 's1',
      title: title,
      priceCents: priceCents,
      categorySlug: slug,
      kind: kind,
      priceMode: priceMode,
      attributes: attributes,
      condition: condition,
    );

void main() {
  final fr = lookupAppLocalizations(_fr);
  final en = lookupAppLocalizations(_en);

  group('format', () {
    test('a grouped number reads with dots and its unit, in both languages', () {
      final km = _field('cars', 'mileage_km');
      expect(km.format(145000, _fr, yes: 'Oui'), '145.000${_nb}km');
      expect(km.format(145000, _en, yes: 'Yes'), '145.000${_nb}km');
    });

    test('an ungrouped number stays plain, so a year is 2012', () {
      expect(_field('cars', 'year').format(2012, _fr, yes: 'Oui'), '2012');
      expect(_field('cars', 'year').format('2012', _en, yes: 'Yes'), '2012', reason: 'a string answer still formats');
    });

    test('English writes % against the number; French spaces it, unbreakably', () {
      final batt = _field('phones', 'battery_health');
      expect(batt.format(88, _en, yes: 'Yes'), '88%');
      expect(batt.format(88, _fr, yes: 'Oui'), '88$_nb%');
      final screen = _field('tv-audio', 'screen_in');
      expect(screen.format(55, _en, yes: 'Yes'), '55″');
      expect(screen.format(55, _fr, yes: 'Oui'), '55${_nb}pouces');
    });

    test('a word unit gets a no-break space', () {
      final advance = _field('property-rent', 'advance_months');
      expect(advance.format(3, _fr, yes: 'Oui'), '3${_nb}mois');
      expect(advance.format(3, _en, yes: 'Yes'), '3${_nb}months');
    });

    test('the short pattern wraps the formatted value', () {
      expect(_field('phones', 'battery_health').format(88, _fr, short: true, yes: 'Oui'), 'Batt. 88$_nb%');
      expect(_field('phones', 'battery_health').format(88, _fr, yes: 'Oui'), '88$_nb%', reason: 'long form has no pattern');
      expect(_field('property-rent', 'bedrooms').format(1, _fr, short: true, yes: 'Oui'), '1 ch.');
    });

    test('a true bool reads as its short text; a false one is never shown', () {
      final smart = _field('tv-audio', 'smart');
      expect(smart.format(true, _fr, short: true, yes: 'Oui'), 'Smart TV');
      expect(smart.format(true, _fr, yes: 'Oui'), 'Oui');
      expect(smart.format(false, _fr, short: true, yes: 'Oui'), isNull);
      expect(smart.format(null, _fr, yes: 'Oui'), isNull);
      final signedOut = _field('phones', 'accounts_removed');
      expect(signedOut.format(true, _fr, short: true, yes: 'Oui'), "Déconnecté d'iCloud / Google",
          reason: 'no short text: the label');
    });

    test('a contiguous run of three or more sizes reads as a range', () {
      final sizes = _field('shoes', 'shoe_sizes_eu');
      expect(sizes.format(['38', '39', '40', '41', '42', '43'], _fr, short: true, yes: 'Oui'), '38–43');
      expect(sizes.format(['43', '38', '40', '39', '42', '41'], _fr, short: true, yes: 'Oui'), '38–43',
          reason: 'template order, not answer order');
      expect(sizes.format(['38', '39', '40'], _fr, yes: 'Oui'), '38, 39, 40', reason: 'the long form lists them');
      expect(sizes.format(['38', '40'], _fr, short: true, yes: 'Oui'), '38, 40');
      expect(sizes.format(['38', '40', '42'], _fr, short: true, yes: 'Oui'), '38, 40 +1');
    });

    test('more than two scattered answers read as the first two and a count', () {
      final colours = _field('shoes', 'colours');
      expect(colours.format(['black', 'white', 'red', 'blue'], _fr, short: true, yes: 'Oui'), 'Noir, Blanc +2');
      expect(colours.format(['blue', 'black'], _fr, short: true, yes: 'Oui'), 'Noir, Bleu');
      expect(colours.format(['black', 'white', 'red', 'blue'], _fr, yes: 'Oui'), 'Noir, Blanc, Rouge, Bleu');
      expect(colours.format(const [], _fr, yes: 'Oui'), isNull);
      expect(colours.format(['black', 'gold'], _fr, yes: 'Oui'), 'Noir, gold', reason: 'a dropped option still reads');
    });

    test('an option reads its short label in short form', () {
      final lock = _field('phones', 'unlocked');
      expect(lock.format('unlocked', _fr, short: true, yes: 'Oui'), 'Débloqué');
      expect(lock.format('unlocked', _fr, yes: 'Oui'), 'Débloqué tout opérateur');
      expect(lock.format('locked', _fr, short: true, yes: 'Oui'), 'Bloqué sur un opérateur', reason: 'falls back to the label');
      expect(lock.format('unlocked', _en, short: true, yes: 'Yes'), 'Unlocked');
    });

    test('a multi keeps its full option labels in short form, as the site does', () {
      final multi = AttrField.fromJson({'key': 'network', 'type': 'multi', 'label_en': 'Network', 'label_fr': 'Réseau',
        'options': [
          {'value': 'unlocked', 'label_en': 'Unlocked, any network', 'label_fr': 'Débloqué tout opérateur',
           'short_en': 'Unlocked', 'short_fr': 'Débloqué'},
          _o('mtn', 'MTN'),
        ]})!;
      expect(multi.format(['unlocked', 'mtn'], _fr, short: true, yes: 'Oui'), 'Débloqué tout opérateur, MTN');
    });

    test('text is trimmed and blank is nothing', () {
      expect(_field('phones', 'model').format('  iPhone 13 Pro ', _fr, yes: 'Oui'), 'iPhone 13 Pro');
      expect(_field('phones', 'model').format('   ', _fr, yes: 'Oui'), isNull);
    });
  });

  group('displayFields', () {
    test('checklists move to the end, the rest keep their order', () {
      final keys = displayFields(attributeFieldsFor(_categories, 'phones')).map((f) => f.key).toList();
      expect(keys.last, 'in_box');
      expect(keys.first, 'brand');
      expect(keys.indexOf('colour'), keys.length - 2, reason: 'the root field still comes after the leaf\'s');
    });
  });

  group('specParts', () {
    List<String> parts(Listing x, {bool forCard = true, ListingGuide? guide, AppLocalizations? l10n, Locale l = _fr}) =>
        specParts(x, attributeFieldsFor(_categories, x.categorySlug), guide ?? guideFor(_categories, x.categorySlug),
            l10n ?? fr, l, forCard: forCard);

    const phone = {'storage_gb': '256', 'battery_health': 88, 'colour': 'black'};

    test('a fact the title already states is dropped', () {
      final x = _listing(title: 'iPhone 13 Pro 256 Go', attributes: phone, condition: 'New');
      expect(parts(x), ['Batt. 88$_nb%']);
      expect(parts(_listing(title: 'iPhone 13 Pro 256 Go', attributes: phone, condition: 'Like New')),
          ['Batt. 88$_nb%', 'Comme neuf']);
      expect(parts(_listing(title: 'iPhone 13 Pro', attributes: phone)), ['256 Go', 'Batt. 88$_nb%']);
    });

    test('cars: the year in the title is not repeated', () {
      final x = _listing(title: 'Toyota Corolla 2012', slug: 'cars', attributes: {
        'make': 'toyota', 'model': 'Corolla', 'year': 2012, 'mileage_km': 145000, 'gearbox': 'automatic'});
      expect(parts(x), ['145.000${_nb}km', 'Automatique']);
      expect(parts(x, l10n: en, l: _en), ['145.000${_nb}km', 'Automatic']);
    });

    test('a typed space matches the no-break space a unit carries', () {
      final x = _listing(title: 'Corolla 145.000 km', slug: 'cars', attributes: {'mileage_km': 145000});
      expect(parts(x), isEmpty);
    });

    test('with no answers, only a chosen condition other than New shows on a card', () {
      expect(parts(_listing(condition: 'New')), isEmpty);
      expect(parts(_listing(condition: 'Used')), ['Occasion']);
      expect(parts(_listing(condition: 'Refurbished')), ['Reconditionné']);
      expect(parts(_listing()), isEmpty);
    });

    test('the item page keeps "Neuf", and puts the condition first', () {
      expect(parts(_listing(condition: 'New'), forCard: false), ['Neuf']);
      expect(parts(_listing(title: 'iPhone 13 Pro', attributes: phone, condition: 'New'), forCard: false),
          ['Neuf', '256 Go', 'Batt. 88$_nb%']);
    });

    test('the condition only fits when there is room', () {
      final x = _listing(slug: 'cars', condition: 'Used',
          attributes: {'year': 2012, 'mileage_km': 145000, 'gearbox': 'manual'});
      expect(parts(x), ['2012', '145.000${_nb}km', 'Manuelle']);
    });

    test('no condition where the category or the kind has none', () {
      expect(parts(_listing(slug: 'property-rent', condition: 'New'), forCard: false), isEmpty);
      expect(parts(_listing(condition: 'Used', kind: 'service')), isEmpty);
      expect(parts(_listing(slug: 'property-rent', attributes: {'bedrooms': 1})), ['1 ch.']);
    });

    test('max is respected', () {
      final x = _listing(slug: 'cars', attributes: {'year': 2012, 'mileage_km': 145000, 'gearbox': 'manual'});
      expect(specParts(x, attributeFieldsFor(_categories, 'cars'), ListingGuide.empty, fr, _fr, max: 2),
          ['2012', '145.000${_nb}km']);
    });
  });

  group('suggestTitle', () {
    String? title(String slug, Map<String, dynamic> answers, {Locale l = _fr, int maxLen = 70}) =>
        suggestTitle(answers, attributeFieldsFor(_categories, slug), l, maxLen: maxLen, yes: 'Oui');

    test('make and model join with a space, the rest with " · "', () {
      expect(title('phones', {'brand': 'apple', 'model': 'iPhone 13 Pro', 'storage_gb': '256'}),
          'Apple iPhone 13 Pro · 256 Go');
      expect(title('phones', {'brand': 'apple', 'model': 'iPhone 13 Pro', 'storage_gb': '256'}, l: _en),
          'Apple iPhone 13 Pro · 256 GB');
    });

    test('a part another part contains is dropped', () {
      expect(title('phones', {'brand': 'samsung', 'model': 'Samsung Galaxy A54'}), 'Samsung Galaxy A54');
      expect(title('phones', {'brand': 'samsung', 'model': 'samsung galaxy a54', 'storage_gb': '128'}),
          'samsung galaxy a54 · 128 Go');
    });

    test('cars read make, model and year, then the facts', () {
      final t = title('cars', {'make': 'toyota', 'model': 'Corolla', 'year': 2012, 'mileage_km': 145000,
        'gearbox': 'automatic', 'customs': 'cleared'});
      expect(t, 'Toyota Corolla 2012 · 145.000${_nb}km · Automatique · Dédouanée');
      expect(t!.length, 58);
    });

    test('an answer pushing it past the limit drops the last group', () {
      final t = title('cars', {'make': 'toyota', 'model': 'Corolla Verso Executive', 'year': 2012,
        'mileage_km': 145000, 'gearbox': 'automatic', 'customs': 'cleared'});
      expect(t, 'Toyota Corolla Verso Executive 2012 · 145.000${_nb}km · Automatique');
      expect(t!.length, lessThanOrEqualTo(70));
    });

    test('nothing to suggest from a single answer', () {
      expect(title('cars', {'make': 'toyota'}), isNull);
      expect(title('cars', const {}), isNull);
      expect(title('elektronik', {'brand': 'Sony', 'model': 'X90'}), isNull, reason: 'no title parts on the root');
    });

    test('nothing when even the first group is too long', () {
      expect(title('phones', {'brand': 'apple', 'model': 'iPhone 13 Pro', 'storage_gb': '256'}, maxLen: 10), isNull);
    });
  });

  group('priceLine', () {
    final none = ListingGuide.empty;
    final rent = guideFor(_categories, 'property-rent');
    ({String main, String? tail, bool negotiableChip}) line(String mode, int cents,
            {ListingGuide? g, bool compact = false, AppLocalizations? l10n}) =>
        priceLine(_listing(priceMode: mode, priceCents: cents), g ?? none, l10n ?? fr, compact: compact);

    test('fixed is the amount, with the guide\'s per-unit suffix', () {
      expect(line('fixed', 5000).main, '5.000 FCFA');
      expect(line('fixed', 75000, g: rent).main, '75.000 FCFA / mois');
      expect(line('fixed', 75000, g: rent, l10n: en).main, '75.000 FCFA / month');
      expect(line('fixed', 75000, g: rent, compact: true).main, '75.000 FCFA / mois');
      expect(line('fixed', 5000).tail, isNull);
      expect(line('fixed', 5000).negotiableChip, isFalse);
    });

    test('from reads in full on the item page and short on a card', () {
      expect(line('from', 18000).main, 'À partir de 18.000 FCFA');
      expect(line('from', 18000, compact: true).main, 'Dès 18.000 FCFA');
      expect(line('from', 18000, compact: true, l10n: en).main, 'From 18.000 FCFA');
      expect(line('from', 75000, g: rent, compact: true).main, 'Dès 75.000 FCFA / mois');
    });

    test('negotiable with an amount: a chip on the item page, a tail on a card', () {
      final detail = line('negotiable', 50000);
      expect(detail.main, '50.000 FCFA');
      expect(detail.negotiableChip, isTrue);
      expect(detail.tail, isNull);
      final card = line('negotiable', 50000, compact: true);
      expect(card.main, '50.000 FCFA');
      expect(card.tail, 'nég.');
      expect(card.negotiableChip, isFalse);
      expect(line('negotiable', 50000, compact: true, l10n: en).tail, 'neg.');
    });

    test('negotiable without an amount, on request and free never show 0', () {
      expect(line('negotiable', 0).main, 'Prix à négocier');
      expect(line('negotiable', 0, compact: true).main, 'Prix à négocier');
      expect(line('negotiable', 0).negotiableChip, isFalse);
      expect(line('on_request', 0).main, fr.priceOnRequest);
      expect(line('free', 0).main, 'Gratuit');
      expect(line('free', 0, g: rent).main, 'Gratuit', reason: 'no suffix on an amount-less price');
    });

    test('hourly and daily keep their own suffix', () {
      expect(line('hourly', 5000).main, '5.000 FCFA/h');
      expect(line('daily', 5000).main, '5.000 FCFA/jour');
      expect(line('daily', 5000, l10n: en).main, '5.000 FCFA/day');
    });
  });

  group('conditionLabel', () {
    test('the four stored values translate; anything else is nothing', () {
      expect(conditionLabel(fr, 'New'), 'Neuf');
      expect(conditionLabel(fr, 'Like New'), 'Comme neuf');
      expect(conditionLabel(fr, 'Used'), 'Occasion');
      expect(conditionLabel(fr, 'Refurbished'), 'Reconditionné');
      expect(conditionLabel(en, 'Used'), 'Used');
      expect(conditionLabel(fr, null), isNull);
      expect(conditionLabel(fr, 'mint'), isNull);
    });
  });
}
