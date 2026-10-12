import 'package:flutter_test/flutter_test.dart';
import 'package:mambandamarket/api/models.dart';

void main() {
  test('a held message carries its status and reason, in both languages', () {
    final m = Message.fromJson({
      'id': 'm1',
      'conversation_id': 'c1',
      'sender_id': 'u1',
      'body': 'send the money first',
      'moderation_status': 'held',
      'moderation': {
        'status': 'held',
        'case_id': 'k1',
        'reason': {'en': 'Pay on delivery.', 'fr': 'Paiement à la livraison.'},
        'appealed': false,
      },
    });
    expect(m.isHeld, isTrue);
    expect(m.isRejected, isFalse);
    expect(m.moderationReasonFor('fr'), 'Paiement à la livraison.');
    expect(m.moderationReasonFor('en'), 'Pay on delivery.');
    expect(m.copyWith(moderationAppealed: true).moderationAppealed, isTrue);
    expect(m.copyWith(moderationAppealed: true).isHeld, isTrue, reason: 'copyWith keeps the status');
  });

  test('an ordinary message from an older server is simply visible', () {
    final m = Message.fromJson({'id': 'm2', 'conversation_id': 'c1', 'sender_id': 'u2', 'body': 'hi'});
    expect(m.moderationStatus, 'visible');
    expect(m.isHeld || m.isRejected, isFalse);
  });

  test('a listing with changes requested exposes what to fix', () {
    final l = Listing.fromJson({
      'id': 'l1',
      'title': 'Shoe',
      'status': 'hidden',
      'review_state': 'changes_requested',
      'moderation_locked': true,
      'review_messages': {
        'en': ['Write a clearer title.'],
        'fr': ['Écrivez un titre plus précis.'],
      },
    });
    expect(l.needsChanges, isTrue);
    expect(l.hiddenByTeam, isFalse);
    expect(l.reviewMessagesFor('fr').single, 'Écrivez un titre plus précis.');
  });

  test('a listing hidden by the team without a request is told apart', () {
    final l = Listing.fromJson({'id': 'l2', 'title': 'x', 'status': 'hidden', 'moderation_locked': true});
    expect(l.hiddenByTeam, isTrue);
    expect(l.needsChanges, isFalse);
  });
}
