import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flixie_app/core/utils/app_logger.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? code;

  const ApiException({
    required this.statusCode,
    required this.message,
    this.code,
  });

  @override
  String toString() =>
      'ApiException($statusCode${code == null ? '' : ', $code'}): $message';
}

class ApiClient {
  // static const String baseUrl = String.fromEnvironment(
  //   'API_BASE_URL',
  //   defaultValue: 'http://localhost:3000',
  // );

  // static const String baseUrl = String.fromEnvironment(
  //   'API_BASE_URL',
  //   defaultValue: 'http://192.168.1.203:3000',
  // );

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue:
        'https://flixie-api-fmcehvaecwdheccm.northeurope-01.azurewebsites.net',
  );

  static const Duration _timeout = Duration(seconds: 15);

  /// Maximum number of automatic retries when the server returns a 500
  /// DATABASE_ERROR response (Supabase overload).
  static const int _maxRetries = 2;

  /// Back-off delays between consecutive retry attempts.
  static const List<Duration> _retryDelays = [
    Duration(milliseconds: 600),
    Duration(milliseconds: 1200),
  ];

  /// In-flight GET requests keyed by "<auth|anon>:<uri>".
  /// Concurrent callers for the same URL share a single network request,
  /// which prevents the common "N widgets fetch the same endpoint in the
  /// same frame" pattern that puts unnecessary load on Supabase.
  static final Map<String, Future<dynamic>> _inFlightGets = {};

  static String? _token;

  static void setToken(String? token) {
    _token = token;
    if (token != null) {
      apiLogger.d('Token set');
    } else {
      apiLogger.d('Token cleared');
      // Clear deduplication state on sign-out so stale auth-keyed entries
      // are not reused by a subsequent user session.
      _inFlightGets.clear();
    }
  }

  static String? getToken() => _token;

  static Map<String, String> _headers({bool includeAuth = true}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (includeAuth && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  static Uri _buildUri(String path, {Map<String, String>? queryParams}) {
    final uri = Uri.parse('$baseUrl$path');
    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: queryParams);
    }
    return uri;
  }

  static dynamic _parseResponse(http.Response response) {
    if (response.statusCode >= 400) {
      String message;
      String? code;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          message = decoded['error'] as String? ??
              decoded['message'] as String? ??
              response.body;
          code = decoded['code'] as String?;
        } else {
          message = response.body;
        }
      } catch (_) {
        message = response.body;
      }
      apiLogger.e('Error ${response.statusCode}: $message');
      throw ApiException(
        statusCode: response.statusCode,
        message: message,
        code: code,
      );
    }
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  /// Performs a GET request.
  ///
  /// Concurrent calls for the **same URL + auth combination** are coalesced
  /// into a single network request (in-flight deduplication).  This prevents
  /// the "N widgets all fetch the same endpoint on the same frame" pattern
  /// that overloads the Supabase database.
  ///
  /// If the server responds with a 500 DATABASE_ERROR the request is retried
  /// up to [_maxRetries] times with exponential back-off before propagating
  /// the error to the caller.
  static Future<dynamic> get(
    String path, {
    Map<String, String>? queryParams,
    bool authenticated = true,
  }) {
    final uri = _buildUri(path, queryParams: queryParams);
    final key = '${authenticated ? 'auth' : 'anon'}:$uri';

    final existing = _inFlightGets[key];
    if (existing != null) {
      apiLogger.d('GET $uri [coalesced]');
      return existing;
    }

    final future = _fetchWithRetry(uri, authenticated: authenticated);
    _inFlightGets[key] = future;
    future.then<void>((_) => _inFlightGets.remove(key),
        onError: (_) => _inFlightGets.remove(key));
    return future;
  }

  static Future<dynamic> _fetchWithRetry(
    Uri uri, {
    required bool authenticated,
  }) async {
    // Redact Authorization header from logs
    final headers = _headers(includeAuth: authenticated);
    final headersForLog = Map<String, String>.from(headers);
    if (headersForLog.containsKey('Authorization')) {
      headersForLog['Authorization'] = '[REDACTED]';
    }
    apiLogger.d('GET $uri');
    apiLogger.d('Headers: $headersForLog');

    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response =
            await http.get(uri, headers: headers).timeout(_timeout);
        apiLogger.d('Response ${response.statusCode}');
        return _parseResponse(response);
      } on ApiException catch (e) {
        if (e.statusCode == 500 &&
            e.code == 'DATABASE_ERROR' &&
            attempt < _maxRetries) {
          apiLogger.w(
            'DATABASE_ERROR (attempt ${attempt + 1}/$_maxRetries) for $uri — '
            'retrying in ${_retryDelays[attempt].inMilliseconds}ms…',
          );
          await Future<void>.delayed(_retryDelays[attempt]);
          continue;
        }
        rethrow;
      }
    }
    // Unreachable — the loop always returns or rethrows.
    throw StateError('Unreachable retry loop exit for $uri');
  }

  static Future<dynamic> post(String path, {dynamic body}) async {
    // Redact sensitive fields if present
    dynamic logBody = body;
    if (body is Map && body.containsKey('password')) {
      logBody = Map.of(body);
      logBody['password'] = '[REDACTED]';
      if (logBody.containsKey('newPassword')) {
        logBody['newPassword'] = '[REDACTED]';
      }
      if (logBody.containsKey('currentPassword')) {
        logBody['currentPassword'] = '[REDACTED]';
      }
    }
    apiLogger.d('POST $path');
    apiLogger.d(
        'Headers: ${_headers().map((k, v) => MapEntry(k, k == "Authorization" ? "[REDACTED]" : v))}');
    if (logBody != null) apiLogger.d('Body: $logBody');
    final response = await http
        .post(
          _buildUri(path),
          headers: _headers(),
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(_timeout);
    return _parseResponse(response);
  }

  static Future<dynamic> put(String path, {dynamic body}) async {
    final response = await http
        .put(
          _buildUri(path),
          headers: _headers(),
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(_timeout);
    return _parseResponse(response);
  }

  static Future<dynamic> patch(String path, {dynamic body}) async {
    final response = await http
        .patch(
          _buildUri(path),
          headers: _headers(),
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(_timeout);
    return _parseResponse(response);
  }

  static Future<dynamic> delete(String path, {dynamic body}) async {
    final request = http.Request('DELETE', _buildUri(path));
    request.headers.addAll(_headers());
    if (body != null) {
      request.body = jsonEncode(body);
    }
    final streamedResponse = await request.send().timeout(_timeout);
    final response = await http.Response.fromStream(streamedResponse);
    return _parseResponse(response);
  }
}
