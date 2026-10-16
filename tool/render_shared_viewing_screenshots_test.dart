import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:http/testing.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';
import 'package:flixie_app/features/social/data/starred_people.dart';
import 'package:flixie_app/features/social/presentation/pages/watch_requests_screen.dart';
import 'package:flixie_app/models/friendship.dart';
import '../test/support/api_fixture.dart';
import '../patrol_test/support/store_screenshot_fixture.dart';
import '../patrol_test/support/watch_plan_fixture.dart';

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
      'capture selecting, rating progress, complete and missed shared viewing',
      (tester) async {
    // This opt-in render tool runs through flutter test.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final $ = _ScreenDriver(tester);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewPadding);
    final captureKey = GlobalKey();
    await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(
          await File('output/watch-together-mockups/alien.jpg').readAsBytes());
      final frame = await codec.getNextFrame();
      const provider = CachedNetworkImageProvider(
          'https://image.tmdb.org/t/p/w342/vfrQk5IPloGg1v9Rzbh2Eg3VGyM.jpg');
      PaintingBinding.instance.imageCache.putIfAbsent(
          await provider.obtainKey(ImageConfiguration.empty),
          () => OneFrameImageStreamCompleter(
              Future.value(ImageInfo(image: frame.image))));
    });
    final auth = StoreScreenshotAuth();
    addTearDown(auth.dispose);
    StarredPeople.instance.selectAccount('store-viewer');
    StarredPeople.instance.loaded = true;
    addTearDown(() => StarredPeople.instance.selectAccount(null));
    final friends = [
      for (final name in ['Robin', 'Ellis', 'Sophie'])
        Friendship(
            id: name,
            createdAt: '',
            updatedAt: '',
            friend: FriendshipUser(
                id: 'fixture-${name.toLowerCase()}',
                username: name,
                profileBadges: const ['EARLY_ADOPTER']))
    ];
    final api = WatchPlanFixture(status: 'ACCEPTED');
    final people = [
      screenshotPerson,
      for (final friend in friends)
        {
          'id': friend.friend!.id,
          'username': friend.friend!.username,
          'profileBadges': ['EARLY_ADOPTER']
        }
    ];
    api.plan.addAll({
      'requesterId': 'store-viewer',
      'requester': screenshotPerson,
      'recipientId': 'fixture-robin',
      'recipient': people[1],
      'participants': [
        for (final person in people) {'userId': person['id'], 'user': person}
      ],
      'lightweight': true,
      'groupId': null,
      'watchedStatus': 'PARTIAL',
      'movie': screenshotMovies.firstWhere((m) => m['id'] == 348),
      'message': '',
      'watchConfirmations': <Map<String, dynamic>>[],
    });
    useApiFixture(MockClient((request) async {
      if (request.method == 'POST' &&
          request.url.path.endsWith('/watch-confirmations')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        api.writes.add(body);
        api.plan['watchConfirmations'] = [
          ...(api.plan['watchConfirmations'] as List),
          {...body, 'id': 'my-response'}
        ];
        api.plan['watchedStatus'] = 'NOT_WATCHED';
        return api.json(api.state);
      }
      return api.handle(request);
    }));
    Future<void> capture(String name) async {
      await $.pumpAndSettle();
      expect($.tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary = captureKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 3);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('output/shared-viewing-screenshots/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      debugPrint('Captured $name');
    }

    Future<void> mount(Widget page) async {
      await $.pumpWidgetAndSettle(const SizedBox.shrink());
      final router =
          GoRouter(routes: [GoRoute(path: '/', builder: (_, __) => page)]);
      addTearDown(router.dispose);
      await $.pumpWidgetAndSettle(RepaintBoundary(
          key: captureKey, child: storeScreenshotApp(auth, router)));
      for (final element in find.byType(Scrollable).evaluate()) {
        final state = (element as StatefulElement).state as ScrollableState;
        if (state.position.axis == Axis.vertical) {
          state.position.jumpTo(state.position.minScrollExtent);
        }
      }
      await $.pumpAndSettle();
    }

    Map<String, dynamic> response(String id, int rating) => {
          'id': '$id-log',
          'userId': id,
          'watched': true,
          'rating': rating,
          'recommended': true,
          'watchEntry': {'watchedAt': '2026-10-16T12:00:00.000Z', 'notes': null}
        };
    await mount(Scaffold(
        body: Builder(
            builder: (context) => Center(
                child: FilledButton(
                    onPressed: () => showMovieWatchLogSheet(
                        context: context,
                        builder: (_) => RewatchLogSheet(
                            movieTitle: 'Alien',
                            loadFriends: () async => friends,
                            onSubmit: (
                                {required watchedAt,
                                required rating,
                                required recommended,
                                required notes}) async {})),
                    child: const Text('Log Alien'))))));
    await $('Log Alien').tap();
    await $('Add someone').tap();
    for (final name in ['Robin', 'Ellis', 'Sophie']) {
      await $(name).tap();
    }
    await capture('01-select-three');
    await $('Done · 3 selected').tap();
    await capture('02-watch-editor');
    api.plan['watchConfirmations'] = [response('store-viewer', 8)];
    await mount(const WatchRequestsScreen());
    await $('With Robin, Ellis, Sophie').waitUntilVisible();
    await capture('03-one-rating-card');
    await mount(const WatchRequestsScreen(initialRequestId: 'patrol-plan'));
    await $('1 of 4 rated').waitUntilVisible();
    await $('Shared viewing · 4 people').waitUntilVisible();
    await capture('04-one-rating-detail');
    await $.tester.ensureVisible(find.text('Sophie').last);
    await capture('05-one-rating-people');
    api.plan['watchConfirmations'] = [
      response('store-viewer', 8),
      response('fixture-robin', 9),
      response('fixture-ellis', 7),
      response('fixture-sophie', 6)
    ];
    api.plan['watchedStatus'] = 'WATCHED';
    await mount(const WatchRequestsScreen(initialRequestId: 'patrol-plan'));
    await $('Everyone has rated').waitUntilVisible();
    await capture('06-everyone-rated');
    await $.tester.ensureVisible(find.text('Sophie').last);
    await capture('07-everyone-rated-people');
    api.plan['watchConfirmations'] = [
      response('fixture-robin', 9),
      response('fixture-ellis', 7),
      response('fixture-sophie', 8)
    ];
    api.plan['watchedStatus'] = 'PARTIAL';
    await mount(const WatchRequestsScreen(initialRequestId: 'patrol-plan'));
    await $('I wasn’t there').waitUntilVisible();
    await capture('08-wasnt-there-choice');
    await $('I wasn’t there').tap();
    await $('Everyone who watched has rated').waitUntilVisible();
    expect(api.writes.single['watched'], false);
    expect(api.diary, isEmpty);
    await capture('09-missed-complete');
    await $.tester.ensureVisible(find.text('Sophie').last);
    await capture('10-missed-people');
    expect(api.unexpected, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 10)));
}

class _ScreenDriver {
  _ScreenDriver(this.tester);
  final WidgetTester tester;
  _ScreenFinder call(String text) => _ScreenFinder(tester, find.text(text));
  Future<void> pumpWidgetAndSettle(Widget widget) async {
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  Future<void> pumpAndSettle() => tester.pumpAndSettle();
}

class _ScreenFinder {
  _ScreenFinder(this.tester, this.finder);
  final WidgetTester tester;
  final Finder finder;
  Future<void> waitUntilVisible() async {
    for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(finder, findsWidgets);
  }

  Future<void> tap() async {
    await waitUntilVisible();
    await tester.ensureVisible(finder.first);
    await tester.tap(finder.first);
    await tester.pumpAndSettle();
  }
}
