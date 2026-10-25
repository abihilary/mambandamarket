// Category guides (0066): how a root's guide and a leaf's combine, and that a
// guide the app did not expect costs a hint, never a crash.
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:mambandamarket/api/listing_guide.dart';
import 'package:mambandamarket/api/models.dart';

const _fr = Locale('fr');
const _en = Locale('en');

void main() {
  final realEstate = <String, dynamic>{
    'condition': false,
    'warranty': false,
    'delivery': false,
    'cta': 'visit',
    'photo_tips': [
      {'en': 'Front or entrance', 'fr': 'Façade ou entrée'},
      {'en': 'Living room', 'fr': 'Salon'},
    ],
    'photo_min': 5,
    'describe_prompts': [
      {'en': 'Landmark?', 'fr': 'Repère ?', 'starter_en': 'Landmark: ', 'starter_fr': 'Repère : '},
    ],
    'buyer_tips': [
      {'en': 'Pay nothing before you have visited.', 'fr': "Ne payez rien avant d'avoir visité."},
    ],
  };
  final propertyRent = <String, dynamic>{
    'price_label_en': 'Rent',
    'price_label_fr': 'Loyer',
    'price_per_en': 'month',
    'price_per_fr': 'mois',
    'photo_tips': [
      {'en': 'Shower', 'fr': 'Douche'},
    ],
  };

  test('the leaf wins per top-level key; the root fills the rest', () {
    final g = ListingGuide.resolve(realEstate, propertyRent);
    expect(g.priceLabel(_fr), 'Loyer');
    expect(g.pricePer(_fr), 'mois');
    expect(g.pricePer(_en), 'month');
    expect(g.cta, 'visit');
    expect(g.condition, isFalse);
    expect(g.warranty, isFalse);
    expect(g.delivery, isFalse);
    expect(g.photoMin, 5);
    expect(g.buyerTips.single.text(_fr), "Ne payez rien avant d'avoir visité.");

    final overridden = ListingGuide.resolve({'cta': 'visit', 'condition': false}, {'cta': 'quote', 'condition': true});
    expect(overridden.cta, 'quote');
    expect(overridden.condition, isTrue);
  });

  test('a leaf list replaces the root list rather than adding to it', () {
    final g = ListingGuide.resolve(realEstate, propertyRent);
    expect(g.photoTips.map((t) => t.text(_fr)), ['Douche']);
    expect(ListingGuide.resolve(realEstate, null).photoTips.map((t) => t.text(_en)), ['Front or entrance', 'Living room']);
  });

  test('unknown keys are ignored', () {
    final g = ListingGuide.fromJson({'banana': 1, 'month_picker': {'x': 1}, 'photo_min': 4});
    expect(g.photoMin, 4);
    expect(g.condition, isTrue);
  });

  test('wrong types are tolerated, never thrown on', () {
    final g = ListingGuide.fromJson({
      'title_example_en': 3,
      'photo_tips': 'take some photos',
      'photo_min': 'four',
      'describe_prompts': [42, {'en': ''}, {'fr': 'Des défauts ?', 'starter_fr': 'Défauts : '}],
      'buyer_tips': [1, null, {'en': 'Meet in public.'}, 'Plain text tip'],
      'price_modes': 'free',
      'condition': 'no',
      'warranty': 'false',
      'delivery': null,
      'cta': 5,
    });
    expect(g.titleExample(_en), isNull);
    expect(g.photoTips, isEmpty);
    expect(g.photoMin, isNull);
    expect(g.priceModes, isNull);
    expect(g.condition, isTrue, reason: 'only an explicit false switches it off');
    expect(g.warranty, isFalse);
    expect(g.delivery, isTrue);
    expect(g.cta, isNull);
    expect(g.buyerTips.map((t) => t.text(_fr)), ['Meet in public.', 'Plain text tip'],
        reason: 'a tip in one language beats no tip');
    final prompt = g.describePrompts.single;
    expect(prompt.label(_fr), 'Des défauts ?');
    expect(prompt.label(_en), 'Des défauts ?');
    expect(prompt.starter(_fr), 'Défauts : ', reason: 'the trailing space puts the cursor after the colon');

    expect(ListingGuide.fromJson({'cta': 'call_me'}).cta, isNull);
    expect(ListingGuide.fromJson({'price_modes': ['free', 3]}).priceModes, ['free']);
    expect(ListingGuide.fromJson({'price_modes': []}).priceModes, isNull);
  });

  test('no guide reads as the empty guide: everything on, nothing suggested', () {
    for (final g in [ListingGuide.fromJson(null), ListingGuide.fromJson({}), ListingGuide.resolve(null, null)]) {
      expect(g.condition, isTrue);
      expect(g.warranty, isTrue);
      expect(g.delivery, isTrue);
      expect(g.cta, isNull);
      expect(g.photoTips, isEmpty);
      expect(g.buyerTips, isEmpty);
      expect(g.describePrompts, isEmpty);
      expect(g.pricePer(_fr), isNull);
      expect(g.priceModes, isNull);
    }
    expect(identical(ListingGuide.fromJson(null), ListingGuide.empty), isTrue);
  });

  test('a category resolves its guide through its group', () {
    final cats = [
      Category.fromJson({'slug': 'real-estate', 'label': 'Immobilier', 'listing_guide': realEstate}),
      Category.fromJson({'slug': 'property-rent', 'label': 'Location', 'parent_slug': 'real-estate', 'listing_guide': propertyRent}),
      Category.fromJson({'slug': 'land', 'label': 'Terrains', 'parent_slug': 'real-estate'}),
      Category.fromJson({'slug': 'mode', 'label': 'Mode', 'listing_guide': 'not a map'}),
    ];
    expect(cats.first.listingGuideRaw?['cta'], 'visit');
    expect(guideFor(cats, 'property-rent').pricePer(_fr), 'mois');
    expect(guideFor(cats, 'property-rent').condition, isFalse);
    expect(guideFor(cats, 'land').delivery, isFalse, reason: 'a leaf with no guide inherits its group\'s');
    expect(guideFor(cats, 'real-estate').cta, 'visit');
    expect(cats.last.listingGuideRaw, isNull);
    expect(identical(guideFor(cats, 'mode'), ListingGuide.empty), isTrue);
    expect(identical(guideFor(cats, 'nope'), ListingGuide.empty), isTrue);
    expect(identical(guideFor(cats, null), ListingGuide.empty), isTrue);
  });
}
