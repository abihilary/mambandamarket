import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
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
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
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

  dynamic _decode(http.Response res) {
    final body = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;

    final err = (body is Map ? body['error'] : null) as Map?;
    throw ApiException(
      res.statusCode,
      err?['code']?.toString() ?? 'http_${res.statusCode}',
      // The API always sends a message; this is the fallback for the times it
      // cannot — a gateway 502 with an HTML body, say — which is exactly when
      // a user is looking at the error.
      err?['message']?.toString() ?? l10nNow.apiRequestFailed(res.statusCode),
    );
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async =>
      _decode(await _http.get(_uri(path, query), headers: _headers()));

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async =>
      _decode(await _http.post(_uri(path),
          headers: _headers(), body: jsonEncode(body ?? {})));

  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) async =>
      _decode(await _http.patch(_uri(path),
          headers: _headers(), body: jsonEncode(body ?? {})));

  Future<dynamic> delete(String path) async =>
      _decode(await _http.delete(_uri(path), headers: _headers()));
}
