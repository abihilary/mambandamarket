import 'package:flutter/foundation.dart';

import 'remote_config.dart';

/// What the device may do with one kind of read: keep it, revalidate it with
/// an ETag, paint it before the network answers, stand it in for a network
/// that is not there.
///
/// One table for the whole app (see [of]), so a new route is not saved until
/// somebody decides it should be: the default is [none].
class ReadPolicy {
  const ReadPolicy({
    this.save = false,
    this.conditional = false,
    this.pinned = false,
    this.paint,
    this.fallback,
    this.actionsOffWhenSaved = false,
  });

  /// Keep the body on the device.
  final bool save;

  /// Send If-None-Match with the saved ETag. Needs [save]: a 304 is answered
  /// with the saved body.
  final bool conditional;

  /// Pruned last.
  final bool pinned;

  /// A saved-first paint is allowed within this age of the last time the
  /// server confirmed the copy. Null: never painted before the network.
  final Duration? paint;

  /// A network or server failure falls back to the saved copy within this
  /// age. Null: no fallback.
  final Duration? fallback;

  /// A screen showing this from the device must switch its actions off (an
  /// order's Pay, Confirm, Cancel).
  final bool actionsOffWhenSaved;

  static const none = ReadPolicy();

  ReadPolicy _withoutCondition() => ReadPolicy(
        save: save,
        pinned: pinned,
        paint: paint,
        fallback: fallback,
        actionsOffWhenSaved: actionsOffWhenSaved,
      );

  /// The policy for one read. [query] is the cleaned query (no null or empty
  /// values). [uid] is the signed-in account, which decides whether a
  /// seller's pages are "mine" (pinned).
  ///
  /// The web build never revalidates, on any route and whatever /config
  /// says: Vercel's edge answers If-None-Match itself, and its 304s drop
  /// Access-Control-Allow-Origin, so the browser would reject every one of
  /// them as a CORS failure. Web still saves bodies and paints them first;
  /// it just always asks for the full answer.
  static ReadPolicy of(String path, Map<String, String> query, {String? uid, bool web = kIsWeb}) {
    var p = _lookup(path, query, uid, web);
    if (p.conditional && (web || !_conditionalAllowed())) p = p._withoutCondition();
    return p;
  }

  static bool _conditionalAllowed() {
    try {
      return RemoteConfig.instance.conditionalRequests;
    } catch (_) {
      return true;
    }
  }

  static ReadPolicy _lookup(String path, Map<String, String> query, String? uid, bool web) {
    for (final r in _rules) {
      final m = r.$1.firstMatch(path);
      if (m != null) return r.$2(m, query, uid, web);
    }
    return none;
  }

  static const _d1 = Duration(days: 1);
  static const _d3 = Duration(days: 3);
  static const _d7 = Duration(days: 7);
  static const _d14 = Duration(days: 14);
  static const _d30 = Duration(days: 30);
  static const _d90 = Duration(days: 90);

  /// Fallback only: saved, revalidated, never painted first.
  static ReadPolicy _fb(Duration fallback, {bool pinned = false, bool conditional = true}) =>
      ReadPolicy(save: true, conditional: conditional, fallback: fallback, pinned: pinned);

  static ReadPolicy _first(Duration paint, Duration fallback, {bool pinned = false, bool conditional = true}) =>
      ReadPolicy(save: true, conditional: conditional, paint: paint, fallback: fallback, pinned: pinned);

  static final List<(RegExp, ReadPolicy Function(Match m, Map<String, String> q, String? uid, bool web))> _rules = [
    (RegExp(r'^/config$'), (_, _, _, _) => none),
    // Edge-cached and public: on web the browser and the CDN already answer
    // it, and a conditional request from a page would bypass them.
    (RegExp(r'^/categories$'), (_, _, _, web) => _first(_d30, _d90, pinned: true, conditional: !web)),
    (RegExp(r'^/me$'), (_, _, _, _) => _first(_d30, _d90, pinned: true)),
    (RegExp(r'^/favorites$'), (_, _, _, _) => _first(_d14, _d30, pinned: true)),
    // The browse feed. A search or a later page is a new address every time,
    // and is not worth keeping.
    (RegExp(r'^/listings$'), (_, q, _, _) {
      final offset = int.tryParse(q['offset'] ?? '0') ?? 0;
      return (q.containsKey('q') || offset > 0) ? none : _first(_d3, _d14);
    }),
    (RegExp(r'^/listings/[^/]+$'), (_, _, _, _) => _first(_d3, _d14)),
    (RegExp(r'^/listings/[^/]+/related$'), (_, _, _, _) => _first(_d1, _d7)),
    (RegExp(r'^/listings/[^/]+/images$'), (_, _, _, _) => _fb(_d7)),
    (RegExp(r'^/sellers/([^/]+)/dashboard$'), (m, _, uid, _) => _first(_d14, _d30, pinned: m.group(1) == uid)),
    (RegExp(r'^/sellers/([^/]+)/(listings|sales)$'), (m, _, uid, _) => _fb(_d30, pinned: m.group(1) == uid)),
    (RegExp(r'^/stores/mine$'), (_, _, _, _) => _fb(_d30, pinned: true)),
    (RegExp(r'^/stores/[^/]+(/reviews)?$'), (_, _, _, _) => _fb(_d14)),
    (RegExp(r'^/users/[^/]+$'), (_, _, _, _) => _fb(_d14)),
    (RegExp(r'^/conversations$'), (_, _, _, _) => _first(_d30, _d30, pinned: true)),
    // Messages live in ChatStore, which knows how to fetch only what is new.
    (RegExp(r'^/conversations/[^/]+/messages$'), (_, _, _, _) => none),
    (RegExp(r'^/conversations/[^/]+$'), (_, _, _, _) => _fb(_d30)),
    (RegExp(r'^/me/notifications$'), (_, q, _, _) =>
        q.containsKey('before') ? none : _first(_d14, _d30, pinned: true)),
    (RegExp(r'^/me/notifications/unread$'), (_, _, _, _) => _first(_d14, _d30, pinned: true)),
    (RegExp(r'^/me/notifications/home$'), (_, _, _, _) => _first(_d1, _d1)),
    (RegExp(r'^/me/notifications/[^/]+$'), (_, _, _, _) => _fb(_d30)),
    // Money is never shown from the device.
    (RegExp(r'^/(me/wallet|wallet|wallet/entries|payouts)$'), (_, _, _, _) => none),
    // A shared browser keeps no orders.
    (RegExp(r'^/orders$'), (_, q, _, web) {
      final role = q['role'];
      final buyer = role == null || role == 'buyer';
      return (web || !buyer || q.containsKey('before')) ? none : _fb(_d30);
    }),
    (RegExp(r'^/orders/[^/]+$'), (_, _, _, web) => web
        ? none
        : const ReadPolicy(save: true, conditional: true, fallback: _d30, actionsOffWhenSaved: true)),
    (RegExp(r'^/referrals/me$'), (_, _, _, _) => _fb(_d30)),
    // Its own design: no cold-start copy, a decaying score.
    (RegExp(r'^/trending$'), (_, _, _, _) => none),
    (RegExp(r'^/shipping/options$'), (_, _, _, web) => _fb(_d30, conditional: !web)),
    // Prices are never served from the device.
    (RegExp(r'^/shipping/quote$'), (_, _, _, _) => none),
    // The GET has a side effect.
    (RegExp(r'^/shipping-requests/[^/]+/documents$'), (_, _, _, _) => none),
    // Signed photo URLs change on every answer: no ETag to match.
    (RegExp(r'^/shipping-requests(/[^/]+)?$'), (_, _, _, _) => _fb(_d30, conditional: false)),
    (RegExp(r'^/boards/[^/]+$'), (_, _, _, _) => _fb(_d30)),
  ];
}
