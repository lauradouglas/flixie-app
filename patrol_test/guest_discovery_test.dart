import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import '../test/features/guest/guest_collecting_test.dart'
    show guestCollectingJourney;
import 'guest_browsing_test.dart' as browsing;

const host = String.fromEnvironment('GUEST_CAPTURE_HOST');

class _Network extends HttpOverrides {}

void main() {
  browsing.main();
  patrolTest('guest keeps collecting films and shows without signup',
      ($) async {
    if (host.isNotEmpty) {
      HttpOverrides.global = _Network();
      // ignore: invalid_use_of_protected_member
      ($.tester.binding as LiveTestWidgetsFlutterBinding).setLabel('');
    }
    await guestCollectingJourney($.tester,
        artworkHost: host.isEmpty ? null : host,
        capture: host.isEmpty
            ? null
            : (name) async {
                await $.pump(const Duration(milliseconds: 500));
                await $.tester.runAsync(() async {
                  final client = HttpClient();
                  try {
                    final request =
                        await client.postUrl(Uri.parse('$host/capture'));
                    request.headers.set('X-Capture-Token',
                        const String.fromEnvironment('GUEST_CAPTURE_TOKEN'));
                    request.headers.contentType = ContentType.json;
                    request
                        .write(jsonEncode({'device': 'phone', 'name': name}));
                    final response = await request.close();
                    expect(response.statusCode, 200);
                    await response.drain<void>();
                  } finally {
                    client.close(force: true);
                  }
                });
              });
  });
}
