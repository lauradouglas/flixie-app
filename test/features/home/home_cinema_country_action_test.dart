import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/features/home/presentation/widgets/home_cinema_country_action.dart';
import '../../support/watchlist_auth.dart';
import '../../support/api_fixture.dart';

class CountryAuth extends TestAuth {
  late User user = super.dbUser;
  @override
  User get dbUser => user;
  @override
  void updateCachedUser(User value) {
    user = value;
    notifyListeners();
  }
}

void main() {
  for (final fails in [false, true]) {
    testWidgets(
        'cinema country selection ${fails ? 'preserves country on save failure' : 'saves and updates the region'}',
        (tester) async {
      final auth = CountryAuth();
      addTearDown(auth.dispose);
      final writes = <Map<String, dynamic>>[];
      useApiFixture(MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/utils/countries') {
          return http.Response(
              jsonEncode([
                {'id': 1, 'abbreviation': 'GB', 'name': 'United Kingdom'},
                {'id': 2, 'abbreviation': 'US', 'name': 'United States'},
              ]),
              200);
        }
        if (request.method == 'PUT' && request.url.path == '/users/viewer') {
          writes.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(
              jsonEncode(fails ? {'message': 'offline'} : auth.dbUser.toJson()),
              fails ? 500 : 200);
        }
        return http.Response('{}', 404);
      }));
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
              home: Scaffold(
                  body: Builder(
                      builder: (context) => Column(children: [
                            Text(context
                                .watch<AuthProvider>()
                                .dbUser!
                                .watchProviderRegion),
                            TextButton(
                                onPressed: () =>
                                    changeHomeCinemaCountry(context),
                                child: const Text('Change country')),
                          ]))))));
      await tester.tap(find.text('Change country'));
      await tester.pumpAndSettle();
      expect(find.text('Select Country'), findsOneWidget);
      await tester.tap(find.text('United States'));
      await tester.pumpAndSettle();
      expect(writes, [
        {'countryId': 2}
      ]);
      expect(auth.dbUser.watchProviderRegion, fails ? 'GB' : 'US');
      if (fails)
        expect(find.text('Couldn’t update your country. Please try again.'),
            findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
