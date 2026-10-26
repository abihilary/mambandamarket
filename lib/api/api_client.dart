import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'app_info.dart';
import 'offline_cache.dart';
import 'read_policy.dart';
import 'read_result.dart';
import '../l10n/l10n.dart';

export 'read_result.dart';

/// A failed API call, carrying the server's machine-readable error code.
class ApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;

  ApiException(this.statusCode, this.code, this.message);

  /// True when the user's plan quota blocked a publish.
  bool get isListingLimit => code == 'listing_limit_reached';
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isRateLimited => statusCode == 429;

  /// The request never got an answer: no connection, DNS or TLS failure, or a
  /// network that blocks the API's address.
  bool get isNetwork => code == 'network';
  bool get isTimeout => code == 'timeout';

  /// Something answered, but not with our API's JSON — most often a public
  /// Wi-Fi sign-in page standing in front of every address.
  bool get isBadResponse => code == 'bad_response';
  bool get isServer => statusCode >= 500;

  /// The thing asked for no longer exists (deleted, or never did).
  bool get isGone => statusCode == 404 || statusCode == 410;

  /// What a saved copy would be standing in for, or null when no saved copy
  /// should be shown: the phone is offline, or the server (or something in
  /// front of it) could not answer properly. A 401, 403 or 500 is a real
  /// answer and is not papered over.
  SavedReason? get savedReason => (isNetwork || isTimeout)
      ? SavedReason.offline
      : (isBadResponse || statusCode == 502 || statusCode == 503 || statusCode == 504)
          ? SavedReason.serverUnavailable
          : null;

  /// A short tag a tester can quote back to us ("network", "timeout",
  /// "http 502"), so a screenshot of an error says which one it was.
  String get reference => statusCode <= 0
      ? code
      : code.startsWith('http_')
          ? 'http $statusCode'
          : '$code · http $statusCode';

  @override
  String toString() => message;
}

/// Thin JSON client for the Core API.
///
/// Attaches the current Supabase access token to every request, so the API and
/// its Row-Level Security policies see the real caller. There is no secret key
/// in the app — the server authorizes everything.
///
/// Reads go through [read], which keeps the answers [ReadPolicy] says to keep
/// in [OfflineCache], revalidates them with If-None-Match (a 304 costs no
/// body), and stands a saved copy in for a network that is not there. Writes
/// are never saved or queued; after one succeeds, [onWrite] (installed by
/// CacheRules) patches or drops the saved reads it affected.
class ApiClient {
  ApiClient._()
      : _http = http.Client(),
        _userIdOf = _supabaseUserId,
        _tokenOf = _supabaseToken,
        _timeout = const Duration(seconds: 30),
        _fallbackTimeout = const Duration(seconds: 15),
        _web = kIsWeb;
  static final ApiClient instance = ApiClient._();

  /// [web] stands in for kIsWeb, so a test can check what the web build
  /// sends.
  @visibleForTesting
  ApiClient.test({
    required http.Client client,
    String? Function()? userId,
    String? Function()? token,
    Duration? timeout,
    Duration? fallbackTimeout,
    bool? web,
  })  : _http = client,
        _userIdOf = userId ?? (() => null),
        _tokenOf = token ?? (() => null),
        _timeout = timeout ?? const Duration(seconds: 30),
        _fallbackTimeout = fallbackTimeout ?? const Duration(seconds: 15),
        _web = web ?? kIsWeb;

  final http.Client _http;
  final String? Function() _userIdOf;
  final String? Function() _tokenOf;

  /// The web build: its policies never send If-None-Match (see
  /// [ReadPolicy.of]).
  final bool _web;

  /// Long enough for a slow mobile connection, short enough that a hung
  /// request ends in a message and a retry button rather than a spinner that
  /// never stops.
  final Duration _timeout;

  /// For a read that has a saved copy to fall back to. Shorter, because the
  /// person is already looking at something; long enough that a changed
  /// 40 KB feed still arrives over GPRS (about 5 KB/s), or such a phone
  /// would sit on the saved copy forever. A 304 is tiny and well inside it.
  final Duration _fallbackTimeout;

  /// Called after every write that succeeded. Set by `CacheRules.install`.
  void Function(WriteEvent e)? onWrite;

  static String? _supabaseUserId() => Supabase.instance.client.auth.currentUser?.id;
  static String? _supabaseToken() => Supabase.instance.client.auth.currentSession?.accessToken;

  Map<String, String> _headers() {
    final token = _tokenOf();
    // Which build is talking. Cheap telemetry the server can log, and the
    // precondition for ever raising the supported floor: without it nobody
    // knows what people are actually running.
    final info = AppInfo.cached;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      if (info != null) 'X-App-Build': info.buildNumber,
      if (info != null) 'X-App-Version': info.version,
      'X-App-Platform': AppInfo.platform,
    };
  }

  static Map<String, String> _clean(Map<String, dynamic>? query) {
    final out = <String, String>{};
    query?.forEach((k, v) {
      final s = v?.toString();
      if (s != null && s.isNotEmpty) out[k] = s;
    });
    return out;
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final cleaned = _clean(query);
    return Uri.parse('${AppConfig.apiBaseUrl}$path').replace(
      queryParameters: cleaned.isEmpty ? null : cleaned,
    );
  }

  /// `/trending?category=x` and `/shipping/quote?…` are built by hand; the
  /// policy and the saved key need the path and the query apart.
  static (String, Map<String, String>) _split(String path, Map<String, dynamic>? query) {
    var p = path;
    final merged = <String, dynamic>{};
    final i = path.indexOf('?');
    if (i >= 0) {
      p = path.substring(0, i);
      merged.addAll(Uri.splitQueryString(path.substring(i + 1)));
    }
    if (query != null) merged.addAll(query);
    return (p, _clean(merged));
  }

  /// Runs one request and turns every way it can fail *before* a response
  /// arrives into an [ApiException], so screens can say which failure it was
  /// instead of calling everything a connection problem.
  Future<http.Response> _send(Future<http.Response> Function() call, {Duration? timeout}) async {
    try {
      return await call().timeout(timeout ?? _timeout);
    } on TimeoutException {
      throw ApiException(0, 'timeout', l10nNow.errorTimeout);
    } catch (e) {
      debugPrint('API transport error: $e');
      throw ApiException(0, 'network', l10nNow.connectionError);
    }
  }

  dynamic _decode(http.Response res) {
    dynamic body;
    var parsed = true;
    try {
      body = res.body.isEmpty ? null : jsonDecode(res.body);
    } on FormatException {
      parsed = false;
    }
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    if (ok && parsed) return body;
    if (ok) {
      // A 200 that is not JSON did not come from the API.
      debugPrint('API non-JSON 2xx: ${res.body.length} bytes');
      throw ApiException(res.statusCode, 'bad_response', l10nNow.errorBadResponse);
    }

    final err = (body is Map ? body['error'] : null) as Map?;
    throw ApiException(
      res.statusCode,
      err?['code']?.toString() ?? 'http_${res.statusCode}',
      // The API always sends a message; this is the fallback for the times it
      // cannot — a gateway 502 with an HTML body, say — which is exactly when
      // a user is looking at the error.
      err?['message']?.toString() ??
          (res.statusCode >= 500
              ? l10nNow.errorServer
              : l10nNow.apiRequestFailed(res.statusCode)),
    );
  }

  /// A read, with where its answer came from.
  ///
  /// - A saved copy with an ETag is revalidated: a 304 answers with the saved
  ///   body ([ReadSource.notModified]) and costs no download.
  /// - A 200 replaces the saved copy, unless a write on this device covered
  ///   the same ground while it was in flight; then the read is sent once
  ///   more, since the first answer may predate the write.
  /// - No connection, a timeout, a gateway error or a captive-portal page
  ///   answers with the saved copy when there is one young enough
  ///   ([ReadSource.saved], with a [SavedReason]); otherwise it throws the
  ///   same [ApiException] as before.
  /// - A 404 or 410 drops the saved copy and throws ([ApiException.isGone]).
  Future<ApiRead> read(String path, {Map<String, dynamic>? query}) async {
    final (p, q) = _split(path, query);
    final uid = _userIdOf();
    final policy = ReadPolicy.of(p, q, uid: uid, web: _web);
    final ctx = _ReadCtx(
      path: p,
      uri: _uri(p, q),
      policy: policy,
      key: policy.save ? OfflineCache.keyFor(uid, p, q) : null,
      gen: OfflineCache.generation,
    );
    return _attempt(ctx, first: true);
  }

  Future<ApiRead> _attempt(_ReadCtx c, {required bool first}) async {
    final key = c.key;
    final start = OfflineCache.epoch;
    final saved = key == null ? null : OfflineCache.entry(key);
    final fallback = c.policy.fallback;
    final eligible = saved != null && fallback != null && saved.age <= fallback;
    final headers = _headers();
    // Never on web, whatever the policy table says (see ReadPolicy.of).
    final cond = first && !_web && c.policy.conditional && saved?.etag != null;
    if (cond) headers['If-None-Match'] = saved!.etag!;

    // Only a saved copy of the account that asked, and only while it is still
    // signed in, may stand in for the network; and only one that still parses.
    dynamic savedBody;
    bool canFallBack() {
      if (!eligible || OfflineCache.generation != c.gen) return false;
      try {
        savedBody = jsonDecode(saved.body);
        return true;
      } catch (_) {
        return false;
      }
    }

    ApiRead fromSaved(SavedReason reason) {
      OfflineCache.showingSaved.value = true;
      return ApiRead(
        body: savedBody,
        raw: saved!.body,
        source: ReadSource.saved,
        savedReason: reason,
        generation: c.gen,
      );
    }

    final http.Response res;
    try {
      res = await _send(() => _http.get(c.uri, headers: headers),
          timeout: eligible ? _fallbackTimeout : _timeout);
    } on ApiException catch (e) {
      if (kDebugMode) debugPrint('[api] GET ${c.path} ${e.code}${cond ? ' cond' : ''}${first ? '' : ' retry'}');
      if (canFallBack() && (e.isNetwork || e.isTimeout)) return fromSaved(SavedReason.offline);
      rethrow;
    }
    if (kDebugMode) {
      debugPrint('[api] GET ${c.path} ${res.statusCode} ${res.bodyBytes.length}B'
          '${cond ? ' cond' : ''}${first ? '' : ' retry'}');
    }

    final status = res.statusCode;
    if (status == 502 || status == 503 || status == 504) {
      if (canFallBack()) return fromSaved(SavedReason.serverUnavailable);
      _decode(res); // throws
    }

    // The account changed while this was in flight: hand the answer back
    // as-is, marked not current, and keep nothing.
    if (OfflineCache.generation != c.gen) {
      if (status == 304) throw ApiException(304, 'http_304', l10nNow.errorServer);
      final body = _decode(res);
      return ApiRead(body: body, raw: res.body, source: ReadSource.network, generation: c.gen);
    }

    if (status == 304 && key != null) {
      final current = OfflineCache.entry(key);
      if (current == null || (first && OfflineCache.supersededSince(key, start))) {
        // Dropped or changed while in flight: ask again without a condition.
        if (first) return _attempt(c, first: false);
        throw ApiException(304, 'http_304', l10nNow.errorServer);
      }
      final dynamic body;
      try {
        body = jsonDecode(current.body);
      } catch (_) {
        await OfflineCache.remove(key);
        if (first) return _attempt(c, first: false);
        rethrow;
      }
      unawaited(OfflineCache.touch(key, etag: res.headers['etag'] ?? current.etag, startedEpoch: start));
      OfflineCache.showingSaved.value = false;
      return ApiRead(body: body, raw: current.body, source: ReadSource.notModified, generation: c.gen);
    }

    if ((status == 404 || status == 410) && key != null) {
      unawaited(OfflineCache.remove(key));
    }

    final dynamic body;
    try {
      body = _decode(res); // throws on an error status, which is not saved
    } on ApiException catch (e) {
      if (e.isBadResponse && canFallBack()) return fromSaved(SavedReason.serverUnavailable);
      rethrow;
    }

    if (key != null && OfflineCache.supersededSince(key, start)) {
      if (first) return _attempt(c, first: false);
      OfflineCache.showingSaved.value = false;
      return ApiRead(body: body, raw: res.body, source: ReadSource.network, generation: c.gen, superseded: true);
    }
    if (c.policy.save && key != null) {
      unawaited(OfflineCache.put(key, res.body,
          etag: res.headers['etag'], pinned: c.policy.pinned, startedEpoch: start));
    }
    OfflineCache.showingSaved.value = false;
    return ApiRead(body: body, raw: res.body, source: ReadSource.network, generation: c.gen);
  }

  /// The saved copy of this read, synchronously, for a first paint: null when
  /// there is none, when its route is never painted first, or when the server
  /// last confirmed it longer ago than the route allows.
  SavedRead? saved(String path, {Map<String, dynamic>? query}) {
    if (!OfflineCache.available) return null;
    try {
      final (p, q) = _split(path, query);
      final uid = _userIdOf();
      final policy = ReadPolicy.of(p, q, uid: uid, web: _web);
      final paint = policy.paint;
      if (!policy.save || paint == null) return null;
      final key = OfflineCache.keyFor(uid, p, q);
      if (key == null) return null;
      final e = OfflineCache.entry(key);
      if (e == null || e.age > paint) return null;
      return SavedRead(
        body: jsonDecode(e.body),
        raw: e.body,
        validatedAt: DateTime.fromMillisecondsSinceEpoch(e.validatedAt),
      );
    } catch (_) {
      return null;
    }
  }

  /// A read, as today: the decoded body (saved, revalidated or fresh).
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async =>
      (await read(path, query: query)).body;

  /// A change. Never answered from the cache and never queued: a message or a
  /// purchase replayed later from a stale screen is worse than being told it
  /// did not go. With no connection, the message says so plainly.
  Future<http.Response> _sendChange(Future<http.Response> Function() call) async {
    try {
      return await _send(call);
    } on ApiException catch (e) {
      if (e.isNetwork) throw ApiException(0, 'network', l10nNow.offlineChangeNotSaved);
      rethrow;
    }
  }

  void _wrote(String method, String path, Map<String, dynamic>? request, dynamic response, String? uid) {
    final hook = onWrite;
    if (hook == null) return;
    try {
      hook(WriteEvent(method, path, request, response, uid));
    } catch (e, stack) {
      // The write itself went through; a saved read left as it was is the
      // worst that can happen here, and the next read corrects it.
      debugPrint('[cache] write hook failed for $method $path: $e');
      debugPrintStack(stackTrace: stack, label: '[cache]');
    }
  }

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    final uid = _userIdOf();
    final out = _decode(await _sendChange(() => _http.post(_uri(path),
        headers: _headers(), body: jsonEncode(body ?? {}))));
    _wrote('POST', path, body, out, uid);
    return out;
  }

  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) async {
    final uid = _userIdOf();
    final out = _decode(await _sendChange(() => _http.patch(_uri(path),
        headers: _headers(), body: jsonEncode(body ?? {}))));
    _wrote('PATCH', path, body, out, uid);
    return out;
  }

  Future<dynamic> delete(String path) async {
    final uid = _userIdOf();
    final out = _decode(await _sendChange(() => _http.delete(_uri(path), headers: _headers())));
    _wrote('DELETE', path, null, out, uid);
    return out;
  }
}

class _ReadCtx {
  _ReadCtx({required this.path, required this.uri, required this.policy, required this.key, required this.gen});

  final String path;
  final Uri uri;
  final ReadPolicy policy;
  final String? key;
  final int gen;
}
