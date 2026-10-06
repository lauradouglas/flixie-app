import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/auth/setup_destination.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/features/movies/presentation/pages/search_screen.dart';

class _Auth extends ChangeNotifier implements AuthProvider {
  @override
  List<MovieShort> get cachedTrending => [];
  @override
  int get unreadNotificationCount => 0;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('search launch survives setup without arbitrary parameters', () {
    expect(setupDestination('/search?focus=1'), '/search?focus=1');
    expect(setupDestination('/search?focus=1&next=https://example.com'),
        '/search?focus=1');
    expect(setupDestination('/search'), isNull);
  });

  testWidgets(
      'widget URL routes to Discover and consumes focus for repeat taps',
      (tester) async {
    final auth = _Auth();
    addTearDown(auth.dispose);
    final router = GoRouter(
      initialLocation: '/search?focus=1',
      routes: [
        GoRoute(
            path: '/search',
            builder: (context, state) => SearchScreen(
                  focusSearch: state.uri.queryParameters['focus'] == '1',
                  onFocusHandled: () => context.go('/search'),
                ))
      ],
    );
    addTearDown(router.dispose);
    await http.runWithClient(() async {
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth, child: MaterialApp.router(routerConfig: router)));
      await tester.pumpAndSettle();
      TextField field() => tester.widget<TextField>(find.byType(TextField));
      expect(field().focusNode!.hasFocus, isTrue);
      expect(router.routeInformationProvider.value.uri.toString(), '/search');
      field().focusNode!.unfocus();
      await tester.pump();
      router.go('flixie:///search?focus=1');
      await tester.pumpAndSettle();
      expect(field().focusNode!.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(router.routeInformationProvider.value.uri.toString(), '/search');
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient((_) async => http.Response('[]', 200,
            headers: {'content-type': 'application/json'})));
  });

  testWidgets(
      'widget launch focuses search and repeat launch selects the query',
      (tester) async {
    final auth = _Auth();
    addTearDown(auth.dispose);
    var handled = 0;
    Widget screen(bool focus) => ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
            home: SearchScreen(
              focusSearch: focus,
              onFocusHandled: () => handled++,
            ),
          ),
        );
    await http.runWithClient(() async {
      await tester.pumpWidget(screen(false));
      await tester.pumpAndSettle();
      TextField field() => tester.widget<TextField>(find.byType(TextField));
      expect(field().focusNode!.hasFocus, isFalse);
      await tester.pumpWidget(screen(true));
      await tester.pump();
      expect(field().focusNode!.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(handled, 1);
      await tester.enterText(find.byType(TextField), 'Alien');
      await tester.pumpWidget(screen(false));
      field().focusNode!.unfocus();
      await tester.pump();
      await tester.pumpWidget(screen(true));
      await tester.pump();
      expect(field().focusNode!.hasFocus, isTrue);
      expect(field().controller!.selection,
          const TextSelection(baseOffset: 0, extentOffset: 5));
      expect(handled, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient((request) async => http.Response(
              jsonEncode(request.url.path.contains('/trending/')
                  ? []
                  : {
                      'page': 1,
                      'totalPages': 1,
                      'totalResults': 0,
                      'results': []
                    }),
              200,
              headers: {'content-type': 'application/json'},
            )));
  });
}
