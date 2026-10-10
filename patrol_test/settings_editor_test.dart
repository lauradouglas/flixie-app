import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/settings/presentation/pages/settings_screen.dart';
import '../test/settings_country_test.dart' show CountryAuth;
import '../test/support/api_fixture.dart';

void main() {
  patrolTest('Settings edits save and return to the original page', ($) async {
    final auth = CountryAuth();
    addTearDown(auth.dispose);
    final writes = <Map<String, dynamic>>[];
    var countries = 0;
    useApiFixture(MockClient((request) async {
      if (request.url.path.endsWith('/utils/countries')) {
        countries++;
        return http.Response(
            '[{"id":1,"name":"United Kingdom","abbreviation":"GB"}]', 200);
      }
      if (request.url.path.endsWith('/exists')) {
        return http.Response('false', 200);
      }
      if (request.method != 'GET') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        writes.add(body);
        return http.Response(
            jsonEncode(
                auth.dbUser.copyWith(bio: body['bio'] as String?).toJson()),
            200);
      }
      throw StateError('Unexpected ${request.method} ${request.url}');
    }));
    await $.tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
              builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () => showSettingsEditDetailsSheet(context),
                        child: const Text('Edit fixture profile')),
                  ))),
    ));
    await $(find.text('Edit fixture profile')).tap();
    await $(find.text('Save Changes')).waitUntilVisible();
    await $.tester
        .enterText(find.byType(TextField).at(1), 'Alien and The Odyssey');
    FocusManager.instance.primaryFocus?.unfocus();
    await $.tester.pumpAndSettle();
    await $.tester.ensureVisible(find.text('Save Changes'));
    await $(find.text('Save Changes')).tap();
    await $(find.text('Edit fixture profile')).waitUntilVisible();
    expect(writes, [
      {'bio': 'Alien and The Odyssey'}
    ]);
    expect(auth.dbUser.bio, 'Alien and The Odyssey');
    expect(countries, 1);
    expect($.tester.takeException(), isNull);
  });
}
