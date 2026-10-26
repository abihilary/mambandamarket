import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'models.dart';

/// The inbox and the number on the bell.
///
/// Chat has its own unread count (see ChatRepository); this is everything
/// else the platform says to a person — a parcel that moved, an order that was
/// paid, a note from the desk, an offer. The rows live on the server; this
/// keeps the last page and the unread count where the bell and the list can
/// listen to them.
class NotificationRepository {
  NotificationRepository._();
  static final NotificationRepository instance = NotificationRepository._();

  final _api = ApiClient.instance;

  final ValueNotifier<int> unread = ValueNotifier(0);
  final ValueNotifier<List<AppNotification>> items = ValueNotifier(const []);

  /// The announcement floating on Home, if Mambanda published one for this
  /// person (a campaign with "Float on Home"). Closing it marks it read, which
  /// is what keeps it closed on every device and clears it from the bell.
  final ValueNotifier<AppNotification?> homeCard = ValueNotifier(null);

  /// A card whose `home_until` has passed is not shown from the device: the
  /// server would no longer send it.
  static bool _stillDue(AppNotification n) {
    final raw = n.data['home_until'];
    if (raw == null || raw.isEmpty) return true;
    final until = DateTime.tryParse(raw);
    return until == null || until.isAfter(DateTime.now());
  }

  static AppNotification? _homeOf(Object? json, {required bool saved}) {
    final n = json is Map ? json['notification'] : null;
    if (n is! Map) return null;
    final card = AppNotification.fromJson(Map<String, dynamic>.from(n));
    return (saved && !_stillDue(card)) ? null : card;
  }

  Future<void> refreshHomeCard() async {
    try {
      final r = await _api.read('/me/notifications/home');
      if (!r.isCurrent) return;
      homeCard.value = _homeOf(r.body, saved: r.isSaved);
    } catch (_) {
      // Offline, or signed out: no card is the right answer to both.
    }
  }

  /// The list, the badge and the home card from the device, at launch.
  void restore() {
    final list = _api.saved('/me/notifications', query: {'limit': '30'});
    final body = list?.body;
    if (body is Map) {
      items.value = (body['items'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
      unread.value = (body['unread'] as num?)?.toInt() ?? unread.value;
      _nextBefore = body['next_before']?.toString();
      _exhausted = _nextBefore == null;
    }
    final count = _api.saved('/me/notifications/unread')?.body;
    if (count is Map && count['unread'] is num) unread.value = (count['unread'] as num).toInt();
    final home = _api.saved('/me/notifications/home');
    if (home != null) homeCard.value = _homeOf(home.body, saved: true);
  }

  Future<void> dismissHomeCard() async {
    final n = homeCard.value;
    if (n == null) return;
    homeCard.value = null;
    await markRead([n.id]);
  }

  /// Whether the last [refresh] reached the end of the list.
  bool _exhausted = false;
  String? _nextBefore;
  Future<void>? _inflight;

  bool get canLoadMore => !_exhausted && _nextBefore != null;

  /// First page, replacing what is held. Cheap enough to call on resume.
  Future<void> refresh() {
    final running = _inflight;
    if (running != null) return running;
    final f = _refresh().whenComplete(() => _inflight = null);
    _inflight = f;
    return f;
  }

  /// One row in full — a tap on the shade only carries the id.
  Future<AppNotification> fetch(String id) async {
    final json = await _api.get('/me/notifications/$id') as Map<String, dynamic>;
    return AppNotification.fromJson(Map<String, dynamic>.from(json['notification'] as Map));
  }

  Future<void> _refresh() async {
    final r = await _api.read('/me/notifications', query: {'limit': '30'});
    if (!r.isCurrent) return;
    final json = r.body as Map<String, dynamic>;
    final list = (json['items'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
    items.value = list;
    unread.value = (json['unread'] as num?)?.toInt() ?? 0;
    _nextBefore = json['next_before']?.toString();
    _exhausted = _nextBefore == null;
  }

  Future<void> loadMore() async {
    final before = _nextBefore;
    if (before == null || _exhausted) return;
    final json = await _api.get('/me/notifications', query: {'limit': '30', 'before': before}) as Map<String, dynamic>;
    final more = (json['items'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
    items.value = [...items.value, ...more];
    _nextBefore = json['next_before']?.toString();
    _exhausted = _nextBefore == null;
  }

  /// Just the count — what the shell's sweep and a foreground push call.
  Future<void> refreshUnread() async {
    try {
      final r = await _api.read('/me/notifications/unread');
      if (!r.isCurrent) return;
      final json = r.body as Map<String, dynamic>;
      unread.value = (json['unread'] as num?)?.toInt() ?? unread.value;
    } catch (_) {
      // Offline. The next sweep tries again.
    }
  }

  /// Mark some read. The list and the badge move immediately; the server is
  /// told after, and corrected from if it disagrees.
  Future<void> markRead(Iterable<String> ids) async {
    final set = ids.toSet();
    if (set.isEmpty) return;
    var newlyRead = 0;
    items.value = items.value.map((n) {
      if (set.contains(n.id) && n.isUnread) {
        newlyRead++;
        return n.markRead();
      }
      return n;
    }).toList(growable: false);
    if (newlyRead > 0) unread.value = (unread.value - newlyRead).clamp(0, 1 << 30);
    try {
      final json = await _api.post('/me/notifications/read', {'ids': set.toList()}) as Map<String, dynamic>;
      unread.value = (json['unread'] as num?)?.toInt() ?? unread.value;
    } catch (_) {
      // Shown as read already; the next refresh reconciles.
    }
  }

  Future<void> markAllRead() async {
    items.value = items.value.map((n) => n.isUnread ? n.markRead() : n).toList(growable: false);
    unread.value = 0;
    try {
      await _api.post('/me/notifications/read', {'all': true});
    } catch (_) {}
  }

  /// Sign-out. Nothing here belongs to the next person.
  void clear() {
    items.value = const [];
    homeCard.value = null;
    unread.value = 0;
    _nextBefore = null;
    _exhausted = false;
    _inflight = null;
  }
}
