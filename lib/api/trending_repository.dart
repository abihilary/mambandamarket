import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'trending_model.dart';

/// The trending row, for whichever category the shopper is looking at.
///
/// Two layers, not the three [BoardRepository] uses, and the difference is
/// deliberate. A board is decoration: yesterday's is still worth showing while
/// the network is down. A trending row is a claim about right now, and a
/// day-old one points at things that have since sold. So a failed refresh keeps
/// whatever this session already had — nothing flickers mid-use — and a cold
/// launch with no network simply has no trending row, which is a state this
/// surface is already defined for.
///
/// Nothing here throws, for the same reason nothing in the board repository
/// does: a decoration must never be able to stop somebody browsing.
class TrendingRepository {
  TrendingRepository._();
  static final TrendingRepository instance = TrendingRepository._();

  final ValueNotifier<TrendingSection?> section = ValueNotifier(null);

  /// Which category the value in [section] belongs to, so the row can be
  /// cleared the moment a chip changes rather than showing the previous
  /// category's products until the new answer lands.
  String? _for;
  int _seq = 0;

  Future<void> load({String? categorySlug}) async {
    // A fast run of chip taps must not let an earlier answer land on top of a
    // later one — the row would then disagree with the feed under it.
    final mine = ++_seq;

    if (categorySlug != _for) {
      _for = categorySlug;
      section.value = null;
    }

    try {
      final path = categorySlug == null || categorySlug.isEmpty
          ? '/trending'
          : '/trending?category=${Uri.encodeQueryComponent(categorySlug)}';
      final json = await ApiClient.instance.get(path) as Map<String, dynamic>;
      if (mine != _seq) return;
      section.value = TrendingSection.fromJson(
        (json['section'] as Map?)?.cast<String, dynamic>(),
      );
    } catch (e) {
      debugPrint('[trending] refresh failed ($e)');
      // Keep whatever this session had. On a cold launch that is nothing, and
      // no row is the correct thing to show when we cannot say what is trending.
    }
  }
}
