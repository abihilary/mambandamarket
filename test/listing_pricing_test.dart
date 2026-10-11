// Pricing modes and kinds — the behaviour ~30 render sites inherit from
// Listing.displayPrice, plus the gates that keep a job out of checkout.
import 'package:flutter_test/flutter_test.dart';
import 'package:mambandamarket/api/models.dart';

Listing _listing({
  String kind = 'product',
  String priceMode = 'fixed',
  int priceCents = 5000,
  String? companyId = 'c1',
  int quantity = 1,
  String status = 'active',
}) =>
    Listing(
      id: 'l1',
      sellerId: 's1',
      title: 't',
      priceCents: priceCents,
      currency: 'XAF',
      quantity: quantity,
      categorySlug: 'elektronik',
      kind: kind,
      priceMode: priceMode,
      companyId: companyId,
      status: status,
      createdAt: DateTime(2026),
    );

void main() {
  group('displayPrice', () {
    test('a fixed price is the amount, unchanged', () {
      expect(_listing().displayPrice, '5.000 FCFA');
    });

    test('XAF is zero-decimal — 145000 is 145.000 FCFA, not 1.450', () {
      expect(_listing(priceCents: 145000).displayPrice, '145.000 FCFA');
    });

    test('amount-less modes render from the mode, never the stored 0', () {
      for (final mode in ['negotiable', 'on_request', 'free']) {
        final text = _listing(priceMode: mode, priceCents: 0).displayPrice;
        expect(text, isNot(contains('0')),
            reason: '$mode must not show the placeholder amount');
        expect(text, isNotEmpty);
      }
    });

    test('the three amount-less modes read differently from each other', () {
      String p(String m) => _listing(priceMode: m, priceCents: 0).displayPrice;
      expect({p('negotiable'), p('on_request'), p('free')}, hasLength(3));
    });

    test('from / hourly / daily keep the amount and qualify it', () {
      expect(_listing(priceMode: 'from').displayPrice, contains('5.000 FCFA'));
      expect(_listing(priceMode: 'from').displayPrice,
          isNot('5.000 FCFA'), reason: 'must be qualified, not bare');
      expect(_listing(priceMode: 'hourly').displayPrice, contains('5.000 FCFA'));
      expect(_listing(priceMode: 'daily').displayPrice, contains('5.000 FCFA'));
    });
  });

  group('gates', () {
    test('a plain company product is buyable', () {
      expect(_listing().isBuyable, isTrue);
    });

    test('a job is never buyable, even from a verified company', () {
      expect(_listing(kind: 'job').isBuyable, isFalse);
      expect(_listing(kind: 'service').isBuyable, isFalse);
    });

    test('a negotiable product is not buyable — there is no price to charge', () {
      expect(_listing(priceMode: 'negotiable', priceCents: 0).isBuyable, isFalse);
      expect(_listing(priceMode: 'on_request', priceCents: 0).isBuyable, isFalse);
    });

    test('free is a real amount, so it does not block the other gates', () {
      expect(_listing(priceMode: 'free', priceCents: 0).hasNoAmount, isFalse);
      expect(_listing(priceMode: 'negotiable').hasNoAmount, isTrue);
    });

    test('isProduct is what the shipping and condition chips key off', () {
      expect(_listing().isProduct, isTrue);
      expect(_listing(kind: 'service').isProduct, isFalse);
      expect(_listing(kind: 'job').isProduct, isFalse);
    });
  });

  group('parsing', () {
    test('a response from before 0048 still parses as a product', () {
      final old = Listing.fromJson({
        'id': 'l1', 'seller_id': 's1', 'title': 't',
        'price_cents': 5000, 'currency': 'XAF', 'quantity': 1,
        'category_slug': 'elektronik', 'created_at': '2026-01-01T00:00:00Z',
      });
      expect(old.kind, 'product');
      expect(old.priceMode, 'fixed');
      expect(old.displayPrice, '5.000 FCFA');
    });

    test('the new columns are read when present', () {
      final j = Listing.fromJson({
        'id': 'l1', 'seller_id': 's1', 'title': 't',
        'price_cents': 0, 'currency': 'XAF', 'quantity': 1,
        'category_slug': 'professional-services',
        'kind': 'service', 'price_mode': 'on_request',
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(j.kind, 'service');
      expect(j.isProduct, isFalse);
      expect(j.displayPrice, isNot(contains('0')));
    });
  });

  group('currency round-trip (the search filter bug)', () {
    test('XAF survives a round trip through the filter sheet', () {
      // Typing 5000 must filter at 5.000 FCFA, not 500.000.
      expect(toMinorUnits(5000), 5000);
      expect(fromMinorUnits(toMinorUnits(5000)), 5000);
    });

    test('a hundredths currency still scales', () {
      expect(toMinorUnits(50, currency: 'EUR'), 5000);
      expect(fromMinorUnits(5000, currency: 'EUR'), 50);
    });
  });
}
