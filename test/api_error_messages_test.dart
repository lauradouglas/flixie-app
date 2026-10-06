import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/core/api/api_client.dart';

void main() {
  tearDown(() => ApiClient.useClientForTesting(null));

  Future<ApiException> failure(http.Response response) async {
    ApiClient.useClientForTesting(MockClient((_) async => response));
    try {
      await ApiClient.post('/test');
      fail('Expected an API error');
    } on ApiException catch (error) {
      return error;
    }
  }

  test('preserves actionable validation messages and error codes', () async {
    final error = await failure(http.Response(
      '{"error":"Choose a future time for this Watch Plan","code":"INVALID_TIME"}',
      400,
    ));
    expect(error.message, 'Choose a future time for this Watch Plan');
    expect(error.code, 'INVALID_TIME');
    expect(error.toString(), error.message);
    expect(error.statusCode, 400);
  });

  test('server failures hide technical details', () async {
    final error = await failure(http.Response(
      '{"error":"Prisma query failed","code":"DATABASE_ERROR"}',
      500,
    ));
    expect(error.message, contains('try again shortly'));
    expect(error.message, isNot(contains('Prisma')));
    expect(error.code, 'DATABASE_ERROR');
  });

  test('HTML and non-string error payloads get useful fallbacks', () async {
    for (final body in [
      '<html>proxy failure</html>',
      '{"error":{"query":"sql"}}'
    ]) {
      final error = await failure(http.Response(body, 404));
      expect(error.message, contains('no longer available'));
    }
  });

  test('expired sign-in and rate limits explain the next action', () async {
    expect((await failure(http.Response('expired', 401))).message,
        contains('sign in again'));
    expect((await failure(http.Response('limited', 429))).message,
        contains('Wait a moment'));
  });

  test('timeout preserves uncertainty about a saved change', () async {
    ApiClient.useClientForTesting(MockClient((_) async {
      throw TimeoutException('internal timeout');
    }));
    await expectLater(
        ApiClient.patch('/watch', body: {'rating': 8}),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'REQUEST_TIMEOUT')
            .having((e) => e.message, 'message',
                contains('check whether it saved'))));
  });

  test('lost connection does not claim a save failed or retry the write',
      () async {
    var requests = 0;
    ApiClient.useClientForTesting(MockClient((_) async {
      requests++;
      throw http.ClientException('Socket failure at internal host');
    }));
    await expectLater(
        ApiClient.post('/watch', body: {'rating': 8}),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'CONNECTION_ERROR')
            .having((e) => e.message, 'message',
                contains('check whether it saved'))));
    expect(requests, 1);
  });
}
