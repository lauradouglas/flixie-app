import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/pages/friend_profile_screen.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/profile/presentation/widgets/lists_preview_section.dart';
import 'package:flixie_app/features/profile/presentation/widgets/friend_profile_header.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_tile.dart';
import 'package:flixie_app/features/profile/presentation/controllers/friend_profile_controller.dart';
import 'package:flixie_app/features/profile/presentation/widgets/friend_profile_content.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/movie_rating.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/core/safety/safety_service.dart';
import 'friend_profile_controller_test.dart' show friendUser;
import 'profile_controller_test.dart' show ProfileAuth;

class FriendScreenFixture {
  final auth = ProfileAuth();
  final calls = <String>[];
  bool friends = true, preview = false, unavailable = false, pending = false;
  final updates = <Map<String, dynamic>>[];
  int activityCount = 1;
  Completer<http.Response>? oldUser;
  late final router = GoRouter(routes: [
    GoRoute(
        path: '/',
        builder: (_, __) =>
            FriendProfileScreen(userId: 'friend', previewMode: preview)),
    GoRoute(
        path: '/movie/:id',
        builder: (_, state) =>
            Scaffold(body: Text('Movie ${state.pathParameters['id']}')))
  ]);
  late final client = MockClient((request) async {
    final path = request.url.path;
    calls.add('${request.method} $path');
    Object value = [];
    if (request.method == 'POST' && path.endsWith('/requests/update')) {
      updates.add(jsonDecode(request.body) as Map<String, dynamic>);
    }
    if (path.endsWith('/users/old') && oldUser != null) return oldUser!.future;
    if (RegExp(r'/users/(friend|old|new)$').hasMatch(path)) {
      if (unavailable) return http.Response('{"message":"private"}', 403);
      final id = path.split('/').last;
      value = {
        'id': id,
        'username': id,
        'firstName': 'Robin',
        'email': '',
        'iconColorId': 0,
        'completedSetup': true,
        'profileBadges': ['EARLY_ADOPTER'],
        'favoriteMovies': List.generate(
            10,
            (i) => {
                  'id': 'f$i',
                  'userId': id,
                  'movieId': i + 1,
                  'rank': i + 1,
                  'movie': {
                    'id': i + 1,
                    'title': i == 9
                        ? 'Spider-Man'
                        : i == 0
                            ? 'The Odyssey'
                            : i == 1
                                ? 'Alien'
                                : 'Film ${i + 1}'
                  }
                })
      };
    } else if (path.contains('/friends/')) {
      value = {
        'friendships': friends
            ? [
                {
                  'id': 'edge',
                  'friend': {'id': 'friend', 'username': 'friend'}
                }
              ]
            : [],
        'pendingFriends': pending
            ? [
                {
                  'id': 'edge',
                  'friend': {'id': 'friend', 'username': 'friend'}
                }
              ]
            : [],
        'requestedFriends': []
      };
    } else if (path.endsWith('/activity')) {
      value = {
        'items': List.generate(
            activityCount,
            (i) => {
                  'id': 'a$i',
                  'userId': 'friend',
                  'type': 'watched_movie',
                  'movieId': 348,
                  'createdAt': '2026-10-07T10:00:00Z',
                  'movie': {
                    'id': 348,
                    'title':
                        activityCount == 1 ? 'Alien' : 'Activity film ${i + 1}'
                  },
                }),
        'nextCursor': null,
      };
    } else if (path.endsWith('/follow')) {
      value = {'following': false};
    }
    return http.Response(jsonEncode(value), 200);
  });
  Widget app(double scale, {String? subject}) =>
      ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: subject == null
              ? MaterialApp.router(
                  theme: AppTheme.darkTheme,
                  routerConfig: router,
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!))
              : MaterialApp(
                  theme: AppTheme.darkTheme,
                  home: FriendProfileScreen(
                      key: const ValueKey('same-route'), userId: subject)));
  void install() => ApiClient.useClientForTesting(client);
  void dispose() {
    ApiClient.useClientForTesting(null);
    client.close();
    router.dispose();
    auth.dispose();
  }
}

Future<void> openFriendTab(WidgetTester tester, String label) async {
  final target = find.text(label);
  if (target.evaluate().isEmpty) {
    final scroll = find
        .descendant(
            of: find.byType(ListView).first, matching: find.byType(Scrollable))
        .first;
    final belowHeader = find.byType(FriendProfileHeader).evaluate().isNotEmpty;
    await tester.scrollUntilVisible(target, belowHeader ? 150 : -150,
        scrollable: scroll, maxScrolls: 30);
  } else {
    await tester.ensureVisible(target);
  }
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shared favourites displays the numeric count', (tester) async {
    final fixture = FriendScreenFixture();
    fixture.install();
    addTearDown(fixture.dispose);
    final auth = fixture.auth;
    final controller = FriendProfileController(auth: auth, subjectId: 'friend')
      ..user = friendUser('friend')
      ..friendshipStatus = FriendshipStatus.friends
      ..compatibilityLoading = false
      ..sharedFavCount = 3
      ..sharedRatings = [
        MovieRating(
            id: 'rating',
            userId: 'friend',
            movieId: 1,
            rating: 8,
            createdAt: '',
            updatedAt: '')
      ];
    addTearDown(controller.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
                body: Builder(
                    builder: (context) => SingleChildScrollView(
                        child: Column(
                            children: buildFriendProfileContent(context,
                                controller: controller))))))));
    expect(find.text('3 shared favourites'), findsOneWidget);
    expect(find.textContaining("Instance of 'FriendProfileController'"),
        findsNothing);
  });

  for (final tab in [0, 2]) {
    for (final media in ['movie', 'show']) {
      testWidgets('$media review identifies its title on profile tab $tab',
          (tester) async {
        SafetyService.reset();
        final fixture = FriendScreenFixture();
        fixture.install();
        addTearDown(fixture.dispose);
        final controller = FriendProfileController(
            auth: fixture.auth, subjectId: 'friend')
          ..user = friendUser('friend')
          ..selectedTab = tab
          ..reviewsLoading = false
          ..reviews = [
            Review.fromJson({
              'id': 'review',
              'userId': 'friend',
              'title': 'Worth watching',
              'body': 'A great evening.',
              'rating': 8,
              media: media == 'movie' ? {'title': 'Alien'} : {'title': 'The OA'},
            })
          ];
        addTearDown(controller.dispose);
        await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
            value: fixture.auth,
            child: MaterialApp(
                theme: AppTheme.darkTheme,
                home: Scaffold(
                    body: Builder(
                        builder: (context) => SingleChildScrollView(
                            child: Column(
                                children: buildFriendProfileContent(context,
                                    controller: controller))))))));
        await tester.pumpAndSettle();
        expect(
            find.text(media == 'movie' ? 'Alien' : 'The OA'), findsOneWidget);
        expect(find.text('Worth watching'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets(
      'Activity keeps distant rows lazy and makes them reachable by scrolling',
      (tester) async {
    final f = FriendScreenFixture()..activityCount = 40;
    f.install();
    addTearDown(f.dispose);
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(f.app(1));
    await tester.pumpAndSettle();
    await openFriendTab(tester, 'Activity');
    expect(find.byType(ActivityTile).evaluate().length, lessThan(40));
    expect(find.text('Activity film 40'), findsNothing);
    await tester.scrollUntilVisible(find.text('Activity film 40'), 200,
        scrollable: find
            .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable))
            .first,
        maxScrolls: 60);
    await tester.pumpAndSettle();
    expect(find.text('Activity film 40'), findsOneWidget);
    expect(f.calls.where((p) => p.endsWith('/activity')), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  for (final decision in ['Accept', 'Decline']) {
    testWidgets('preview incoming request remains actionable: $decision',
        (tester) async {
      final f = FriendScreenFixture()
        ..friends = false
        ..preview = true
        ..pending = true;
      f.install();
      addTearDown(f.dispose);
      await tester.pumpWidget(f.app(1));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(decision));
      await tester.pumpAndSettle();
      await tester.tap(find.text(decision));
      await tester.pumpAndSettle();
      expect(f.updates.single['status'],
          decision == 'Accept' ? 'ACCEPTED' : 'DECLINED');
      expect(find.text('Accept'), findsNothing);
      expect(find.text('Decline'), findsNothing);
      expect(
          tester
              .widget<ListsPreviewSection>(find.byType(ListsPreviewSection))
              .publicOnly,
          true);
    });
  }

  for (final size in [
    const Size(320, 800),
    const Size(390, 850),
    const Size(1024, 800),
    const Size(844, 390)
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Friend tabs and badge-bearing header at $size text $scale',
          (tester) async {
        final f = FriendScreenFixture();
        f.install();
        addTearDown(f.dispose);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(f.app(scale));
        await tester.pumpAndSettle();
        expect(
            tester
                .widget<ProfileAvatarView>(find.byType(ProfileAvatarView).first)
                .profileBadges,
            isNotEmpty);
        expect(find.text('Message'), findsOneWidget);
        expect(find.text('Plan a watch'), findsOneWidget);
        for (final tab in ['Activity', 'Reviews', 'Overview']) {
          await openFriendTab(tester, tab);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('preview and nonfriend list projection remain public only',
      (tester) async {
    final f = FriendScreenFixture()
      ..friends = false
      ..preview = true;
    f.install();
    addTearDown(f.dispose);
    await tester.pumpWidget(f.app(1));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ListsPreviewSection>(find.byType(ListsPreviewSection))
            .publicOnly,
        true);
    expect(find.text('Add Friend'), findsNothing);
    expect(find.text('View earned milestones'), findsNothing);
  });
  testWidgets('same route changing subject rejects delayed old profile',
      (tester) async {
    final f = FriendScreenFixture()..oldUser = Completer<http.Response>();
    f.install();
    addTearDown(f.dispose);
    await tester.pumpWidget(f.app(1, subject: 'old'));
    await tester.pump();
    await tester.pumpWidget(f.app(1, subject: 'new'));
    await tester.pumpAndSettle();
    expect(find.text('@new'), findsOneWidget);
    f.oldUser!.complete(http.Response(
        jsonEncode({
          'id': 'old',
          'username': 'old',
          'email': '',
          'iconColorId': 0,
          'completedSetup': true
        }),
        200));
    await tester.pumpAndSettle();
    expect(find.text('@old'), findsNothing);
    expect(find.text('@new'), findsOneWidget);
  });
  testWidgets('private denied profile shows unavailable without loading rows',
      (tester) async {
    final f = FriendScreenFixture()..unavailable = true;
    f.install();
    addTearDown(f.dispose);
    await tester.pumpWidget(f.app(1));
    await tester.pumpAndSettle();
    expect(find.text('This profile is unavailable.'), findsOneWidget);
    expect(
        f.calls.where((p) => p.endsWith('/activity') || p.endsWith('/reviews')),
        isEmpty);
  });
}
