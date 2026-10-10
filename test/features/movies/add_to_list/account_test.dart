import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/movies/presentation/widgets/add_to_list_sheet.dart';
import '../../../settings_country_test.dart' show CountryAuth;
import '../../../support/api_fixture.dart';

void main() {
  testWidgets('account replacement clears previous list selection',
      (tester) async {
    final auth = CountryAuth();
    addTearDown(auth.dispose);
    final reads = <String>[];
    useApiFixture(MockClient((request) async {
      reads.add(request.url.path);
      return http.Response(
          request.url.path.endsWith('/lists')
              ? '[{"id":"alien","name":"Alien collection","removed":false}]'
              : request.url.path.contains('/containing/movie/')
                  ? '{"listIds":[]}'
                  : '[]',
          200);
    }));
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(
            home: Scaffold(body: AddToListSheet(movieId: 1)))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alien collection'));
    await tester.pumpAndSettle();
    expect(find.text('Done · Added to 1 list'), findsOneWidget);
    auth.updateCachedUser(auth.dbUser.copyWith(id: 'second-account'));
    await tester.pumpAndSettle();
    expect(find.text('Done · Added to 0 lists'), findsOneWidget);
    expect(reads.any((p) => p.contains('second-account')), isTrue);
    expect(tester.takeException(), isNull);
  });
}
