import 'dart:ui' show Locale;

/// The home board, as the server describes it.
///
/// Parsing is deliberately forgiving in one direction only. Anything this build
/// does not recognise — a template added later, a slide type that did not exist
/// when this APK was signed — is *skipped*, never fatal. A board is decoration
/// on a marketplace; it must not be able to stop somebody browsing, and an old
/// phone should degrade to showing less rather than showing an error.
class Board {
  const Board({
    required this.version,
    required this.template,
    required this.style,
    required this.slides,
    this.promos = const {},
  });

  final int version;
  final String template;
  final BoardStyle style;
  final List<BoardSlide> slides;

  /// Promos this board can open, by id. Defined in the board itself so a
  /// promotion and the button that opens it are published, restored and rolled
  /// back together.
  final Map<String, BoardPromo> promos;

  /// Null when there is nothing to show, which is a normal answer.
  static Board? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final template = json['template'] as String?;
    if (template == null || !_knownTemplates.contains(template)) return null;

    // Promos first: a link naming one is resolved as it is parsed, so nothing
    // downstream has to carry the board around to find out what a button opens.
    final promos = <String, BoardPromo>{};
    final rawPromos = json['modals'];
    if (rawPromos is Map) {
      for (final entry in rawPromos.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final promo = BoardPromo.fromJson(
          entry.key.toString(),
          value.cast<String, dynamic>(),
        );
        if (promo != null) promos[promo.id] = promo;
      }
    }

    final slides = (json['slides'] as List? ?? [])
        .whereType<Map>()
        .map((s) => BoardSlide.fromJson(s.cast<String, dynamic>(), promos: promos))
        .whereType<BoardSlide>()
        .toList();
    // Every slide unreadable is the same as no board. Rendering an empty frame
    // would leave a hole in the feed with no explanation.
    if (slides.isEmpty) return null;

    return Board(
      version: (json['version'] as num?)?.toInt() ?? 0,
      template: template,
      style: BoardStyle.fromJson((json['style'] as Map?)?.cast<String, dynamic>() ?? const {}),
      slides: slides,
      promos: promos,
    );
  }

  static const _knownTemplates = {'hero', 'carousel', 'text', 'split', 'stack'};

  /// Every remote file this board refers to, for the video cache to reconcile
  /// against. Anything not in here is no longer needed on the device.
  Set<String> get mediaPaths => {
        for (final s in slides) ...[
          if (s.path != null) s.path!,
          if (s.posterPath != null) s.posterPath!,
        ],
        // Promo artwork goes through the image cache rather than this one, so
        // these are never held here today. Included so the set stays honest if
        // a promo ever carries a clip.
        for (final p in promos.values)
          if (p.imagePath != null) p.imagePath!,
      };
}

class BoardStyle {
  const BoardStyle({
    required this.aspect,
    required this.radius,
    required this.interval,
    required this.showDots,
    required this.scrim,
  });

  final double aspect;
  final double radius;
  final Duration interval;
  final bool showDots;

  /// Darkens the foot of a media slide so overlaid words stay readable. Only
  /// drawn where there is something to keep readable.
  final bool scrim;

  factory BoardStyle.fromJson(Map<String, dynamic> json) {
    final ratio = switch (json['aspect'] as String?) {
      '4:3' => 4 / 3,
      '21:9' => 21 / 9,
      _ => 16 / 9,
    };
    return BoardStyle(
      aspect: ratio,
      radius: ((json['radius'] as num?)?.toDouble() ?? 12).clamp(0, 32),
      interval: Duration(
        milliseconds:
            ((json['intervalMs'] as num?)?.toInt() ?? 5000).clamp(2000, 30000),
      ),
      showDots: json['showDots'] as bool? ?? true,
      scrim: json['scrim'] as bool? ?? true,
    );
  }
}

enum SlideKind { image, video, text }

class BoardSlide {
  const BoardSlide({
    required this.kind,
    this.url,
    this.path,
    this.posterUrl,
    this.posterPath,
    this.autoplay = true,
    this.loop = true,
    this.muted = true,
    this.alt = const {},
    this.title = const {},
    this.body = const {},
    this.ctaLabel = const {},
    this.link,
    this.actions = const [],
    this.background,
    this.foreground,
  });

  final SlideKind kind;
  final String? url;

  /// Storage path, not the URL. The video cache keys on this: paths carry a
  /// uuid, so a replaced clip is a key the device has never seen and the old
  /// file falls out of the referenced set.
  final String? path;

  final String? posterUrl;
  final String? posterPath;
  final bool autoplay;
  final bool loop;
  final bool muted;

  final Map<String, String> alt;
  final Map<String, String> title;
  final Map<String, String> body;
  final Map<String, String> ctaLabel;

  final BoardLink? link;

  /// Buttons drawn on the slide. Capped at three: that is what fits across a
  /// banner on a small phone once the labels are in French, and a config that
  /// asks for more is a config somebody got wrong.
  final List<BoardAction> actions;

  final String? background;
  final String? foreground;

  /// Null for anything this build cannot draw, so the caller can drop it.
  static BoardSlide? fromJson(
    Map<String, dynamic> json, {
    Map<String, BoardPromo> promos = const {},
  }) {
    final kind = switch (json['type'] as String?) {
      'image' => SlideKind.image,
      'video' => SlideKind.video,
      'text' => SlideKind.text,
      _ => null,
    };
    if (kind == null) return null;

    // Media slides without media are not worth a frame.
    final url = json['url'] as String?;
    if (kind != SlideKind.text && (url == null || url.isEmpty)) return null;

    return BoardSlide(
      kind: kind,
      url: url,
      path: json['path'] as String?,
      posterUrl: json['poster_url'] as String?,
      posterPath: json['poster'] as String?,
      autoplay: json['autoplay'] as bool? ?? true,
      loop: json['loop'] as bool? ?? true,
      muted: json['muted'] as bool? ?? true,
      alt: _localised(json['alt']),
      title: _localised(json['title']),
      body: _localised(json['body']),
      ctaLabel: _localised((json['cta'] as Map?)?['label']),
      link: BoardLink.fromJson(
            ((json['cta'] as Map?)?['link'] as Map?)?.cast<String, dynamic>(),
            promos: promos,
          ) ??
          BoardLink.fromJson(
            (json['link'] as Map?)?.cast<String, dynamic>(),
            promos: promos,
          ),
      actions: BoardAction.listFrom(json['actions'], promos: promos),
      background: json['background'] as String?,
      foreground: json['foreground'] as String?,
    );
  }

  static Map<String, String> _localised(dynamic raw) => _localisedOf(raw);
}

Map<String, String> _localisedOf(dynamic raw) {
  if (raw is! Map) return const {};
  return {
    for (final e in raw.entries)
      if (e.value is String && (e.value as String).isNotEmpty)
        e.key.toString(): e.value as String,
  };
}

/// A button on a slide, or inside a promo.
class BoardAction {
  const BoardAction({
    required this.label,
    required this.link,
    this.style = BoardActionStyle.primary,
  });

  final Map<String, String> label;
  final BoardLink link;
  final BoardActionStyle style;

  /// Null for anything that would draw a button going nowhere, which is worse
  /// than no button: it looks like the app is broken rather than like the
  /// promotion is over.
  static BoardAction? fromJson(
    Map<String, dynamic> json, {
    Map<String, BoardPromo> promos = const {},
  }) {
    final label = _localisedOf(json['label']);
    if (label.isEmpty) return null;
    final link = BoardLink.fromJson(
      (json['link'] as Map?)?.cast<String, dynamic>(),
      promos: promos,
    );
    if (link == null || !link.isActionable) return null;
    return BoardAction(
      label: label,
      link: link,
      style: json['style'] == 'ghost' ? BoardActionStyle.ghost : BoardActionStyle.primary,
    );
  }

  static List<BoardAction> listFrom(
    dynamic raw, {
    Map<String, BoardPromo> promos = const {},
  }) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((a) => BoardAction.fromJson(a.cast<String, dynamic>(), promos: promos))
        .whereType<BoardAction>()
        .take(3)
        .toList(growable: false);
  }
}

enum BoardActionStyle { primary, ghost }

/// A promotion the app can show without leaving the feed.
class BoardPromo {
  const BoardPromo({
    required this.id,
    this.imageUrl,
    this.imagePath,
    this.title = const {},
    this.body = const {},
    this.actions = const [],
  });

  final String id;
  final String? imageUrl;
  final String? imagePath;
  final Map<String, String> title;
  final Map<String, String> body;
  final List<BoardAction> actions;

  /// Null when there would be nothing to read: a panel that slides up empty is
  /// worse than a button that does nothing.
  static BoardPromo? fromJson(String id, Map<String, dynamic> json) {
    final title = _localisedOf(json['title']);
    final body = _localisedOf(json['body']);
    if (title.isEmpty && body.isEmpty) return null;
    return BoardPromo(
      id: id,
      imageUrl: json['image_url'] as String?,
      imagePath: json['image'] as String?,
      title: title,
      body: body,
      // A promo's own buttons never open a promo — the server refuses to store
      // one, and passing no map here means such a link could not resolve anyway.
      actions: BoardAction.listFrom(json['actions']),
    );
  }
}

/// Picks the caller's language, falling back to the other rather than showing
/// nothing. A board written only in French is still better read in French than
/// not read at all.
String? pickLocalised(Map<String, String> values, Locale locale) {
  if (values.isEmpty) return null;
  return values[locale.languageCode] ?? values['en'] ?? values['fr'] ?? values.values.first;
}

enum BoardLinkKind { none, url, listing, category, promo, screen }

/// Named routes a board is allowed to open.
///
/// A closed list, and not a suggestion. `main.dart`'s `onGenerateRoute` ends in
/// `default: SplashScreen()`, and the splash screen re-roots the navigator — so
/// a route this build does not have would not be an inert dead button, it would
/// throw the user out of whatever they were doing. The server keeps the same
/// list and refuses to store anything outside it; this is the second check,
/// because the first one runs on a machine we do not control at tap time.
const allowedBoardScreens = <String>{
  '/my-orders',
  '/invite',
  '/subscription',
  '/create-listing',
};

class BoardLink {
  const BoardLink(this.kind, this.value, {this.promo});
  final BoardLinkKind kind;
  final String? value;

  /// Resolved from the board's own promos as the link is parsed. A link naming
  /// a promo the board does not define never becomes actionable, so a typo in
  /// the dashboard costs a button rather than producing one that does nothing.
  final BoardPromo? promo;

  bool get isActionable => switch (kind) {
        BoardLinkKind.none => false,
        BoardLinkKind.promo => promo != null,
        BoardLinkKind.screen => allowedBoardScreens.contains(value),
        _ => value?.isNotEmpty ?? false,
      };

  static BoardLink? fromJson(
    Map<String, dynamic>? json, {
    Map<String, BoardPromo> promos = const {},
  }) {
    if (json == null) return null;
    final kind = switch (json['kind'] as String?) {
      'url' => BoardLinkKind.url,
      'listing' => BoardLinkKind.listing,
      'category' => BoardLinkKind.category,
      'promo' => BoardLinkKind.promo,
      'screen' => BoardLinkKind.screen,
      'none' => BoardLinkKind.none,
      // Anything a later dashboard invents: not drawn, rather than drawn wrong.
      _ => null,
    };
    if (kind == null) return null;
    final value = json['value'] as String?;
    return BoardLink(
      kind,
      value,
      promo: kind == BoardLinkKind.promo && value != null ? promos[value] : null,
    );
  }
}
