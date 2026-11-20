import 'package:flutter_test/flutter_test.dart';
import 'package:mambandamarket/api/share_links.dart';

void main() {
  const id = '1d2043e4-f54e-41d6-b271-e1c3bdf64638';

  test('a shop link is /s/<user id> on the public site', () {
    expect(ShareLinks.shop(id).toString(), 'https://mambandamarket.com/s/$id');
  });

  test('shop and listing links are told apart, both ways', () {
    final shop = ShareLinks.shop(id);
    final listing = ShareLinks.listing(id);
    expect(ShareLinks.shopIdFrom(shop), id);
    expect(ShareLinks.listingIdFrom(shop), isNull);
    expect(ShareLinks.listingIdFrom(listing), id);
    expect(ShareLinks.shopIdFrom(listing), isNull);
  });

  test('only our hosts, and only a real id', () {
    expect(ShareLinks.shopIdFrom(Uri.parse('https://evil.example/s/$id')), isNull);
    expect(ShareLinks.shopIdFrom(Uri.parse('https://mambandamarket.blacksilvergroups.xyz/s/$id')), id);
    expect(ShareLinks.shopIdFromPath('/s/not-an-id'), isNull);
    expect(ShareLinks.shopIdFromPath('/s/$id/extra'), isNull);
    expect(ShareLinks.shopIdFromPath('/s/$id'), id);
  });

  test('invite links carry a clean code', () {
    expect(ShareLinks.invite(' wil374 ').toString(), 'https://mambandamarket.com/r/WIL374');
    expect(ShareLinks.inviteCodeFrom(Uri.parse('https://mambandamarket.com/r/wil374')), 'WIL374');
    expect(ShareLinks.inviteCodeFromPath('/r/AB'), isNull);
    expect(ShareLinks.inviteCodeFromPath('/r/WIL-374'), isNull);
    expect(ShareLinks.inviteCodeFrom(Uri.parse('https://evil.example/r/WIL374')), isNull);
  });

  test('category links carry a clean slug', () {
    expect(ShareLinks.categorySlugFrom(Uri.parse('https://mambandamarket.com/c/food-drink')), 'food-drink');
    expect(ShareLinks.categorySlugFromPath('/c/Mode'), 'mode');
    expect(ShareLinks.categorySlugFromPath('/c/../x'), isNull);
    expect(ShareLinks.listingIdFromPath('/c/mode'), isNull);
  });
}
