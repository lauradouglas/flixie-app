import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/app_logger.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
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

  static String? _token;

  static void setToken(String? token) {
    _token = token;
    if (token != null) {
      apiLogger.d('Token set');
    } else {
      apiLogger.d('Token cleared');
    }
  }

  static String? getToken() => _token;

  static Map<String, String> _headers() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (_token != null) {
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
      try {
        final decoded = jsonDecode(response.body);
        message = decoded['message'] as String? ?? response.body;
      } catch (_) {
        message = response.body;
      }
      apiLogger.e('Error ${response.statusCode}: $message');
      throw ApiException(statusCode: response.statusCode, message: message);
    }
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  static Future<dynamic> get(String path,
      {Map<String, String>? queryParams}) async {
    final uri = _buildUri(path, queryParams: queryParams);
    apiLogger.d('GET $uri');
    // Redact Authorization header from logs
    final headersForLog = Map<String, String>.from(_headers());
    if (headersForLog.containsKey('Authorization')) {
      headersForLog['Authorization'] = '[REDACTED]';
    }
    apiLogger.d('Headers: $headersForLog');

    final response = await http.get(uri, headers: _headers()).timeout(_timeout);

    apiLogger.d('Response ${response.statusCode}');

    return _parseResponse(response);
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
