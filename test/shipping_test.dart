import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:mambandamarket/api/shipping_draft.dart';
import 'package:mambandamarket/api/shipping_model.dart';
import 'package:mambandamarket/api/location_share.dart';

Map<String, dynamic> catalogue() => {
      'enabled': true,
      'sizes': <String, dynamic>{
        'envelope': {'label_en': 'Envelope', 'label_fr': 'Enveloppe', 'kg_min': 0, 'kg_max': 0.5},
        'small_box': {
          'label_en': 'Small box',
          'label_fr': 'Petit carton',
          'hint_en': 'A shoebox',
          'hint_fr': 'Une boîte à chaussures',
          'kg_min': 0.5,
          'kg_max': 5,
        },
        'tv_flat': {'label_en': 'Flat-screen TV', 'label_fr': 'Téléviseur', 'kg_min': 8, 'kg_max': 35},
        'custom': {'label_en': 'Something else', 'label_fr': 'Autre chose', 'kg_min': null, 'kg_max': null},
      },
      'default': ['envelope', 'small_box'],
      // Deliberately <String, dynamic>: the tests below put a non-list in here
      // to check the parser survives it, which is exactly what a hand-edited
      // catalogue in the dashboard could contain.
      'by_category': <String, dynamic>{
        'elektronik': ['tv_flat', 'small_box'],
      },
      'from_locations': [
        {'code': 'cn', 'label_en': 'China', 'label_fr': 'Chine'},
      ],
      'to_locations': [
        {'code': 'douala', 'label_en': 'Douala', 'label_fr': 'Douala'},
      ],
    };

void main() {
  _embedShapeTests();
  _rateCardTests();
  _locationShareTests();
  const en = Locale('en');
  const fr = Locale('fr');

  group('catalogue', () {
    test('parses', () {
      final o = ShippingOptions.fromJson(catalogue());
      expect(o.enabled, isTrue);
      expect(o.isUsable, isTrue);
      expect(o.sizes.length, 4);
      expect(o.from.single.labelFor(fr), 'Chine');
      expect(o.custom, isNotNull);
    });

    test('a category with its own sizes gets them', () {
      final o = ShippingOptions.fromJson(catalogue());
      expect(o.sizesFor('elektronik').map((s) => s.code), ['tv_flat', 'small_box']);
    });

    test('a leaf falls back to its parent, then to the default ladder', () {
      // Operations key most of the catalogue on roots — there are eighty-eight
      // categories and only a handful genuinely differ — so this step is what
      // makes a leaf work at all.
      final o = ShippingOptions.fromJson(catalogue());
      expect(o.sizesFor('phones', parentSlug: 'elektronik').map((s) => s.code),
          ['tv_flat', 'small_box']);
      expect(o.sizesFor('mode', parentSlug: 'nothing-known').map((s) => s.code),
          ['envelope', 'small_box']);
      expect(o.sizesFor(null).map((s) => s.code), ['envelope', 'small_box']);
    });

    test('a size named by a category but missing from sizes is dropped, not blank', () {
      final json = catalogue();
      (json['by_category'] as Map)['mode'] = ['small_box', 'ghost_size'];
      final o = ShippingOptions.fromJson(json);
      expect(o.sizesFor('mode').map((s) => s.code), ['small_box']);
    });

    test('a category whose value is not a list is one category with no overrides', () {
      final json = catalogue();
      (json['by_category'] as Map)['broken'] = 'small_box';
      final o = ShippingOptions.fromJson(json);
      expect(o.sizesFor('broken').map((s) => s.code), ['envelope', 'small_box']);
      expect(o.sizes.length, 4);
    });

    test('a size with no label at all is not offered', () {
      final json = catalogue();
      (json['sizes'] as Map)['nameless'] = {'kg_min': 1};
      expect(ShippingOptions.fromJson(json).sizes.containsKey('nameless'), isFalse);
    });

    test('a label missing French still renders in French', () {
      final json = catalogue();
      (json['sizes'] as Map)['envelope'] = {'label_en': 'Envelope'};
      final size = ShippingOptions.fromJson(json).sizes['envelope']!;
      expect(size.labelFor(fr), 'Envelope');
      expect(size.labelFor(en), 'Envelope');
    });

    test('nothing at all is a disabled, unusable catalogue rather than a crash', () {
      for (final json in [null, <String, dynamic>{}, {'sizes': 'not a map'}]) {
        final o = ShippingOptions.fromJson(json as Map<String, dynamic>?);
        expect(o.enabled, isFalse);
        expect(o.isUsable, isFalse);
        expect(o.sizesFor('elektronik'), isEmpty);
      }
    });

    test('hints come through, because "medium box" alone means nothing', () {
      final o = ShippingOptions.fromJson(catalogue());
      expect(o.sizes['small_box']!.hintFor(en), 'A shoebox');
      expect(o.sizes['small_box']!.hintFor(fr), 'Une boîte à chaussures');
      expect(o.sizes['envelope']!.hintFor(en), isNull);
    });
  });

  group('what the form still needs', () {
    ShippingDraft filled({
      ShippingSource? source = ShippingSource.external,
      String url = '',
      String description = 'a washing machine',
      String category = 'elektronik',
      String size = 'tv_flat',
      String sizeCustom = '',
      String estimatedValue = '1000',
      bool hasPresets = true,
      String from = 'cn',
      String to = 'douala',
      String phone = '+237600000000',
    }) =>
        ShippingDraft(
          source: source,
          productUrl: url,
          description: description,
          categorySlug: category,
          sizeCode: size,
          sizeCustom: sizeCustom,
          estimatedValue: estimatedValue,
          categoryHasPresets: hasPresets,
          fromLocation: from,
          toLocation: to,
          contactPhone: phone,
        );

    test('a complete external request is ready', () {
      expect(filled().missing, isEmpty);
      expect(filled().isReady, isTrue);
    });

    test('nothing is asked for until a path is chosen', () {
      // The chooser owns the screen first; listing ten missing fields under it
      // would be shouting at somebody who has not started.
      expect(const ShippingDraft().missing, [ShippingField.source]);
    });

    test('a link is enough on its own, and so is a description', () {
      expect(filled(description: '', url: 'https://example.test/thing').missing, isEmpty);
      expect(filled(description: 'a thing', url: '').missing, isEmpty);
      expect(filled(description: '', url: '').missing, contains(ShippingField.item));
      expect(filled(description: '   ', url: '  ').missing, contains(ShippingField.item));
    });

    test('the Mambanda path wants a product and nothing about the item', () {
      final d = filled(source: ShippingSource.mambanda, description: '', url: '');
      expect(d.missing, contains(ShippingField.item));
    });

    test('size is required only when the category actually has presets', () {
      expect(filled(size: '').missing, contains(ShippingField.size));
      // A catalogue we could not load must never be a wall.
      expect(filled(size: '', hasPresets: false).missing, isNot(contains(ShippingField.size)));
      expect(filled(size: '', hasPresets: false).isReady, isTrue);
    });

    test('choosing "something else" and saying nothing is choosing nothing', () {
      expect(filled(size: ShippingDraft.customSize, sizeCustom: '').missing,
          contains(ShippingField.sizeCustom));
      expect(filled(size: ShippingDraft.customSize, sizeCustom: 'a bathtub').missing, isEmpty);
    });

    test('the route and a phone number are always required', () {
      expect(filled(from: '').missing, contains(ShippingField.from));
      expect(filled(to: '').missing, contains(ShippingField.to));
      expect(filled(phone: '123').missing, contains(ShippingField.phone));
    });

    test('missing fields come back in the order they appear on screen', () {
      final d = filled(description: '', url: '', category: '', size: '', from: '', to: '', phone: '');
      expect(d.missing, [
        ShippingField.item,
        ShippingField.category,
        ShippingField.size,
        ShippingField.from,
        ShippingField.to,
        ShippingField.phone,
      ]);
    });
  });
}

void _locationShareTests() {
  group('location shares', () {
    Map<String, dynamic> base(Map<String, dynamic> over) => <String, dynamic>{
          'id': 's1',
          'conversation_id': 'c1',
          'sender_id': 'u1',
          'mode': 'live',
          'lat': 4.05,
          'lng': 9.7,
          ...over,
        };

    test('a share with no position is dropped, not drawn on Null Island', () {
      expect(LocationShare.fromJson(base({'lat': null})), isNull);
      expect(LocationShare.fromJson(base({'id': ''})), isNull);
      expect(LocationShare.fromJson(null), isNull);
    });

    test('a pin is never running', () {
      final pin = LocationShare.fromJson(base({'mode': 'pin', 'expires_at': null}))!;
      expect(pin.isLive, isFalse);
      expect(pin.isRunning, isFalse);
      expect(pin.hasExpired, isFalse);
    });

    test('a live share runs only inside its window', () {
      final future = DateTime.now().add(const Duration(minutes: 30)).toIso8601String();
      final past = DateTime.now().subtract(const Duration(minutes: 1)).toIso8601String();
      expect(LocationShare.fromJson(base({'expires_at': future}))!.isRunning, isTrue);
      expect(LocationShare.fromJson(base({'expires_at': past}))!.isRunning, isFalse);
    });

    test('stopped and expired are told apart', () {
      final future = DateTime.now().add(const Duration(minutes: 30)).toIso8601String();
      final past = DateTime.now().subtract(const Duration(minutes: 1)).toIso8601String();

      final stopped = LocationShare.fromJson(
          base({'expires_at': future, 'stopped_at': DateTime.now().toIso8601String()}))!;
      expect(stopped.isRunning, isFalse);
      // It did not run out — somebody ended it, and the bubble says so.
      expect(stopped.hasExpired, isFalse);

      final expired = LocationShare.fromJson(base({'expires_at': past}))!;
      expect(expired.hasExpired, isTrue);
    });

    test('a live share with no expiry cannot run', () {
      // The table refuses to store one, so this only happens if something
      // upstream changes. It must fail closed rather than broadcast forever.
      expect(LocationShare.fromJson(base({'expires_at': null}))!.isRunning, isFalse);
    });

    test('the map link carries the point', () {
      final s = LocationShare.fromJson(base({'expires_at': null, 'mode': 'pin'}))!;
      expect(s.mapUri.toString(), contains('4.05,9.7'));
      expect(s.webMapUri.toString(), contains('query=4.05,9.7'));
    });
  });
}

void _rateCardTests() {
  group('rate card', () {
    test('a catalogue without tiers still parses as before', () {
      final o = ShippingOptions.fromJson(<String, dynamic>{
        'enabled': true,
        'sizes': {'custom': {'label_en': 'Other', 'label_fr': 'Autre', 'kg_min': null, 'kg_max': null}},
        'default': ['custom'],
        'by_category': <String, dynamic>{},
        'from_locations': [{'code': 'a', 'label_en': 'A', 'label_fr': 'A'}],
        'to_locations': [{'code': 'b', 'label_en': 'B', 'label_fr': 'B', 'zone': 'z'}],
      });
      expect(o.tiers, isEmpty);
      expect(o.currency, 'XAF');
      expect(o.from.single.zone, isNull);
      expect(o.from.single.isPriced, isFalse);
      expect(o.to.single.zone, 'z');
    });

    test('tiers and bands parse', () {
      final o = ShippingOptions.fromJson(<String, dynamic>{
        'sizes': {
          'custom': {'label_en': 'Other', 'label_fr': 'Autre', 'kg_min': null, 'kg_max': null},
          'small_box': {'label_en': 'Small', 'label_fr': 'Petit', 'kg_min': 0, 'kg_max': 2, 'band': 's'},
        },
        'default': ['small_box'],
        'by_category': <String, dynamic>{},
        'from_locations': [{'code': 'a', 'label_en': 'A', 'label_fr': 'A'}],
        'to_locations': [{'code': 'b', 'label_en': 'B', 'label_fr': 'B'}],
        'tiers': [
          {'code': 'standard', 'label_en': 'Standard', 'label_fr': 'Standard', 'eta_days_min': 1, 'eta_days_max': 2},
          {'code': 'bad'},
        ],
      });
      expect(o.sizes['small_box']!.band, 's');
      expect(o.tiers.map((t) => t.code), ['standard']);
      expect(o.tier('standard')!.etaDaysMax, 2);
      expect(o.tier('nope'), isNull);
    });
  });

  group('quote', () {
    test('quotable with options, cheapest first on a tie', () {
      final q = ShippingQuote.fromJson(<String, dynamic>{
        'quotable': true,
        'currency': 'XAF',
        'options': [
          {'tier': 'express', 'label_en': 'Express', 'price_cents': 4500, 'eta_days_min': 0, 'eta_days_max': 0},
          {'tier': 'standard', 'label_en': 'Standard', 'price_cents': 2500, 'eta_days_min': 1, 'eta_days_max': 2},
          {'tier': 'economy', 'label_en': 'Economy', 'price_cents': 2500, 'eta_days_min': 3, 'eta_days_max': 5},
        ],
      });
      expect(q.quotable, isTrue);
      expect(q.options.length, 3);
      expect(q.cheapest!.tier, 'standard');
    });

    test('not quotable carries its reason and no options', () {
      final q = ShippingQuote.fromJson(<String, dynamic>{'quotable': false, 'reason': 'no_rate', 'options': []});
      expect(q.quotable, isFalse);
      expect(q.reason, 'no_rate');
      expect(q.cheapest, isNull);
    });

    test('quotable with nothing to choose is not quotable', () {
      final q = ShippingQuote.fromJson(<String, dynamic>{'quotable': true, 'options': []});
      expect(q.quotable, isFalse);
    });

    test('an option without a price is dropped', () {
      final q = ShippingQuote.fromJson(<String, dynamic>{
        'quotable': true,
        'options': [{'tier': 'x'}, {'tier': 'y', 'price_cents': 100}],
      });
      expect(q.options.map((o) => o.tier), ['y']);
    });

    test('null is not quotable', () {
      expect(ShippingQuote.fromJson(null).quotable, isFalse);
      expect(ShippingQuote.manual.quotable, isFalse);
    });
  });

  group('documents', () {
    test('parse in order; one without a url is dropped', () {
      final items = [
        {'kind': 'confirmation', 'number': 'MB-10023-C', 'url': 'https://x/y.pdf', 'created_at': '2026-09-09T10:00:00Z'},
        {'kind': 'receipt', 'number': 'MB-10023-R', 'url': null},
      ].map((m) => ShippingDocument.fromJson(m)).whereType<ShippingDocument>().toList();
      expect(items.length, 1);
      expect(items.single.isReceipt, isFalse);
      expect(items.single.number, 'MB-10023-C');
    });
  });

  group('request fields', () {
    Map<String, dynamic> row(Map<String, dynamic> over) => <String, dynamic>{
          'id': 'r1',
          'status': 'accepted',
          'reference': 'MB-10023',
          'tier': 'standard',
          'eta_days_min': 1,
          'eta_days_max': 2,
          'quoted_total_cents': 2500,
          'currency': 'XAF',
          'accepted_at': '2026-09-09T10:00:00Z',
          'created_at': '2026-09-09T09:00:00Z',
          ...over,
        };

    test('everything new is parsed', () {
      final r = ShippingRequest.fromJson(row({
        'collected_cents': 3000,
        'delivered_at': '2026-09-10T10:00:00Z',
        'paid_at': '2026-09-10T10:00:00Z',
        'from_place': 'douala-akwa',
        'to_place': 'douala-bonaberi',
        'pickup_address': 'Shop',
        'contact_phone': '+237',
        'locale': 'fr',
      }))!;
      expect(r.reference, 'MB-10023');
      expect(r.displayRef, '#MB-10023');
      expect(r.tier, 'standard');
      expect(r.etaDaysMax, 2);
      expect(r.collectedCents, 3000);
      // What was taken beats what was quoted.
      expect(r.codCents, 3000);
      expect(r.deliveredAt, isNotNull);
      expect(r.fromPlace, 'douala-akwa');
      expect(r.locale, 'fr');
    });

    test('cod falls back to the quote', () {
      expect(ShippingRequest.fromJson(row({}))!.codCents, 2500);
    });

    test('a pending quote is one that is quoted and not yet expired', () {
      final future = DateTime.now().add(const Duration(days: 1)).toIso8601String();
      final past = DateTime.now().subtract(const Duration(days: 1)).toIso8601String();
      expect(ShippingRequest.fromJson(row({'status': 'quoted', 'quote_expires_at': future}))!.isQuotePending, isTrue);
      expect(ShippingRequest.fromJson(row({'status': 'quoted', 'quote_expires_at': past}))!.isQuotePending, isFalse);
      expect(ShippingRequest.fromJson(row({'status': 'accepted', 'quote_expires_at': future}))!.isQuotePending, isFalse);
    });

    test('no reference reads as nothing, not "#null"', () {
      expect(ShippingRequest.fromJson(row({'reference': null}))!.displayRef, '');
    });
  });

  group('eta window', () {
    final base = DateTime.utc(2026, 9, 9, 10);
    ShippingRequest r({int? min = 2, int? max = 3, DateTime? accepted}) => ShippingRequest(
          id: 'r',
          status: 'accepted',
          source: 'external',
          etaDaysMin: min,
          etaDaysMax: max,
          acceptedAt: accepted ?? base,
          createdAt: base.subtract(const Duration(hours: 1)),
        );

    test('counted from acceptance', () {
      final w = r().eta(now: base)!;
      expect(w.kind, EtaKind.range);
      expect(w.minDays, 2);
      expect(w.maxDays, 3);
    });

    test('shrinks as days pass', () {
      final w = r().eta(now: base.add(const Duration(days: 2, hours: 12)))!;
      expect(w.kind, EtaKind.range);
      expect(w.minDays, 0);
      expect(w.maxDays, 1);
    });

    test('today when the latest day is this one', () {
      expect(r().eta(now: base.add(const Duration(days: 2, hours: 23)))!.kind, EtaKind.today);
    });

    test('late a day after the latest', () {
      expect(r().eta(now: base.add(const Duration(days: 4, hours: 1)))!.kind, EtaKind.late);
    });

    test('same-day tier on the day is today', () {
      expect(r(min: 0, max: 0).eta(now: base.add(const Duration(hours: 5)))!.kind, EtaKind.today);
    });

    test('no eta is no window', () {
      expect(r(min: null, max: null).eta(now: base), isNull);
    });

    test('falls back to creation when nothing was accepted', () {
      final w = ShippingRequest(
        id: 'r', status: 'new', source: 'external', etaDaysMin: 1, etaDaysMax: 1, createdAt: base,
      ).eta(now: base)!;
      expect(w.maxDays, 1);
    });
  });

  group('steps', () {
    test('every field belongs to exactly one step', () {
      final all = stepFields.values.expand((f) => f).toList();
      expect(all.toSet(), ShippingField.values.toSet());
      expect(all.length, ShippingField.values.length, reason: 'a field in two steps');
    });

    test('the route step wants the route and nothing else', () {
      const d = ShippingDraft(source: ShippingSource.external);
      expect(d.missingIn(ShippingStep.route), [ShippingField.from, ShippingField.to]);
      expect(d.missingIn(ShippingStep.quote), isEmpty);
      expect(d.isStepReady(ShippingStep.quote), isTrue);
    });

    test('a description alone lets the item step continue', () {
      const d = ShippingDraft(
        source: ShippingSource.external,
        description: 'a box of books',
        categorySlug: 'books',
        sizeCode: 'small_box',
        categoryHasPresets: true,
      );
      expect(d.isStepReady(ShippingStep.item), isTrue);
      expect(d.isStepReady(ShippingStep.confirm), isFalse);
    });
  });
}

void _embedShapeTests() {
  group('conversation embed', () {
    test('an object embed parses', () {
      final r = ShippingRequest.fromJson(<String, dynamic>{
        'id': 'r', 'status': 'new', 'conversation': {'id': 'c1', 'buyer_unread': 2},
      })!;
      expect(r.conversationId, 'c1');
      expect(r.unread, 2);
    });
    test('a one-element array embed (pre-constraint rows, cached payloads) parses', () {
      final r = ShippingRequest.fromJson(<String, dynamic>{
        'id': 'r', 'status': 'new', 'conversation': [{'id': 'c1', 'buyer_unread': 1}],
      })!;
      expect(r.conversationId, 'c1');
    });
    test('no thread is no thread', () {
      expect(ShippingRequest.fromJson(<String, dynamic>{'id': 'r', 'status': 'new', 'conversation': []})!.conversationId, isNull);
    });
  });
}
