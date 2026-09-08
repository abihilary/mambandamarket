import 'package:flutter_test/flutter_test.dart';
import 'package:mambandamarket/api/models.dart';

Map<String, dynamic> listingThread() => {
      'id': 'c1',
      'kind': 'listing',
      'listing_id': 'l1',
      'buyer_id': 'b1',
      'seller_id': 's1',
      'role': 'buyer',
      'unread': 3,
      'subject_title': 'A red bicycle',
      'listing': {
        'id': 'l1',
        'title': 'A red bicycle',
        'price_cents': 150000,
        'currency': 'XAF',
        'category_slug': 'bicycles',
      },
    };

Map<String, dynamic> shippingThread() => {
      'id': 'c2',
      'kind': 'shipping',
      'listing_id': null,
      'shipping_request_id': 'r1',
      'buyer_id': 'b1',
      'seller_id': 'desk',
      'role': 'buyer',
      'unread': 1,
      'subject_title': 'A washing machine',
      'shipping': {
        'id': 'r1',
        'status': 'quoted',
        'item_title': 'A washing machine',
        'size_key': 'appliance',
      },
    };

void main() {
  group('back-compatibility', () {
    test('a response with no kind is a listing thread, exactly as before', () {
      final json = listingThread()..remove('kind');
      final c = Conversation.fromJson(json);
      expect(c.kind, ConversationKind.listing);
      expect(c.isShipping, isFalse);
      expect(c.shipping, isNull);
      expect(c.listing?.title, 'A red bicycle');
      expect(c.unread, 3);
    });

    test('a kind this build has never heard of reads as a listing thread', () {
      // Whatever a later server invents must not make a thread unopenable.
      final json = listingThread()..['kind'] = 'auction';
      expect(Conversation.fromJson(json).kind, ConversationKind.listing);
    });
  });

  group('shipping threads', () {
    test('parse with no listing at all', () {
      final c = Conversation.fromJson(shippingThread());
      expect(c.isShipping, isTrue);
      expect(c.listing, isNull);
      expect(c.listingId, '');
      expect(c.shipping!.title, 'A washing machine');
      expect(c.shipping!.status, 'quoted');
      expect(c.subjectTitle, 'A washing machine');
    });

    test('an embed with no id is not a shipping subject', () {
      final json = shippingThread()..['shipping'] = {'status': 'new'};
      expect(Conversation.fromJson(json).shipping, isNull);
    });

    test('an empty title falls back to null rather than an empty string', () {
      final json = shippingThread();
      (json['shipping'] as Map)['item_title'] = '';
      expect(Conversation.fromJson(json).shipping!.title, isNull);
    });
  });

  group('copyWith', () {
    // The regression this exists for: marking a thread read used to rebuild
    // Conversation field by field, so every field added later was silently
    // dropped — a shipping thread turned back into a listing thread with no
    // listing the moment its room was opened.
    test('marking read keeps everything except the unread count', () {
      final before = Conversation.fromJson(shippingThread());
      final after = before.copyWith(unread: 0);

      expect(after.unread, 0);
      expect(after.kind, ConversationKind.shipping);
      expect(after.shipping?.id, 'r1');
      expect(after.shipping?.status, 'quoted');
      expect(after.subjectTitle, 'A washing machine');
      expect(after.id, before.id);
      expect(after.role, before.role);
      expect(after.buyerId, before.buyerId);
      expect(after.sellerId, before.sellerId);
    });

    test('a listing thread survives it too', () {
      final before = Conversation.fromJson(listingThread());
      final after = before.copyWith(unread: 0);
      expect(after.listing?.title, 'A red bicycle');
      expect(after.listingId, 'l1');
      expect(after.kind, ConversationKind.listing);
    });
  });
}
