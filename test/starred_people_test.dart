import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/features/social/data/starred_people.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'device stars migrate once and two devices read shared server preferences',
      () async {
    SharedPreferences.setMockInitialValues({
      'starred-friends:me': ['friend']
    });
    final server = <String, bool>{'unstarredElsewhere': false};
    var imports = 0;
    ApiClient.useClientForTesting(MockClient((r) async {
      if (r.url.path.endsWith('/stars/import')) {
        imports++;
        for (final id in jsonDecode(r.body)['ids']) {
          server.putIfAbsent(id, () => true);
        }
      } else if (r.method == 'PUT') {
        server[r.url.path.split('/').reversed.skip(1).first] =
            jsonDecode(r.body)['starred'];
      }
      return http.Response(
          jsonEncode({
            'ids':
                server.entries.where((e) => e.value).map((e) => e.key).toList()
          }),
          200);
    }));
    addTearDown(() => ApiClient.useClientForTesting(null));
    final phone = StarredPeople()..selectAccount('me');
    final tablet = StarredPeople()..selectAccount('me');
    await phone.refresh();
    expect(phone.ids, {'friend'});
    expect(
        (await SharedPreferences.getInstance())
            .containsKey('starred-friends:me'),
        isFalse);
    await phone.setStar('follow-only', true);
    await tablet.refresh();
    expect(tablet.ids, {'friend', 'follow-only'});
    await tablet.setStar('friend', false);
    await phone.refresh();
    expect(phone.ids, {'follow-only'});
    expect(imports, 1);
    phone.selectAccount('another');
    expect(phone.ids, isEmpty);
  });
  test('failed write keeps the confirmed star state', () async {
    SharedPreferences.setMockInitialValues({});
    ApiClient.useClientForTesting(
        MockClient((r) async => http.Response('{}', 500)));
    addTearDown(() => ApiClient.useClientForTesting(null));
    final store = StarredPeople()..selectAccount('me');
    await expectLater(store.setStar('a', true), throwsA(anything));
    expect(store.ids, isEmpty);
  });
}
