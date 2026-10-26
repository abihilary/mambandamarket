import 'offline_cache.dart';

/// Where the answer to a read came from.
///
/// [network]: the server sent a body. [notModified]: the server said the copy
/// on this device is still right (a 304, no body). [saved]: the server could
/// not be asked, and the copy on this device stands in for it.
enum ReadSource { network, notModified, saved }

/// Why a saved copy is on screen instead of a fresh one. Decides the wording
/// of the note above it: "you're offline" is not true when the phone is online
/// and the server is the one in trouble.
enum SavedReason { offline, serverUnavailable }

/// Equal stamps mean equal content, within one run of the app. Cheap, and
/// never written anywhere: `String.hashCode` is not stable across runs.
String stampOf(String raw) => '${raw.length}:${raw.hashCode}';

/// One read through [ApiClient.read].
class ApiRead {
  ApiRead({
    required this.body,
    required this.raw,
    required this.source,
    required this.generation,
    this.savedReason,
    this.superseded = false,
  });

  /// The decoded JSON.
  final dynamic body;

  /// The body exactly as it was sent (or saved).
  final String raw;
  final ReadSource source;

  /// Non-null exactly when [source] is [ReadSource.saved].
  final SavedReason? savedReason;

  /// A write on this device changed what this read covers while it was in
  /// flight, twice in a row. The body is the server's, but it was not saved.
  final bool superseded;

  /// [OfflineCache.generation] when the read started.
  final int generation;

  /// False once the signed-in account changed after the read started: the
  /// answer belongs to the previous account and must not reach the screen.
  bool get isCurrent => generation == OfflineCache.generation;

  bool get isSaved => source == ReadSource.saved;
  String get stamp => stampOf(raw);
}

/// A saved copy, read synchronously for a first paint.
class SavedRead {
  SavedRead({
    required this.body,
    required this.raw,
    required this.validatedAt,
  });

  final dynamic body;
  final String raw;

  /// When the server last confirmed this copy (a 200 or a 304).
  final DateTime validatedAt;
  String get stamp => stampOf(raw);
}

/// A saved-first paint, already parsed.
class Saved<T> {
  const Saved({required this.value, required this.stamp, required this.validatedAt});

  final T value;

  /// Compare with the [Fetched.stamp] that follows: equal means nothing to
  /// repaint.
  final String stamp;
  final DateTime validatedAt;
}

/// A read's result, already parsed.
class Fetched<T> {
  const Fetched({
    required this.value,
    required this.source,
    required this.stamp,
    required this.generation,
    this.savedReason,
  });

  /// [value] parsed from [r], keeping its source, stamp and account.
  Fetched.of(ApiRead r, this.value, {String? stamp})
      : source = r.source,
        savedReason = r.savedReason,
        stamp = stamp ?? r.stamp,
        generation = r.generation;

  final T value;
  final ReadSource source;

  /// Non-null exactly when [source] is [ReadSource.saved].
  final SavedReason? savedReason;

  /// Equal stamp = same content as what was painted.
  final String stamp;
  final int generation;

  /// False: the account changed mid-flight; ignore this result.
  bool get isCurrent => generation == OfflineCache.generation;
  bool get isSaved => source == ReadSource.saved;
}

/// A write that succeeded, handed to [CacheRules] so the saved reads it
/// affects are patched, marked stale or dropped.
class WriteEvent {
  const WriteEvent(this.method, this.path, this.request, this.response, this.uid);

  /// POST | PATCH | DELETE.
  final String method;
  final String path;
  final Map<String, dynamic>? request;
  final dynamic response;

  /// Who was signed in when the write was sent.
  final String? uid;

  @override
  String toString() => '$method $path';
}

/// One read at a time: a call while one is running shares it, unless a write
/// (or an account switch) bumped [OfflineCache.epoch] since it started; then
/// the shared answer might predate the change, and a new read starts.
class Inflight<T> {
  Future<T>? _running;
  int _epoch = -1;

  Future<T> run(Future<T> Function() f) {
    final running = _running;
    if (running != null && _epoch == OfflineCache.epoch) return running;
    _epoch = OfflineCache.epoch;
    late final Future<T> future;
    future = f().whenComplete(() {
      if (identical(_running, future)) _running = null;
    });
    _running = future;
    return future;
  }

  void reset() => _running = null;
}
