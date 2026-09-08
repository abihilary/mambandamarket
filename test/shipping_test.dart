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
