import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// One movement on a person's wallet: a referral reward (+), a withdrawal (−),
/// a withdrawal that was not sent and came back (+).
@immutable
class PersonalWalletEntry {
  final String id;
  final String kind;
  final int amountCents;
  final String? memo;
  final DateTime? createdAt;

  const PersonalWalletEntry({
    required this.id,
    required this.kind,
    required this.amountCents,
    this.memo,
    this.createdAt,
  });

  factory PersonalWalletEntry.fromJson(Map<String, dynamic> j) => PersonalWalletEntry(
    id: j['id'].toString(),
    kind: j['kind']?.toString() ?? 'adjustment',
    amountCents: (j['amount_cents'] as num?)?.toInt() ?? 0,
    memo: j['memo']?.toString(),
    createdAt: DateTime.tryParse(j['created_at']?.toString() ?? ''),
  );
}

/// A request to send money to MTN MoMo or Orange Money.
@immutable
class PersonalWithdrawal {
  final String id;
  final int amountCents;
  final String method;
  final String msisdn;

  /// requested | paid | rejected
  final String status;
  final String? providerRef;
  final String? note;
  final DateTime? requestedAt;

  const PersonalWithdrawal({
    required this.id,
    required this.amountCents,
    required this.method,
    required this.msisdn,
    required this.status,
    this.providerRef,
    this.note,
    this.requestedAt,
  });

  factory PersonalWithdrawal.fromJson(Map<String, dynamic> j) => PersonalWithdrawal(
    id: j['id'].toString(),
    amountCents: (j['amount_cents'] as num?)?.toInt() ?? 0,
    method: j['method']?.toString() ?? 'mtn_momo',
    msisdn: j['msisdn']?.toString() ?? '',
    status: j['status']?.toString() ?? 'requested',
    providerRef: j['provider_ref']?.toString(),
    note: j['note']?.toString(),
    requestedAt: DateTime.tryParse(j['requested_at']?.toString() ?? ''),
  );
}

@immutable
class PersonalWalletSummary {
  final int balanceCents;
  final int rewardCents;
  final int minWithdrawalCents;
  final List<PersonalWalletEntry> entries;
  final List<PersonalWithdrawal> withdrawals;

  const PersonalWalletSummary({
    required this.balanceCents,
    required this.rewardCents,
    required this.minWithdrawalCents,
    required this.entries,
    required this.withdrawals,
  });

  bool get canWithdraw =>
      balanceCents >= minWithdrawalCents && balanceCents > 0;

  factory PersonalWalletSummary.fromJson(Map<String, dynamic> j) => PersonalWalletSummary(
    balanceCents: (j['balance_cents'] as num?)?.toInt() ?? 0,
    rewardCents: (j['reward_cents'] as num?)?.toInt() ?? 0,
    minWithdrawalCents: (j['min_withdrawal_cents'] as num?)?.toInt() ?? 1000,
    entries: [
      for (final e in (j['entries'] as List? ?? const []))
        if (e is Map) PersonalWalletEntry.fromJson(e.cast<String, dynamic>()),
    ],
    withdrawals: [
      for (final w in (j['withdrawals'] as List? ?? const []))
        if (w is Map) PersonalWithdrawal.fromJson(w.cast<String, dynamic>()),
    ],
  );
}

/// A person's own money: referral earnings and withdrawals (`/me/wallet`).
class UserWalletRepository {
  UserWalletRepository._();
  static final UserWalletRepository instance = UserWalletRepository._();

  final _api = ApiClient.instance;

  Future<PersonalWalletSummary> summary() async {
    final json = await _api.get('/me/wallet') as Map<String, dynamic>;
    return PersonalWalletSummary.fromJson(json);
  }

  /// Throws [ApiException] with code `below_minimum`, `insufficient_balance`
  /// or `invalid_msisdn` for the cases a person can fix.
  Future<void> withdraw({
    required int amountCents,
    required String method,
    required String msisdn,
  }) async {
    await _api.post('/me/wallet/withdrawals', {
      'amount_cents': amountCents,
      'method': method,
      'msisdn': msisdn,
    });
  }
}
