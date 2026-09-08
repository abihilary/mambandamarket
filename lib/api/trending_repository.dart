import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'repositories.dart';
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

  /// Where the feed last knew the caller to be, so "near you" has an origin.
  /// Set by whoever already asked for a location; this never asks on its own.
  (double, double)? _origin;
  set origin((double, double)? value) => _origin = value;

  /// The category this person has saved the most from.
  String? _favouriteCategory() {
    final counts = <String, int>{};
    for (final listing in FavoritesRepository.instance.favorites.value) {
      final slug = listing.categorySlug;
      if (slug.isEmpty) continue;
      counts[slug] = (counts[slug] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  Future<void> load({
    String? categorySlug,
    bool nearMe = false,
    bool likeMyFavourites = false,
  }) async {
    // A fast run of chip taps must not let an earlier answer land on top of a
    // later one — the row would then disagree with the feed under it.
    final mine = ++_seq;

    if (categorySlug != _for) {
      _for = categorySlug;
      section.value = null;
    }

    try {
      // "Because you like" is not a recommender: it is the category the person
      // has saved most from. Cheap, honest, and it needs nothing the server
      // does not already do.
      var slug = categorySlug;
      if (likeMyFavourites) slug = _favouriteCategory() ?? categorySlug;

      final params = <String>[
        if (slug != null && slug.isNotEmpty) 'category=${Uri.encodeQueryComponent(slug)}',
        if (nearMe && _origin != null) 'near=${_origin!.$1},${_origin!.$2}',
        if (nearMe && _origin != null) 'sort=distance',
      ];
      final path = params.isEmpty ? '/trending' : '/trending?${params.join('&')}';
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
