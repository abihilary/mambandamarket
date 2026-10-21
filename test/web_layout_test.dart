import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mambandamarket/api/share_links.dart';
import 'package:mambandamarket/theme/breakpoints.dart';

void main() {
  group('listing links', () {
    const id = '733c1d47-63a6-471b-9500-15448bfc8a09';

    test('the web app reads its own address as a path', () {
      expect(ShareLinks.listingIdFromPath('/l/$id'), id);
      expect(ShareLinks.listingIdFromPath('/l/$id/'), id);
      expect(ShareLinks.listingIdFromPath('/'), isNull);
      expect(ShareLinks.listingIdFromPath('/home'), isNull);
      expect(ShareLinks.listingIdFromPath('/l/not-a-uuid'), isNull);
      expect(ShareLinks.listingIdFromPath('/x/$id'), isNull);
    });

    test('a full link still needs one of our hosts', () {
      expect(ShareLinks.listingIdFrom(Uri.parse('https://mambandamarket.com/l/$id')), id);
      expect(ShareLinks.listingIdFrom(Uri.parse('https://evil.example/l/$id')), isNull);
    });
  });

  group('ContentFrame', () {
    Future<Size> frameSize(WidgetTester tester, double screen) async {
      tester.view.physicalSize = Size(screen, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const key = Key('content');
      await tester.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: ContentFrame(
          maxWidth: 720,
          child: SizedBox.expand(key: key),
        ),
      ));
      return tester.getSize(find.byKey(key));
    }

    testWidgets('is not there on a phone', (tester) async {
      expect(await frameSize(tester, 390), const Size(390, 800));
    });

    testWidgets('caps and centres on a desktop', (tester) async {
      expect(await frameSize(tester, 1440), const Size(720, 800));
    });
  });

}
