// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/storage/movie_cache_service.dart';
import 'package:flixie_app/features/movies/presentation/pages/search_screen.dart';
import '../../../support/api_fixture.dart';
import '../../../../patrol_test/support/search_journeys.dart' show SearchAuth;

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(430, 932),
    const Size(844, 390),
    const Size(1024, 768)
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Search remains usable at $size with ${scale}x text',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        MovieCacheService().clearCache();
        final auth = SearchAuth();
        addTearDown(auth.dispose);
        useApiFixture(MockClient((r) async => http.Response(
            jsonEncode(r.url.path.contains('trending')
                ? [
                    {
                      'id': 1,
                      'title':
                          'The Odyssey with a long readable catalogue title'
                    }
                  ]
                : {
                    'page': 1,
                    'totalPages': 1,
                    'totalResults': 1,
                    'results': [
                      {
                        'id': 2,
                        'media_type': r.url.queryParameters['type'] == 'person'
                            ? 'person'
                            : 'movie',
                        'name':
                            'A very long person or movie name that must stay readable',
                        'title':
                            'A very long person or movie name that must stay readable',
                        'overview':
                            'A long overview preview for this fictional title.',
                        'known_for_department': 'Directing and production'
                      }
                    ]
                  }),
            200,
            headers: {'content-type': 'application/json'})));
        await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: MaterialApp(
                theme: AppTheme.darkTheme,
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!),
                home: const SearchScreen())));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.enterText(find.byType(TextField), 'long');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expect(
            find.text(
                'A very long person or movie name that must stay readable',
                findRichText: true),
            findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(find.text('People'), 120,
            scrollable: find.descendant(
                of: find.byWidgetPredicate((w) =>
                    w is ListView && w.scrollDirection == Axis.horizontal),
                matching: find.byType(Scrollable)));
        await tester.pumpAndSettle();
        await tester.tap(find.text('People'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Clear search'));
        await tester.pumpAndSettle();
        expect(find.text('Trending movies'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
