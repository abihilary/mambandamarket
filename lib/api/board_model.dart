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
  });

  final int version;
  final String template;
  final BoardStyle style;
  final List<BoardSlide> slides;

  /// Null when there is nothing to show, which is a normal answer.
  static Board? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final template = json['template'] as String?;
    if (template == null || !_knownTemplates.contains(template)) return null;

    final slides = (json['slides'] as List? ?? [])
        .whereType<Map>()
        .map((s) => BoardSlide.fromJson(s.cast<String, dynamic>()))
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
    );
  }

  static const _knownTemplates = {'hero', 'carousel', 'text', 'split'};

  /// Every remote file this board refers to, for the video cache to reconcile
  /// against. Anything not in here is no longer needed on the device.
  Set<String> get mediaPaths => {
        for (final s in slides) ...[
          if (s.path != null) s.path!,
          if (s.posterPath != null) s.posterPath!,
        ],
      };
}

class BoardStyle {
  const BoardStyle({
    required this.aspect,
    required this.radius,
    required this.interval,
    required this.showDots,
  });

  final double aspect;
  final double radius;
  final Duration interval;
  final bool showDots;

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
  final String? background;
  final String? foreground;

  /// Null for anything this build cannot draw, so the caller can drop it.
  static BoardSlide? fromJson(Map<String, dynamic> json) {
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
          ) ??
          BoardLink.fromJson((json['link'] as Map?)?.cast<String, dynamic>()),
      background: json['background'] as String?,
      foreground: json['foreground'] as String?,
    );
  }

  static Map<String, String> _localised(dynamic raw) {
    if (raw is! Map) return const {};
    return {
      for (final e in raw.entries)
        if (e.value is String && (e.value as String).isNotEmpty)
          e.key.toString(): e.value as String,
    };
  }
}

/// Picks the caller's language, falling back to the other rather than showing
/// nothing. A board written only in French is still better read in French than
/// not read at all.
String? pickLocalised(Map<String, String> values, Locale locale) {
  if (values.isEmpty) return null;
  return values[locale.languageCode] ?? values['en'] ?? values['fr'] ?? values.values.first;
}

enum BoardLinkKind { none, url, listing, category }

class BoardLink {
  const BoardLink(this.kind, this.value);
  final BoardLinkKind kind;
  final String? value;

  bool get isActionable => kind != BoardLinkKind.none && (value?.isNotEmpty ?? false);

  static BoardLink? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final kind = switch (json['kind'] as String?) {
      'url' => BoardLinkKind.url,
      'listing' => BoardLinkKind.listing,
      'category' => BoardLinkKind.category,
      'none' => BoardLinkKind.none,
      _ => null,
    };
    if (kind == null) return null;
    return BoardLink(kind, json['value'] as String?);
  }
}
