import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'auth_service.dart';
import 'chat_sync.dart' show chatTimeMicros;
import 'offline_cache.dart';

/// One write route and what it does to the saved reads.
class WriteRule {
  const WriteRule(this.name, this._run);

  final String name;
  final void Function(WriteEvent e, List<String> seg) _run;

  void run(WriteEvent e) => _run(e, _segments(e.path));

  static List<String> _segments(String path) {
    final i = path.indexOf('?');
    final p = i < 0 ? path : path.substring(0, i);
    return [for (final s in p.split('/')) if (s.isNotEmpty) s];
  }
}

/// The write hook: after a write succeeds, the saved reads it affects are
/// patched to the confirmed state, marked stale (ETag forgotten) or dropped,
/// so a saved copy never brings back what the person just changed.
///
/// Every write the app sends has a row here; a test scans lib/ and fails on
/// a write path with none. Rules touch the writer's own entries and the
/// shared (`anon`) ones.
///
/// Every OfflineCache call below records its tombstone before its first
/// await, so firing them unawaited is safe: no read that started before the
/// write can save its (possibly older) answer afterwards.
abstract final class CacheRules {
  static void install(ApiClient api) => api.onWrite = apply;

  static final List<(String, RegExp, WriteRule)> _rules = [
    ('POST', RegExp(r'^/listings$'), WriteRule('listing create', (e, _) {
      final u = _uids(e);
      _drop(u, exact: ['/listings'], prefixes: [..._mine(e), '/stores/mine']);
      _staleMe(e);
    })),
    ('PATCH', RegExp(r'^/listings/[^/]+$'), WriteRule('listing edit', (e, seg) {
      final id = seg[1];
      _listingChanged(e, id);
      if (e.request?['action'] == 'mark_sold') {
        OfflineCache.markGone(id);
        _staleMe(e);
      }
    })),
    ('DELETE', RegExp(r'^/listings/[^/]+$'), WriteRule('listing delete', (e, seg) {
      final id = seg[1];
      _listingChanged(e, id);
      OfflineCache.markGone(id);
      _staleMe(e);
      _stale(_uids(e), exact: ['/conversations']);
    })),
    ('POST|PATCH|DELETE', RegExp(r'^/listings/[^/]+/images(/.*)?$'), WriteRule('listing images', (e, seg) {
      final id = seg[1];
      final u = _uids(e);
      _drop(u, prefixes: ['/listings/$id']);
      _drop(u, exact: ['/listings'], bodyContains: '"id":"$id"');
      _drop(u, prefixes: _mine(e));
    })),
    ('POST', RegExp(r'^/favorites/[^/]+$'), WriteRule('favourite add', (e, seg) {
      final id = seg[1];
      final u = _uids(e);
      _patch('/listings/$id', u, (json) => _setFavorited(json, true));
      _stale(u, exact: ['/favorites']);
    })),
    ('DELETE', RegExp(r'^/favorites/[^/]+$'), WriteRule('favourite remove', (e, seg) {
      final id = seg[1];
      final u = _uids(e);
      _patch('/favorites', u, (json) {
        if (json is! Map) return json;
        final items = json['items'];
        if (items is! List) return json;
        return {
          ...json.cast<String, dynamic>(),
          'items': [
            for (final row in items)
              if (!(row is Map &&
                  (row['listing_id']?.toString() == id ||
                      (row['listing'] is Map && (row['listing'] as Map)['id']?.toString() == id))))
                row,
          ],
        };
      });
      _patch('/listings/$id', u, (json) => _setFavorited(json, false));
    })),
    ('POST', RegExp(r'^/stores$'), WriteRule('store create', (e, _) => _storeChanged(e, null))),
    ('PATCH', RegExp(r'^/stores/[^/]+$'), WriteRule('store edit', (e, seg) => _storeChanged(e, seg[1]))),
    ('POST', RegExp(r'^/sellers/[^/]+/reviews$'), WriteRule('seller review', (e, seg) {
      final id = seg[1];
      _drop(_uids(e), exact: ['/users/$id'], prefixes: ['/sellers/$id/reviews']);
    })),
    ('POST', RegExp(r'^/stores/[^/]+/reviews$'), WriteRule('store review', (e, seg) {
      _drop(_uids(e), prefixes: ['/stores/${seg[1]}']);
    })),
    ('POST', RegExp(r'^/conversations$'), WriteRule('conversation start', (e, _) {
      _stale(_uids(e), exact: ['/conversations']);
    })),
    ('POST', RegExp(r'^/conversations/[^/]+/(messages|location)$'), WriteRule('chat send', (e, seg) {
      final cid = seg[1];
      final msg = e.response is Map ? (e.response as Map)['message'] : null;
      final at = msg is Map ? msg['created_at']?.toString() : null;
      if (at == null) {
        _stale(_uids(e), exact: ['/conversations']);
        return;
      }
      _patch('/conversations', _uids(e), (json) => json is Map
          ? patchInbox(json.cast<String, dynamic>(), cid, lastMessageAt: at)
          : json);
    })),
    // ChatRepository patches the stored message itself.
    ('PATCH', RegExp(r'^/conversations/[^/]+/location/[^/]+$'), WriteRule('share move', (_, _) {})),
    ('POST', RegExp(r'^/conversations/[^/]+/location/[^/]+/stop$'), WriteRule('share stop', (_, _) {})),
    ('POST', RegExp(r'^/conversations/[^/]+/read$'), WriteRule('chat read', (e, seg) {
      final cid = seg[1];
      _patch('/conversations', _uids(e), (json) => json is Map
          ? patchInbox(json.cast<String, dynamic>(), cid, readByMe: true)
          : json);
    })),
    ('POST', RegExp(r'^/compliance/appeals$'), WriteRule('appeal', (_, _) {})),
    ('POST', RegExp(r'^/support/thread$'), WriteRule('support thread', (e, _) {
      _stale(_uids(e), exact: ['/conversations']);
    })),
    ('POST', RegExp(r'^/me/notifications/read$'), WriteRule('notifications read', (e, _) {
      final u = _uids(e);
      final unread = e.response is Map ? (e.response as Map)['unread'] : null;
      if (e.request?['all'] == true) {
        final now = DateTime.now().toUtc().toIso8601String();
        _patch('/me/notifications', u, (json) => _markNotifications(json, null, now));
        _patch('/me/notifications/unread', u, (json) => {
              if (json is Map) ...json.cast<String, dynamic>(),
              'unread': 0,
            });
        _drop(u, exact: ['/me/notifications/home']);
        return;
      }
      final ids = <String>{
        for (final id in (e.request?['ids'] as List? ?? const [])) id.toString(),
      };
      if (ids.isEmpty) return;
      final now = DateTime.now().toUtc().toIso8601String();
      _patch('/me/notifications', u, (json) => _markNotifications(json, ids, now));
      if (unread is num) {
        _patch('/me/notifications/unread', u, (json) => {
              if (json is Map) ...json.cast<String, dynamic>(),
              'unread': unread.toInt(),
            });
      } else {
        _stale(u, exact: ['/me/notifications/unread']);
      }
      _patch('/me/notifications/home', u, (json) {
        final n = json is Map ? json['notification'] : null;
        return (n is Map && ids.contains(n['id']?.toString())) ? null : json;
      });
      _drop(u, prefixes: [for (final id in ids) '/me/notifications/$id']);
    })),
    ('PATCH', RegExp(r'^/me$'), WriteRule('profile edit', (e, _) => _profileChanged(e))),
    ('POST', RegExp(r'^/auth/sync$'), WriteRule('profile sync', (e, _) => _profileChanged(e))),
    ('POST', RegExp(r'^/account/request-deletion$'), WriteRule('account deletion', (e, _) => _profileChanged(e))),
    ('POST', RegExp(r'^/referrals/apply$'), WriteRule('referral claim', (e, _) {
      _drop(_uids(e), exact: ['/referrals/me']);
      _staleMe(e);
    })),
    ('POST', RegExp(r'^/orders$'), WriteRule('order create', (e, _) {
      final items = e.request?['items'];
      _drop(_uids(e), exact: ['/orders'], prefixes: [
        if (items is List)
          for (final i in items)
            if (i is Map && i['listing_id'] != null) '/listings/${i['listing_id']}',
      ]);
    })),
    ('POST', RegExp(r'^/orders/[^/]+/(pay|confirm|cancel|fulfil)$'), WriteRule('order action', (e, seg) {
      _drop(_uids(e), exact: ['/orders'], prefixes: ['/orders/${seg[1]}']);
    })),
    // Money reads are never saved.
    ('POST', RegExp(r'^/payouts$'), WriteRule('payout', (_, _) {})),
    ('POST', RegExp(r'^/me/wallet/withdrawals$'), WriteRule('withdrawal', (_, _) {})),
    ('POST', RegExp(r'^/shipping-requests$'), WriteRule('shipping create', (e, _) {
      _drop(_uids(e), exact: ['/shipping-requests']);
      _stale(_uids(e), exact: ['/conversations']);
    })),
    ('POST', RegExp(r'^/shipping-requests/[^/]+/accept$'), WriteRule('shipping accept', (e, seg) {
      _drop(_uids(e), exact: ['/shipping-requests'], prefixes: ['/shipping-requests/${seg[1]}']);
      _stale(_uids(e), exact: ['/conversations']);
    })),
    // Touch nothing the app saves.
    ('POST', RegExp(r'^/uploads/sign$'), WriteRule('upload sign', (_, _) {})),
    ('POST', RegExp(r'^/devices$'), WriteRule('device register', (_, _) {})),
    ('DELETE', RegExp(r'^/devices/[^/]+$'), WriteRule('device remove', (_, _) {})),
    ('POST', RegExp(r'^/reports$'), WriteRule('report', (_, _) {})),
    ('POST', RegExp(r'^/support$'), WriteRule('support message', (_, _) {})),
  ];

  /// The rule for a write, or null when none covers it.
  static WriteRule? ruleFor(String method, String path) {
    final m = method.toUpperCase();
    final i = path.indexOf('?');
    final p = i < 0 ? path : path.substring(0, i);
    for (final r in _rules) {
      if (!r.$1.split('|').contains(m)) continue;
      if (r.$2.hasMatch(p)) return r.$3;
    }
    return null;
  }

  static void apply(WriteEvent e) {
    final rule = ruleFor(e.method, e.path);
    if (rule == null) {
      // Not covered: the conservative answer is to forget the writer's saved
      // reads of that resource and everything under it.
      debugPrint('[cache] no rule for $e');
      final seg = WriteRule._segments(e.path);
      if (seg.isNotEmpty) _drop(_uids(e), prefixes: ['/${seg.first}']);
      return;
    }
    rule.run(e);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  static Set<String> _uids(WriteEvent e) => {e.uid ?? 'anon', 'anon'};

  static List<String> _mine(WriteEvent e) {
    final uid = e.uid;
    return uid == null ? const [] : ['/sellers/$uid', '/users/$uid'];
  }

  static void _drop(Set<String> uids, {List<String> exact = const [], List<String> prefixes = const [],
      String? bodyContains}) {
    if (exact.isEmpty && prefixes.isEmpty) return;
    unawaited(OfflineCache.drop(uids: uids, exact: exact, prefixes: prefixes, bodyContains: bodyContains));
  }

  static void _stale(Set<String> uids, {List<String> exact = const [], List<String> prefixes = const []}) {
    unawaited(OfflineCache.stale(uids: uids, exact: exact, prefixes: prefixes));
  }

  static void _patch(String path, Set<String> uids, Object? Function(Object? json) edit) {
    unawaited(OfflineCache.patch(path, edit, uids: uids));
  }

  /// STALE /me, then fetch it again (only for the account still signed in).
  /// Any /me read that starts after this joins the refetch.
  static void _staleMe(WriteEvent e) {
    _stale(_uids(e), exact: ['/me']);
    if (e.uid == null) return;
    try {
      if (AuthService.instance.userId != e.uid) return;
      unawaited(AuthService.instance.refreshMe().then((_) {}, onError: (_) {}));
    } catch (_) {
      // No auth (tests, or before Supabase is up): the stale mark is enough.
    }
  }

  static void _listingChanged(WriteEvent e, String id) {
    final u = _uids(e);
    _drop(u, prefixes: ['/listings/$id']);
    _drop(u, exact: ['/listings', '/favorites'], bodyContains: '"id":"$id"');
    _drop(u, prefixes: _mine(e));
  }

  static void _storeChanged(WriteEvent e, String? id) {
    _drop(_uids(e), exact: [
      '/stores/mine',
      if (e.uid != null) '/users/${e.uid}',
    ], prefixes: [
      if (id != null) '/stores/$id',
    ]);
    _staleMe(e);
  }

  static void _profileChanged(WriteEvent e) {
    _staleMe(e);
    if (e.uid != null) _drop(_uids(e), exact: ['/users/${e.uid}']);
  }

  static Object? _setFavorited(Object? json, bool value) {
    if (json is! Map) return json;
    final listing = json['listing'];
    if (listing is! Map) return json;
    return {
      ...json.cast<String, dynamic>(),
      'listing': {...listing.cast<String, dynamic>(), 'is_favorited': value},
    };
  }

  /// Marks the saved list's rows read: [ids], or every row when null. The
  /// list's own `unread` follows.
  static Object? _markNotifications(Object? json, Set<String>? ids, String now) {
    if (json is! Map) return json;
    final items = json['items'];
    if (items is! List) return json;
    var newlyRead = 0;
    final next = <Object?>[];
    for (final n in items) {
      if (n is Map && n['read_at'] == null && (ids == null || ids.contains(n['id']?.toString()))) {
        newlyRead++;
        next.add({...n.cast<String, dynamic>(), 'read_at': now});
      } else {
        next.add(n);
      }
    }
    final out = {...json.cast<String, dynamic>(), 'items': next};
    final before = json['unread'];
    if (before is num) {
      final left = ids == null ? 0 : before.toInt() - newlyRead;
      out['unread'] = left < 0 ? 0 : left;
    }
    return out;
  }

  /// Pure. Patches a /conversations body: one thread's last_message_at
  /// (moved forward only), or my unread to 0, or removes it; then re-sorts
  /// (last_message_at desc with nulls last, created_at desc, id asc: the
  /// server's order) and recomputes total_unread.
  static Map<String, dynamic> patchInbox(Map<String, dynamic> body, String cid,
      {String? lastMessageAt, bool readByMe = false, bool remove = false}) {
    final items = [
      for (final m in (body['items'] as List? ?? const []).whereType<Map>()) Map<String, dynamic>.from(m),
    ];
    if (remove) {
      items.removeWhere((m) => m['id']?.toString() == cid);
    } else {
      for (final m in items) {
        if (m['id']?.toString() != cid) continue;
        if (lastMessageAt != null) {
          final current = m['last_message_at']?.toString();
          if (current == null || chatTimeMicros(lastMessageAt) > chatTimeMicros(current)) {
            m['last_message_at'] = lastMessageAt;
          }
        }
        if (readByMe) {
          m['unread'] = 0;
          if (m['role']?.toString() == 'buyer') {
            m['buyer_unread'] = 0;
          } else {
            m['seller_unread'] = 0;
          }
        }
      }
    }
    items.sort(_inboxOrder);
    var total = 0;
    for (final m in items) {
      final u = m['unread'];
      total += u is num ? u.toInt() : int.tryParse(u?.toString() ?? '') ?? 0;
    }
    return {...body, 'items': items, 'total_unread': total};
  }

  static int _t(Object? raw) => raw == null ? 0 : chatTimeMicros(raw.toString());

  static int _inboxOrder(Map<String, dynamic> a, Map<String, dynamic> b) {
    final la = _t(a['last_message_at']);
    final lb = _t(b['last_message_at']);
    if (la != lb) {
      if (la == 0) return 1; // nulls last
      if (lb == 0) return -1;
      return lb.compareTo(la);
    }
    final ca = _t(a['created_at']);
    final cb = _t(b['created_at']);
    if (ca != cb) return cb.compareTo(ca);
    return (a['id']?.toString() ?? '').compareTo(b['id']?.toString() ?? '');
  }
}
