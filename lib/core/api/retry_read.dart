import 'dart:async';
import 'package:http/http.dart' as http;
import 'api_client.dart';

/// Only for read operations, including read-only POST batch endpoints.
/// Never retry a mutation whose first response may have been lost.
Future<T> retryRead<T>(Future<T> Function() request,
    {bool Function()? isCurrent}) async {
  try {
    return await request();
  } catch (error) {
    final transient = error is TimeoutException ||
        error is http.ClientException ||
        (error is ApiException &&
            (error.statusCode == 429 || error.statusCode >= 500));
    if (!transient || (isCurrent != null && !isCurrent())) rethrow;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (isCurrent != null && !isCurrent()) rethrow;
    return request();
  }
}
