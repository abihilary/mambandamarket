import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:mambandamarket/api/board_media_cache.dart';
import 'package:mambandamarket/api/board_model.dart';

/// A board with one image slide, plus whatever the caller wants to add.
Map<String, dynamic> boardJson({
  List<Map<String, dynamic>>? actions,
  Map<String, dynamic>? modals,
  String template = 'hero',
  String path = 'uuid-a/pic.webp',
}) =>
    {
      'version': 1,
      'template': template,
      'style': const {'aspect': '16:9'},
      if (modals != null) 'modals': modals,
      'slides': [
        {
          'type': 'image',
          'path': path,
          'url': 'https://example.test/$path',
          if (actions != null) 'actions': actions,
        },
      ],
    };

Map<String, dynamic> action(Map<String, dynamic> link, {String label = 'Go'}) =>
    {
      'label': {'en': label},
      'link': link,
    };

void main() {
  const locale = Locale('en');

  group('back-compatibility', () {
    test('the board live in production today still parses the same', () {
      // Copied from GET /boards/home on 8 Sep 2026. If this stops parsing, the
      // banner disappears for everybody.
      final board = Board.fromJson({
        'version': 7,
        'template': 'carousel',
        'style': {'aspect': '21:9', 'radius': 3, 'intervalMs': 30000, 'showDots': false},
        'slides': [
          {
            'type': 'image',
            'path': 'b377726e/photo-1.webp',
            'alt': {'en': 'Welcome', 'fr': 'Alt'},
            'link': {'kind': 'none'},
            'url': 'https://example.test/photo-1.webp',
          },
          {
            'type': 'image',
            'path': '37b442ca/photo-2.webp',
            'alt': {'en': 'Welcome', 'fr': 'Bienvenue'},
            'link': {'kind': 'none'},
            'url': 'https://example.test/photo-2.webp',
          },
        ],
      });

      expect(board, isNotNull);
      expect(board!.template, 'carousel');
      expect(board.slides.length, 2);
      expect(board.style.aspect, closeTo(21 / 9, 0.001));
      expect(board.style.radius, 3);
      expect(board.style.interval, const Duration(seconds: 30));
      expect(board.style.showDots, isFalse);
      // Fields that did not exist when it was written take their defaults.
      expect(board.style.scrim, isTrue);
      expect(board.slides.first.actions, isEmpty);
      expect(board.promos, isEmpty);
    });
  });

  group('buttons', () {
    test('a button with a working link is kept', () {
      final board = Board.fromJson(boardJson(actions: [
        action(const {'kind': 'category', 'value': 'mode'}, label: 'Shop'),
      ]));
      expect(board!.slides.first.actions.single.label['en'], 'Shop');
    });

    test('a button with no words in any language is dropped', () {
      final board = Board.fromJson(boardJson(actions: [
        {
          'label': const {'en': ''},
          'link': const {'kind': 'category', 'value': 'mode'},
        },
      ]));
      expect(board!.slides.first.actions, isEmpty);
    });

    test('a button whose link kind this build has never heard of is dropped', () {
      final board = Board.fromJson(boardJson(actions: [
        action(const {'kind': 'teleport', 'value': 'anywhere'}),
      ]));
      expect(board!.slides.first.actions, isEmpty);
      // The slide itself still renders — one bad button is not a lost slide.
      expect(board.slides.length, 1);
    });

    test('no more than three buttons survive a config that asks for more', () {
      final board = Board.fromJson(boardJson(actions: [
        for (var i = 0; i < 6; i++)
          action(const {'kind': 'category', 'value': 'mode'}, label: 'B$i'),
      ]));
      expect(board!.slides.first.actions.length, 3);
    });
  });

  group('promos', () {
    test('a promo link resolves to the promo the board defines', () {
      final board = Board.fromJson(boardJson(
        actions: [action(const {'kind': 'promo', 'value': 'sale'})],
        modals: {
          'sale': {
            'title': const {'en': 'Free delivery'},
            'body': const {'en': 'This week only.'},
          },
        },
      ));
      final link = board!.slides.first.actions.single.link;
      expect(link.kind, BoardLinkKind.promo);
      expect(link.promo, isNotNull);
      expect(link.promo!.title['en'], 'Free delivery');
      expect(link.isActionable, isTrue);
    });

    test('a promo link naming a promo that is not there is dropped', () {
      final board = Board.fromJson(boardJson(
        actions: [action(const {'kind': 'promo', 'value': 'sale'})],
        modals: {
          'other': {
            'title': const {'en': 'Something else'},
          },
        },
      ));
      // A button that opens nothing looks like a broken app; no button just
      // looks like the promotion ended.
      expect(board!.slides.first.actions, isEmpty);
    });

    test('a promo with no words at all is not defined', () {
      final board = Board.fromJson(boardJson(modals: {
        'empty': const {'image': 'uuid-b/pic.webp'},
      }));
      expect(board!.promos, isEmpty);
    });
  });

  group('screen links', () {
    test('a route this build has is actionable', () {
      final link = BoardLink.fromJson(const {'kind': 'screen', 'value': '/my-orders'});
      expect(link!.isActionable, isTrue);
    });

    test('a route outside the allowlist is never actionable', () {
      // onGenerateRoute falls through to SplashScreen, which re-roots the
      // navigator: an unrecognised route would eject the user, not do nothing.
      for (final route in ['/admin', '/', '/home', '/login', 'my-orders']) {
        final link = BoardLink.fromJson({'kind': 'screen', 'value': route});
        expect(link!.isActionable, isFalse, reason: route);
      }
    });

    test('a screen button with an unknown route is dropped from the slide', () {
      final board = Board.fromJson(boardJson(actions: [
        action(const {'kind': 'screen', 'value': '/admin'}),
      ]));
      expect(board!.slides.first.actions, isEmpty);
    });
  });

  group('templates', () {
    test('the new stack template renders', () {
      expect(Board.fromJson(boardJson(template: 'stack')), isNotNull);
    });

    test('a template this build does not know is no board at all', () {
      expect(Board.fromJson(boardJson(template: 'diorama')), isNull);
    });
  });

  group('pickLocalised', () {
    test('prefers the caller\'s language', () {
      expect(pickLocalised(const {'en': 'Sale', 'fr': 'Soldes'}, locale), 'Sale');
    });
    test('falls back rather than showing nothing', () {
      expect(pickLocalised(const {'fr': 'Soldes'}, locale), 'Soldes');
      expect(pickLocalised(const {'de': 'Rabatt'}, locale), 'Rabatt');
    });
    test('empty is null, not an empty string', () {
      expect(pickLocalised(const {}, locale), isNull);
    });
  });

  group('media cache keep-set', () {
    test('holds every board\'s files, not just one', () {
      final a = Board.fromJson(boardJson(path: 'uuid-a/clip.mp4'))!;
      final b = Board.fromJson(boardJson(path: 'uuid-b/clip.mp4'))!;

      expect(boardMediaKeepSet([a, b]), {'uuid-a/clip.mp4', 'uuid-b/clip.mp4'});
      // The bug this closes: reconciling against one board alone treated the
      // other's file as stale and deleted it on every pull-to-refresh.
      expect(boardMediaKeepSet([a]), isNot(contains('uuid-b/clip.mp4')));
      // A placement that has not loaded contributes nothing and evicts nothing.
      expect(boardMediaKeepSet([a, null]), {'uuid-a/clip.mp4'});
    });
  });
}
