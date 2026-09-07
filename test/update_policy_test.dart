import 'package:flutter_test/flutter_test.dart';
import 'package:mambandamarket/api/update_policy.dart';

void main() {
  final now = DateTime.utc(2026, 9, 7, 12);

  UpdateDecision decide({
    int? build = 29,
    String mode = 'notify',
    int latestBuild = 0,
    int minSupportedBuild = 0,
    DateTime? blocksAt,
    DateTime? serverNow,
    int? snoozedBuild,
    DateTime? snoozedAt,
  }) =>
      decideUpdate(
        build: build,
        mode: mode,
        latestBuild: latestBuild,
        minSupportedBuild: minSupportedBuild,
        blocksAt: blocksAt,
        serverNow: serverNow ?? now,
        snoozedBuild: snoozedBuild,
        snoozedAt: snoozedAt,
        now: now,
      );

  group('inert configurations', () {
    test('mode off says nothing even when far behind', () {
      expect(decide(mode: 'off', latestBuild: 99, minSupportedBuild: 99),
          UpdateDecision.none);
    });
    test('unknown build says nothing', () {
      expect(decide(build: null, latestBuild: 99), UpdateDecision.none);
    });
    test('current build says nothing', () {
      expect(decide(latestBuild: 29), UpdateDecision.none);
      expect(decide(latestBuild: 28), UpdateDecision.none);
    });
  });

  group('nudge', () {
    test('a newer build nudges', () {
      expect(decide(latestBuild: 30), UpdateDecision.nudge);
    });
    test('snoozed for the same build within three days stays quiet', () {
      expect(
        decide(latestBuild: 30, snoozedBuild: 30,
            snoozedAt: now.subtract(const Duration(days: 2))),
        UpdateDecision.none,
      );
    });
    test('snooze expires after three days', () {
      expect(
        decide(latestBuild: 30, snoozedBuild: 30,
            snoozedAt: now.subtract(const Duration(days: 4))),
        UpdateDecision.nudge,
      );
    });
    test('a snooze on an older build does not cover a newer one', () {
      expect(
        decide(latestBuild: 31, snoozedBuild: 30,
            snoozedAt: now.subtract(const Duration(hours: 1))),
        UpdateDecision.nudge,
      );
    });
  });

  group('floor', () {
    test('below the floor in notify mode warns', () {
      expect(decide(minSupportedBuild: 30), UpdateDecision.warn);
    });
    test('the floor outranks a nudge', () {
      expect(decide(latestBuild: 31, minSupportedBuild: 30), UpdateDecision.warn);
    });
    test('block mode without a deadline warns', () {
      expect(decide(mode: 'block', minSupportedBuild: 30), UpdateDecision.warn);
    });
    test('block mode before the deadline warns', () {
      expect(
        decide(mode: 'block', minSupportedBuild: 30,
            blocksAt: now.add(const Duration(days: 1))),
        UpdateDecision.warn,
      );
    });
    test('block mode past the deadline blocks', () {
      expect(
        decide(mode: 'block', minSupportedBuild: 30,
            blocksAt: now.subtract(const Duration(minutes: 1))),
        UpdateDecision.blocked,
      );
    });
    test('the deadline is judged by server time, not device time', () {
      final deadline = now.add(const Duration(hours: 1));
      // Device thinks it is noon; the server says it is already 14:00.
      expect(
        decide(mode: 'block', minSupportedBuild: 30, blocksAt: deadline,
            serverNow: now.add(const Duration(hours: 2))),
        UpdateDecision.blocked,
      );
    });
    test('at or above the floor is not on notice', () {
      expect(decide(build: 30, minSupportedBuild: 30), UpdateDecision.none);
    });
  });
}
