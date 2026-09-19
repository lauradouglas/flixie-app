import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/core/safety/safety_service.dart';

void main() {
  setUp(SafetyService.reset);
  test('logout discards a previous session block response', () async {
    final response = Completer<http.Response>();
    await http.runWithClient(() async {
      final pending = SafetyService.blockedUsers();
      SafetyService.reset();
      response
          .complete(http.Response('[{"id":"old-user","username":"old"}]', 200));
      await pending;
      expect(SafetyService.isBlocked('old-user'), isFalse);
    }, () => MockClient((_) => response.future));
  });
  test('blocking invalidates the cached list and reset clears ids', () async {
    var blocked = false;
    await http.runWithClient(() async {
      expect(await SafetyService.blockedUsers(), isEmpty);
      await SafetyService.block('user');
      expect(SafetyService.isBlocked('user'), isTrue);
      expect((await SafetyService.blockedUsers()).single.id, 'user');
      SafetyService.reset();
      expect(SafetyService.isBlocked('user'), isFalse);
    },
        () => MockClient((request) async {
              if (request.method == 'POST') {
                blocked = true;
                return http.Response('{}', 200);
              }
              return http.Response(
                  blocked ? '[{"id":"user","username":"name"}]' : '[]', 200);
            }));
  });
}
