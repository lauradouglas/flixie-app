import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  static const String baseUrl = 'http://localhost:3000';

  static String? _token;

  static void setToken(String? token) {
    _token = token;
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
      throw ApiException(statusCode: response.statusCode, message: message);
    }
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  static Future<dynamic> get(String path,
      {Map<String, String>? queryParams}) async {
    final response = await http.get(
      _buildUri(path, queryParams: queryParams),
      headers: _headers(),
    );
    return _parseResponse(response);
  }

  static Future<dynamic> post(String path, {dynamic body}) async {
    final response = await http.post(
      _buildUri(path),
      headers: _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _parseResponse(response);
  }

  static Future<dynamic> put(String path, {dynamic body}) async {
    final response = await http.put(
      _buildUri(path),
      headers: _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _parseResponse(response);
  }

  static Future<dynamic> patch(String path, {dynamic body}) async {
    final response = await http.patch(
      _buildUri(path),
      headers: _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _parseResponse(response);
  }

  static Future<dynamic> delete(String path, {dynamic body}) async {
    final request = http.Request('DELETE', _buildUri(path));
    request.headers.addAll(_headers());
    if (body != null) {
      request.body = jsonEncode(body);
    }
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _parseResponse(response);
  }
}
