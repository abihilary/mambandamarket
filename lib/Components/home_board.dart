import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../api/board_media_cache.dart';
import '../api/board_model.dart';
import '../api/board_repository.dart';
import '../navigation.dart';
import '../theme/app_tokens.dart';
import 'board_promo_sheet.dart';

/// The dashboard-authored board in the home feed.
///
/// This slot showed a hardcoded picsum.photos placeholder to every user from
/// the day the screen was written. It now shows whatever an admin published,
/// and nothing at all when they have published nothing — which is the normal
/// state, not an error state.
///
/// Everything here is defensive by design. The board is decoration on a
/// marketplace: an image that will not load, a video that will not play, or a
/// template this build has never heard of must all reduce to "less board", never
/// to a broken home feed.
class HomeBoard extends StatelessWidget {
  const HomeBoard({
    super.key,
    this.slug = BoardRepository.homeSlug,
    this.onCategory,
  });

  /// Which placement to draw. One widget for both, so a change to the carousel
  /// or the video lifecycle cannot apply to one board and not the other.
  final String slug;

  /// How a `category` link asks the feed to filter. Supplied by HomeScreen so
  /// the board reuses the same path a tap on the category bar takes.
  final void Function(String slug)? onCategory;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Board?>(
      valueListenable: BoardRepository.instance.notifier(slug),
      builder: (context, board, _) {
        // No board is the common case. Take up no room at all rather than
        // leaving a gap where one used to be.
        if (board == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(board.style.radius),
            // The stack template sizes to its words instead of to a ratio: a
            // headline, a line of body and two buttons do not fit inside a
            // 21:9 banner once the labels are in French.
            child: board.template == 'stack'
                ? _Stack(board: board, onCategory: onCategory)
                : AspectRatio(
                    aspectRatio: board.style.aspect,
                    child: _BoardBody(board: board, onCategory: onCategory),
                  ),
          ),
        );
      },
    );
  }
}

/// Media on top, words and buttons underneath.
class _Stack extends StatelessWidget {
  const _Stack({required this.board, this.onCategory});

  final Board board;
  final void Function(String slug)? onCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slide = board.slides.first;
    final locale = Localizations.localeOf(context);
    final title = pickLocalised(slide.title, locale);
    final body = pickLocalised(slide.body, locale);
    final bg = _hex(slide.background) ?? theme.colorScheme.surfaceContainerHighest;
    final fg = _hex(slide.foreground) ?? theme.colorScheme.onSurface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: board.style.aspect,
          child: _Slide(slide: slide, active: true, onCategory: onCategory, overlay: false),
        ),
        Container(
          width: double.infinity,
          color: bg,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null)
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: fg, fontWeight: FontWeight.w800),
                ),
              if (body != null) ...[
                const SizedBox(height: 4),
                Text(
                  body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: fg.withValues(alpha: 0.8)),
                ),
              ],
              if (slide.actions.isNotEmpty) ...[
                const SizedBox(height: 12),
                _ActionBar(
                  actions: slide.actions,
                  onMedia: false,
                  foreground: fg,
                  onCategory: onCategory,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BoardBody extends StatelessWidget {
  const _BoardBody({required this.board, this.onCategory});

  final Board board;
  final void Function(String slug)? onCategory;

  @override
  Widget build(BuildContext context) {
    if (board.template == 'carousel' && board.slides.length > 1) {
      return _Carousel(board: board, onCategory: onCategory);
    }
    final slide = board.slides.first;
    if (board.template == 'split' && slide.kind != SlideKind.text) {
      return _Split(slide: slide, onCategory: onCategory);
    }
    return _Slide(slide: slide, active: true, onCategory: onCategory, scrim: board.style.scrim);
  }
}

class _Carousel extends StatefulWidget {
  const _Carousel({required this.board, this.onCategory});

  final Board board;
  final void Function(String slug)? onCategory;

  @override
  State<_Carousel> createState() => _CarouselState();
}

class _CarouselState extends State<_Carousel> {
  final _controller = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.board.style.interval, (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % widget.board.slides.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.board.slides;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Advancing on its own while somebody is dragging fights them; the
        // timer restarts once they let go.
        NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollStartNotification && n.dragDetails != null) _timer?.cancel();
            if (n is ScrollEndNotification) _start();
            return false;
          },
          child: PageView.builder(
            controller: _controller,
            itemCount: slides.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => _Slide(
              slide: slides[i],
              // Only the slide on screen plays. Four videos decoding at once
              // for the sake of one visible frame is battery and data spent on
              // nothing.
              active: i == _index,
              onCategory: widget.onCategory,
              scrim: widget.board.style.scrim,
            ),
          ),
        ),
        if (widget.board.style.showDots && slides.length > 1)
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _index ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: i == _index ? 0.95 : 0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({
    required this.slide,
    required this.active,
    this.onCategory,
    this.scrim = true,
    this.overlay = true,
  });

  final BoardSlide slide;
  final bool active;
  final void Function(String slug)? onCategory;
  final bool scrim;

  /// Whether words and buttons are drawn over the media. False on the stack
  /// template, which puts them underneath instead.
  final bool overlay;

  @override
  Widget build(BuildContext context) {
    final media = switch (slide.kind) {
      SlideKind.image => _Image(slide: slide),
      SlideKind.video => _Video(slide: slide, active: active),
      SlideKind.text => _Text(slide: slide, onCategory: onCategory),
    };

    Widget child = media;

    // Text slides draw their own words; over media, they go in an overlay.
    if (overlay && slide.kind != SlideKind.text) {
      final locale = Localizations.localeOf(context);
      final title = pickLocalised(slide.title, locale);
      final body = pickLocalised(slide.body, locale);
      if (title != null || body != null || slide.actions.isNotEmpty) {
        child = Stack(
          fit: StackFit.expand,
          children: [
            media,
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _Overlay(
                title: title,
                body: body,
                actions: slide.actions,
                scrim: scrim,
                onCategory: onCategory,
              ),
            ),
          ],
        );
      }
    }

    if (!(slide.link?.isActionable ?? false)) return child;
    // The buttons sit above this in the stack and take their own taps, so the
    // slide's link is what is left over — tapping the picture, not the button.
    return GestureDetector(
      onTap: () => openBoardLink(context, slide.link!, onCategory: onCategory),
      child: child,
    );
  }
}

/// Words and buttons over a picture.
///
/// A gradient scrim, not a [GlassSurface]: a BackdropFilter over a playing
/// video inside a scrolling feed is the exact case that file warns about, and
/// a linear gradient is a single cheap paint.
class _Overlay extends StatelessWidget {
  const _Overlay({
    this.title,
    this.body,
    required this.actions,
    required this.scrim,
    this.onCategory,
  });

  final String? title;
  final String? body;
  final List<BoardAction> actions;
  final bool scrim;
  final void Function(String slug)? onCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: scrim
          ? const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xA6000000), Color(0x00000000)],
              ),
            )
          : const BoxDecoration(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Text(
                title!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            if (body != null) ...[
              const SizedBox(height: 3),
              Text(
                body!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
              ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 10),
              _ActionBar(
                actions: actions,
                onMedia: true,
                foreground: Colors.white,
                onCategory: onCategory,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The buttons themselves.
///
/// A [Wrap], not a Row: "En savoir plus" beside "Voir la boutique" does not fit
/// across a 360dp phone, and a Row would overflow rather than move one down.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.actions,
    required this.onMedia,
    required this.foreground,
    this.onCategory,
  });

  final List<BoardAction> actions;
  final bool onMedia;
  final Color foreground;
  final void Function(String slug)? onCategory;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final action in actions)
          _ActionButton(
            label: pickLocalised(action.label, locale) ?? '',
            style: action.style,
            onMedia: onMedia,
            foreground: foreground,
            onTap: () => openBoardLink(context, action.link, onCategory: onCategory),
          ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.style,
    required this.onMedia,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final BoardActionStyle style;
  final bool onMedia;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    final tokens = context.tokens;
    final theme = Theme.of(context);

    // accentFill is a background and never ink — lime reads at 1.43:1 on white.
    final isPrimary = style == BoardActionStyle.primary;
    final background = isPrimary ? tokens.accentFill : Colors.transparent;
    final ink = isPrimary
        ? tokens.onAccentFill
        : (onMedia ? Colors.white : foreground);

    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: isPrimary
            ? BorderSide.none
            : BorderSide(color: ink.withValues(alpha: 0.7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: ink, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

class _Image extends StatelessWidget {
  const _Image({required this.slide});
  final BoardSlide slide;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return CachedNetworkImage(
      imageUrl: slide.url!,
      fit: BoxFit.cover,
      width: double.infinity,
      // No spinner. A board is not worth a loading indicator in the middle of
      // the feed; it either appears or it does not.
      placeholder: (_, __) => const _Blank(),
      errorWidget: (_, __, ___) => const _Blank(),
      imageBuilder: (context, image) => Semantics(
        label: pickLocalised(slide.alt, locale),
        image: true,
        child: Image(image: image, fit: BoxFit.cover, width: double.infinity),
      ),
    );
  }
}

class _Blank extends StatelessWidget {
  const _Blank();

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest);
}

class _Video extends StatefulWidget {
  const _Video({required this.slide, required this.active});

  final BoardSlide slide;
  final bool active;

  @override
  State<_Video> createState() => _VideoState();
}

class _VideoState extends State<_Video> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_prepare());
  }

  @override
  void didUpdateWidget(covariant _Video old) {
    super.didUpdateWidget(old);
    if (widget.slide.path != old.slide.path) {
      unawaited(_disposeController());
      unawaited(_prepare());
    } else if (widget.active != old.active) {
      _applyPlayState();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_disposeController());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A looping video playing to a screen nobody is looking at is pure cost.
    if (state == AppLifecycleState.resumed) {
      _applyPlayState();
    } else {
      _controller?.pause();
    }
  }

  Future<void> _disposeController() async {
    final c = _controller;
    _controller = null;
    _ready = false;
    await c?.dispose();
  }

  Future<void> _prepare() async {
    final url = widget.slide.url;
    final path = widget.slide.path;
    if (url == null || path == null) return;

    // From disk, always. The download happens once, on the first board that
    // referenced this file; every later launch and every pull-to-refresh reads
    // the same bytes back.
    final File? file = await BoardMediaCache.instance.fileFor(url: url, path: path);
    if (file == null || !mounted) return;

    final controller = VideoPlayerController.file(file);
    try {
      await controller.initialize();
      await controller.setLooping(widget.slide.loop);
      // Muted whenever it starts on its own. Sound that begins without being
      // asked for is startling in a marketplace, and on Android it would
      // interrupt whatever the user is already playing.
      await controller.setVolume(widget.slide.muted || widget.slide.autoplay ? 0 : 1);
    } catch (e) {
      debugPrint('[board] video failed to initialise ($e)');
      await controller.dispose();
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _controller = controller;
      _ready = true;
    });
    _applyPlayState();
  }

  void _applyPlayState() {
    final c = _controller;
    if (c == null || !_ready) return;
    if (widget.active && widget.slide.autoplay) {
      unawaited(c.play());
    } else {
      unawaited(c.pause());
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (!_ready || c == null) {
      // The poster carries the slot until the file is ready — and stays there
      // for good if the video never arrives.
      final poster = widget.slide.posterUrl;
      if (poster == null) return const _Blank();
      return CachedNetworkImage(
        imageUrl: poster,
        fit: BoxFit.cover,
        width: double.infinity,
        placeholder: (_, __) => const _Blank(),
        errorWidget: (_, __, ___) => const _Blank(),
      );
    }
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: c.value.size.width,
        height: c.value.size.height,
        child: VideoPlayer(c),
      ),
    );
  }
}

class _Text extends StatelessWidget {
  const _Text({required this.slide, this.onCategory});
  final BoardSlide slide;
  final void Function(String slug)? onCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final bg = _hex(slide.background) ?? theme.colorScheme.primaryContainer;
    final fg = _hex(slide.foreground) ?? theme.colorScheme.onPrimaryContainer;

    final title = pickLocalised(slide.title, locale);
    final body = pickLocalised(slide.body, locale);
    final cta = pickLocalised(slide.ctaLabel, locale);

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: fg, fontWeight: FontWeight.bold),
            ),
          if (body != null) ...[
            const SizedBox(height: 6),
            Flexible(
              child: Text(
                body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: fg),
              ),
            ),
          ],
          // Real buttons where there are any; the old decorative pill only
          // where there are not, so boards written before buttons existed are
          // untouched.
          if (slide.actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ActionBar(
              actions: slide.actions,
              onMedia: false,
              foreground: fg,
              onCategory: onCategory,
            ),
          ] else if (cta != null) ...[
            const SizedBox(height: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: fg.withValues(alpha: 0.6)),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Text(cta,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: fg, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }

}

/// A slide's own colour, or null when it did not set a usable one.
Color? _hex(String? value) {
  if (value == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) return null;
  return Color(int.parse(value.substring(1), radix: 16) | 0xFF000000);
}

/// Media on one side, words on the other.
class _Split extends StatelessWidget {
  const _Split({required this.slide, this.onCategory});

  final BoardSlide slide;
  final void Function(String slug)? onCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final title = pickLocalised(slide.title, locale);
    final body = pickLocalised(slide.body, locale);

    final content = Row(
      children: [
        // No overlay inside a split: the words already have their own half.
        Expanded(child: _Slide(slide: slide, active: true, onCategory: onCategory, overlay: false)),
        Expanded(
          child: Container(
            color: theme.colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                if (body != null) ...[
                  const SizedBox(height: 4),
                  Flexible(
                    child: Text(body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );

    if (!(slide.link?.isActionable ?? false)) return content;
    return GestureDetector(
      onTap: () => openBoardLink(context, slide.link!, onCategory: onCategory),
      child: content,
    );
  }
}

/// Where a tap on the board goes.
///
/// Each kind reuses the path the rest of the app already takes, so a board link
/// to a listing behaves exactly like a shared link to the same listing.
Future<void> openBoardLink(
  BuildContext context,
  BoardLink link, {
  void Function(String slug)? onCategory,
}) async {
  final value = link.value;
  if (value == null || value.isEmpty) return;

  switch (link.kind) {
    case BoardLinkKind.none:
      return;
    case BoardLinkKind.url:
      // https is enforced when the board is saved; checked again because this
      // value arrived over the network and the check is one line.
      final uri = Uri.tryParse(value);
      if (uri == null || uri.scheme != 'https') return;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    case BoardLinkKind.listing:
      await openSharedListing(value);
    case BoardLinkKind.category:
      onCategory?.call(value);
    case BoardLinkKind.promo:
      final promo = link.promo;
      if (promo == null) return;
      await showBoardPromoSheet(context, promo: promo, onCategory: onCategory);
    case BoardLinkKind.screen:
      // Checked again here, not only when the link was parsed. onGenerateRoute
      // falls through to SplashScreen, which re-roots the navigator — so an
      // unrecognised route would not be a dead button, it would eject whoever
      // tapped it out of whatever they were doing.
      if (!allowedBoardScreens.contains(value)) return;
      await Navigator.of(context, rootNavigator: true).pushNamed(value);
  }
}
