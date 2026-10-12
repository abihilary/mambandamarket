import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'app_info.dart';
import '../l10n/l10n.dart';

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
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  final http.Client _http = http.Client();

  Map<String, String> _headers() {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
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

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final cleaned = query?.map((k, v) => MapEntry(k, v?.toString()))
      ?..removeWhere((_, v) => v == null || v.isEmpty);
    return Uri.parse('${AppConfig.apiBaseUrl}$path').replace(
      queryParameters: (cleaned == null || cleaned.isEmpty)
          ? null
          : cleaned.cast<String, String>(),
    );
  }

  /// Long enough for a slow mobile connection, short enough that a hung
  /// request ends in a message and a retry button rather than a spinner that
  /// never stops.
  static const Duration _timeout = Duration(seconds: 30);

  /// Runs one request and turns every way it can fail *before* a response
  /// arrives into an [ApiException], so screens can say which failure it was
  /// instead of calling everything a connection problem.
  Future<http.Response> _send(Future<http.Response> Function() call) async {
    try {
      return await call().timeout(_timeout);
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

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async =>
      _decode(await _send(() => _http.get(_uri(path, query), headers: _headers())));

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async =>
      _decode(await _send(() => _http.post(_uri(path),
          headers: _headers(), body: jsonEncode(body ?? {}))));

  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) async =>
      _decode(await _send(() => _http.patch(_uri(path),
          headers: _headers(), body: jsonEncode(body ?? {}))));

  Future<dynamic> delete(String path) async =>
      _decode(await _send(() => _http.delete(_uri(path), headers: _headers())));
}
