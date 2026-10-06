import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/social/presentation/pages/group_members_screen.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'dart:async';
import 'package:flixie_app/features/social/presentation/pages/direct_chat_screen.dart';
import 'package:flixie_app/features/movies/presentation/pages/user_wrapped_screen.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
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
  models.User get dbUser =>
      models.User.fromJson({'id': 'ux-fixture', 'username': 'Casey'});
  @override
  List<Review>? get cachedReviews => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

http.Response response(Object data, [int status = 200]) =>
    http.Response(jsonEncode(data), status,
        headers: {'content-type': 'application/json'});

void main() {
  setUpAll(() async {
    await (FontLoader('Manrope')
          ..addFont(
              rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  testWidgets(
      'group invite retries friends and preserves their personal border',
      (tester) async {
    var fail = true;
    useApiFixture(MockClient((request) async {
      if (request.url.path == '/groups/fixture-group/members') {
        return response([
          {
            'groupId': 'fixture-group',
            'memberId': 'ux-fixture',
            'role': 'OWNER',
            'username': 'Casey'
          }
        ]);
      }
      expect(request.url.path, '/friends/ux-fixture');
      return fail
          ? response({'error': 'offline'}, 500)
          : response({
              'friendships': [
                {
                  'id': 'friendship',
                  'friend': {
                    'id': 'robin-fixture',
                    'username': 'Robin',
                    'profileBadges': ['FOUNDER']
                  }
                }
              ]
            });
    }));
    final auth = FixtureAuth();
    addTearDown(auth.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(
            home: GroupMembersScreen(
                groupId: 'fixture-group', groupName: 'Film friends'))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Invite'));
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t load your friends.'), findsOneWidget);
    fail = false;
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pumpAndSettle();
    final row = find.ancestor(
        of: find.text('Robin'), matching: find.byType(CheckboxListTile));
    expect(row, findsOneWidget);
    final avatar = tester.widget<ProfileAvatarView>(
        find.descendant(of: row, matching: find.byType(ProfileAvatarView)));
    expect(avatar.profileBadges, ['FOUNDER']);
    await tester.tap(row);
    await tester.pump();
    expect(find.text('Invite (1)'), findsOneWidget);
  });

  testWidgets(
      'reviews retry preserves the entered query and only shows matches',
      (tester) async {
    var fail = true;
    useApiFixture(MockClient((request) async => fail
        ? response({'error': 'offline'}, 500)
        : response([
            {
              'id': 'alien-review',
              'movieId': 348,
              'title': 'A great night',
              'movieTitle': 'Alien',
              'rating': 9
            },
            {
              'id': 'odyssey-review',
              'movieId': 99,
              'title': 'Another film',
              'movieTitle': 'The Odyssey',
              'rating': 8
            },
          ])));
    final auth = FixtureAuth();
    addTearDown(auth.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth, child: const MaterialApp(home: MyReviewsScreen())));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Alien');
    fail = false;
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Alien');
    expect(find.text('Alien'), findsWidgets);
    expect(find.text('The Odyssey'), findsNothing);
  });

  testWidgets(
      'history renders base titles before bounded detail requests finish',
      (tester) async {
    final details = <Completer<http.Response>>[];
    var active = 0;
    var peak = 0;
    useApiFixture(MockClient((request) async {
      if (request.url.path.endsWith('/movies/watched')) {
        return response(List.generate(
            9,
            (i) => {
                  'id': 'watch-$i',
                  'movieId': i + 1,
                  'userId': 'ux-fixture',
                  'movie': {'id': i + 1, 'title': i == 0 ? 'Alien' : 'Film $i'},
                }));
      }
      if (request.url.path.endsWith('/movies/reviews')) return response([]);
      expect(request.url.path, endsWith('/watches'));
      final pending = Completer<http.Response>();
      details.add(pending);
      active++;
      if (active > peak) peak = active;
      final result = await pending.future;
      active--;
      return result;
    }));
    final auth = FixtureAuth();
    addTearDown(auth.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth, child: const MaterialApp(home: WatchHistoryScreen())));
    await tester.pump();
    await tester.pump();
    expect(find.text('Alien'), findsOneWidget);
    expect(details.length, 4);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    for (var batch = 0; batch < 3; batch++) {
      for (final pending in details.toList()) {
        if (!pending.isCompleted) pending.complete(response([]));
      }
      await tester.pump();
      await tester.pump();
    }
    expect(details.length, 9);
    expect(peak, lessThanOrEqualTo(4));
    expect(find.text('9 movies watched'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'history retains a title when details fail and retry clears the failure',
      (tester) async {
    var failDetail = true;
    useApiFixture(MockClient((request) async {
      if (request.url.path.endsWith('/movies/watched')) {
        return response([
          {
            'id': 'watch',
            'movieId': 348,
            'movie': {'id': 348, 'title': 'Alien'}
          }
        ]);
      }
      if (request.url.path.endsWith('/movies/reviews')) return response([]);
      expect(request.url.path, endsWith('/watches'));
      return failDetail ? response({'error': 'offline'}, 500) : response([]);
    }));
    final auth = FixtureAuth();
    addTearDown(auth.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth, child: const MaterialApp(home: WatchHistoryScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Alien'), findsOneWidget);
    expect(
        find.text(
            'Some watch details couldn’t load. Your saved history is still here.'),
        findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Alien');
    failDetail = false;
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Some watch details couldn’t load. Your saved history is still here.'),
        findsNothing);
    expect(find.text('Alien'), findsWidgets);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Alien');
  });

  testWidgets(
      'leaving reviews during a pending request does not update disposed state',
      (tester) async {
    final pending = Completer<http.Response>();
    useApiFixture(MockClient((_) => pending.future));
    final auth = FixtureAuth();
    addTearDown(auth.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth, child: const MaterialApp(home: MyReviewsScreen())));
    await tester.pumpWidget(const SizedBox());
    pending.complete(response([]));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('chat startup failure offers retry on the same conversation',
      (tester) async {
    var starts = 0;
    useApiFixture(MockClient((request) async {
      if (request.url.path == '/conversations/direct') {
        starts++;
        expect(jsonDecode(request.body)['otherUserId'], 'robin-fixture');
      }
      return response({'error': 'offline'}, 500);
    }));
    final auth = FixtureAuth();
    addTearDown(auth.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(
            home: DirectChatScreen(otherUserId: 'robin-fixture'))));
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t load this chat.'), findsOneWidget);
    expect(starts, 1);
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pumpAndSettle();
    expect(starts, 2);
    expect(find.text('Couldn’t load this chat.'), findsOneWidget);
  });

  testWidgets('Wrapped keeps technical errors out of the UI and retries',
      (tester) async {
    var calls = 0;
    useApiFixture(MockClient((request) async {
      calls++;
      return response({'error': 'internal query stack details'}, 500);
    }));
    final auth = FixtureAuth();
    addTearDown(auth.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(home: UserWrappedScreen(initialYear: 2026))));
    await tester.pumpAndSettle();
    expect(find.textContaining('internal query stack'), findsNothing);
    expect(find.text('Couldn’t load this Wrapped. Please try again.'),
        findsOneWidget);
    final before = calls;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(calls, greaterThan(before));
  });

  for (final entry in <(Widget, String, String)>[
    (const MyReviewsScreen(), 'Couldn’t load your reviews.', 'No reviews yet'),
    (
      const WatchHistoryScreen(),
      'Couldn’t load your watch history.',
      'No watch history yet'
    ),
    (
      const MovieListsScreen(),
      'Couldn’t load your lists.',
      'No lists yet. Create your first one.'
    ),
  ]) {
    testWidgets(
        '${entry.$1.runtimeType} distinguishes failure from empty and retries',
        (tester) async {
      var fail = true;
      var calls = 0;
      useApiFixture(MockClient((request) async {
        calls++;
        return fail ? response({'error': 'offline'}, 500) : response([]);
      }));
      final auth = FixtureAuth();
      addTearDown(auth.dispose);
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth, child: MaterialApp(home: entry.$1)));
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

  for (final size in [
    const Size(320, 640),
    const Size(430, 932),
    const Size(768, 1024),
    const Size(844, 390)
  ]) {
    testWidgets('Home actions remain reachable at $size with double text',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final boundary = GlobalKey();
      var activated = false;
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!),
          home: RepaintBoundary(
              key: boundary,
              child: Scaffold(
                  body: SingleChildScrollView(
                      child: GreetingHeader(
                name: 'Casey with a longer name',
                onSearch: () {},
                onWatchlist: () {},
                onInvite: () {},
                onRequests: () => activated = true,
              ))))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('UX_CAPTURE')) {
        await tester.runAsync(() async {
          final image = await (boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('/tmp/flixie-home-${size.width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.ensureVisible(find.text('Plans'));
      await tester.tap(find.text('Plans'));
      expect(activated, isTrue);
    });
  }

  testWidgets('Home shortcuts reflow at large text and still activate',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var invites = 0;
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: Scaffold(
            body: SingleChildScrollView(
                child: GreetingHeader(
                    name: 'Casey with a longer name',
                    onSearch: () {},
                    onWatchlist: () {},
                    onInvite: () => invites++,
                    onRequests: () {})))));
    expect(
        find.ancestor(
            of: find.text('Invite friends'), matching: find.byType(FittedBox)),
        findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Invite friends'));
    expect(invites, 1);
    expect(tester.getTopLeft(find.text('Invite friends')).dy,
        greaterThan(tester.getTopLeft(find.text('Search')).dy));
  });

  testWidgets('navigation announces selection and changes destination',
      (tester) async {
    final handle = tester.ensureSemantics();

    final router = GoRouter(routes: [
      StatefulShellRoute.indexedStack(
          builder: (_, __, shell) =>
              MainNavigationShell(navigationShell: shell),
          branches: [
            for (final path in [
              '/',
              '/search',
              '/plans',
              '/social',
              '/profile'
            ])
              StatefulShellBranch(routes: [
                GoRoute(
                    path: path, builder: (_, __) => Text('Destination $path'))
              ])
          ])
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(
        tester
                .getSemantics(find.bySemanticsLabel('Home'))
                .flagsCollection
                .isSelected ==
            ui.Tristate.isTrue,
        isTrue);
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
    expect(find.text('Destination /search'), findsOneWidget);
    expect(
        tester
                .getSemantics(find.bySemanticsLabel('Discover'))
                .flagsCollection
                .isSelected ==
            ui.Tristate.isTrue,
        isTrue);
    expect(
        tester
                .getSemantics(find.bySemanticsLabel('Home'))
                .flagsCollection
                .isSelected ==
            ui.Tristate.isTrue,
        isFalse);
    handle.dispose();
  });

  testWidgets('reduced-motion loading settles and follows preference changes',
      (tester) async {
    Future<void> mount(bool reduced) => tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: child!),
        home: const Scaffold(
            body: Column(children: [
          SkeletonBox(width: 80, height: 40),
          Expanded(child: HomeBootLoadingScreen())
        ]))));
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
