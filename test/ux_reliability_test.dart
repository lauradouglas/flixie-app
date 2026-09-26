import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/router/router.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/features/home/presentation/widgets/greeting_header.dart';
import 'package:flixie_app/features/movies/presentation/pages/my_reviews_screen.dart';
import 'package:flixie_app/features/movies/presentation/pages/watch_history_screen.dart';
import 'package:flixie_app/features/movies/presentation/pages/movie_lists_screen.dart';
import 'package:flixie_app/models/user.dart' as models;
import 'package:flixie_app/models/review.dart';
import 'support/api_fixture.dart';

class FixtureAuth extends ChangeNotifier implements AuthProvider {
  @override
  models.User get dbUser => models.User.fromJson({'id': 'ux-fixture', 'username': 'Casey'});
  @override
  List<Review>? get cachedReviews => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

http.Response response(Object data, [int status = 200]) => http.Response(jsonEncode(data), status, headers: {'content-type': 'application/json'});

void main() {
  for (final entry in <(Widget, String, String)>[
    (const MyReviewsScreen(), 'Couldn’t load your reviews.', 'No reviews yet'),
    (const WatchHistoryScreen(), 'Couldn’t load your watch history.', 'No watch history yet'),
    (const MovieListsScreen(), 'Couldn’t load your lists.', 'No lists yet. Create your first one.'),
  ]) {
    testWidgets('${entry.$1.runtimeType} distinguishes failure from empty and retries', (tester) async {
      var fail = true;
      var calls = 0;
      useApiFixture(MockClient((request) async {
        calls++;
        return fail ? response({'error': 'offline'}, 500) : response([]);
      }));
      final auth = FixtureAuth();
      addTearDown(auth.dispose);
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(value: auth, child: MaterialApp(home: entry.$1)));
      await tester.pumpAndSettle();
      expect(find.text(entry.$2), findsOneWidget);
      expect(find.text(entry.$3), findsNothing);
      final before = calls;
      fail = false;
      await tester.tap(find.widgetWithText(TextButton, 'Retry'));
      await tester.pumpAndSettle();
      expect(calls, greaterThan(before));
      expect(find.text(entry.$2), findsNothing);
      expect(find.text(entry.$3), findsOneWidget);
    });
  }

  testWidgets('Home shortcuts reflow at large text and still activate', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var invites = 0;
    await tester.pumpWidget(MaterialApp(builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)), child: child!), home: Scaffold(body: SingleChildScrollView(child: GreetingHeader(name: 'Casey with a longer name', onSearch: () {}, onWatchlist: () {}, onInvite: () => invites++, onRequests: () {})))));
    expect(find.byType(FittedBox), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Invite friends'));
    expect(invites, 1);
    expect(tester.getTopLeft(find.text('Invite friends')).dy, greaterThan(tester.getTopLeft(find.text('Search')).dy));
  });

  testWidgets('navigation announces selection and changes destination', (tester) async {
    final handle = tester.ensureSemantics();
    addTearDown(handle.dispose);
    final router = GoRouter(routes: [ShellRoute(builder: (_, __, child) => MainNavigationShell(child: child), routes: [for (final path in ['/', '/watchlist', '/search', '/social', '/profile']) GoRoute(path: path, builder: (_, __) => Text('Destination $path'))])]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(find.bySemanticsLabel('Home')).hasFlag(SemanticsFlag.isSelected), isTrue);
    await tester.tap(find.text('Watchlist'));
    await tester.pumpAndSettle();
    expect(find.text('Destination /watchlist'), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('Watchlist')).hasFlag(SemanticsFlag.isSelected), isTrue);
    expect(tester.getSemantics(find.bySemanticsLabel('Home')).hasFlag(SemanticsFlag.isSelected), isFalse);
  });

  testWidgets('reduced-motion loading settles and follows preference changes', (tester) async {
    Future<void> mount(bool reduced) => tester.pumpWidget(MaterialApp(builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: reduced), child: child!), home: const Scaffold(body: Column(children: [SkeletonBox(width: 80, height: 40), Expanded(child: HomeBootLoadingScreen())]))));
    await mount(true);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await mount(false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await mount(true);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
