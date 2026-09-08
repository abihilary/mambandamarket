import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:mambandamarket/api/board_model.dart';
import 'package:mambandamarket/api/trending_model.dart';

Map<String, dynamic> item(String id, {String title = 'A thing'}) => {
      'id': id,
      'title': title,
      'price_cents': 150000,
      'currency': 'XAF',
      'category_slug': 'mode',
      'view_count': 3,
      'created_at': '2026-09-01T10:00:00Z',
      'primary_image': 'uuid/pic.webp',
    };

void main() {
  const locale = Locale('en');

  test('items parse into a section', () {
    final section = TrendingSection.fromJson({
      'title': const {'en': 'Trending now', 'fr': 'Tendances'},
      'items': [item('a'), item('b')],
    });
    expect(section, isNotNull);
    expect(section!.items.length, 2);
    expect(section.titleFor(locale), 'Trending now');
  });

  test('no items means no section, so nothing is drawn', () {
    // Decided here rather than in the widget, so there is one answer to
    // "should this row exist" instead of one per place that draws it.
    expect(TrendingSection.fromJson(const {'items': []}), isNull);
    expect(TrendingSection.fromJson(null), isNull);
  });

  test('one unreadable row does not take the others down', () {
    // Listing.fromJson calls toString() on the id, which throws on a null one.
    final section = TrendingSection.fromJson({
      'items': [
        item('a'),
        {'title': 'no id here'},
        item('c'),
      ],
    });
    expect(section!.items.map((l) => l.id), ['a', 'c']);
  });

  test('a missing title leaves the app to supply its own word', () {
    final section = TrendingSection.fromJson({'items': [item('a')]});
    expect(section!.titleFor(locale), isNull);
  });

  test('see all is kept when it goes somewhere and dropped when it does not', () {
    final good = TrendingSection.fromJson({
      'items': [item('a')],
      'see_all': const {'kind': 'category', 'value': 'mode'},
    });
    expect(good!.seeAll?.kind, BoardLinkKind.category);

    for (final dud in [
      const {'kind': 'none'},
      const {'kind': 'category'},
      const {'kind': 'screen', 'value': '/admin'},
    ]) {
      final section = TrendingSection.fromJson({'items': [item('a')], 'see_all': dud});
      expect(section!.seeAll, isNull, reason: '$dud');
    }
  });
}
