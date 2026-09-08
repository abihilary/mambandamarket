import 'dart:ui' show Locale;

import 'board_model.dart';
import 'models.dart';

/// The curated product row, as the server describes it.
///
/// Whether the row exists at all is decided on the server: it answers with
/// nothing when the section is off, when nothing qualifies, or when fewer
/// products cleared the bar than the section requires. So there is exactly one
/// place that rule lives, and no build can be talked into drawing a row of two.
///
/// Parsing is forgiving in one direction only, like a board. A single
/// unreadable item is dropped; it does not take the row down with it.
class TrendingSection {
  const TrendingSection({
    required this.items,
    this.title = const {},
    this.seeAll,
  });

  final List<Listing> items;
  final Map<String, String> title;

  /// Where "See all" goes, when the dashboard set one. Null means no button —
  /// there is no generic "all trending" screen to fall back to.
  final BoardLink? seeAll;

  /// Null when there is nothing to show, which is a normal answer.
  static TrendingSection? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;

    final items = <Listing>[];
    for (final raw in (json['items'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final map = raw.cast<String, dynamic>();
      // Listing.fromJson stringifies the id, so a row without one becomes a
      // card that opens nothing rather than an error anybody notices. Drop it
      // here instead.
      final id = map['id'];
      if (id == null || id.toString().isEmpty) continue;
      try {
        items.add(Listing.fromJson(map));
      } catch (_) {
        // One unreadable row is not worth the whole row.
      }
    }
    if (items.isEmpty) return null;

    final seeAll = BoardLink.fromJson(
      (json['see_all'] as Map?)?.cast<String, dynamic>(),
    );
    return TrendingSection(
      items: items,
      title: _localised(json['title']),
      seeAll: (seeAll?.isActionable ?? false) ? seeAll : null,
    );
  }

  String? titleFor(Locale locale) => pickLocalised(title, locale);

  static Map<String, String> _localised(dynamic raw) {
    if (raw is! Map) return const {};
    return {
      for (final e in raw.entries)
        if (e.value is String && (e.value as String).isNotEmpty)
          e.key.toString(): e.value as String,
    };
  }
}
