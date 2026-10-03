import 'dart:async';
import 'package:flixie_app/core/navigation/instant_swipe_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/features/home/presentation/widgets/home_community_section.dart';
import 'package:flixie_app/features/social/data/community_service.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_tile.dart';
import 'community_activity_feed_test.dart' as fixtures;

class HomeFeedFixture extends fixtures.FixtureCommunity {
  Completer<CommunityPage>? pending;
  bool empty = false;
  int loads = 0;
  int? lastLimit;
  @override
  Future<CommunityPage> load(
      {String? cursor,
      String filter = 'all',
      String sort = 'latest',
      String? owner,
      bool saved = false,
      int? limit}) async {
    loads++;
    lastLimit = limit;
    if (pending != null) return pending!.future;
    if (this.fail) throw Exception('offline');
    return CommunityPage(
        empty ? [] : List.generate(5, (i) => fixtures.fixture('$i')), null);
  }
}

void main() {
  testWidgets('Home shows three public posts and opens Community directly',
      (tester) async {
    final service = HomeFeedFixture();
    final scroll = ScrollController();
    final section = GlobalKey<HomeCommunitySectionState>();
    addTearDown(scroll.dispose);
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
              body: SingleChildScrollView(
                  controller: scroll,
                  child: HomeCommunitySection(
                      key: section, userId: 'viewer', service: service)))),
      GoRoute(
          path: '/community/posts/:ownerId/:type/:id',
          pageBuilder: (_, state) => InstantSwipePage<void>(
              key: state.pageKey,
              child:
                  Scaffold(body: Text('Post ${state.pathParameters["id"]}')))),
      GoRoute(
          path: '/friends-activity',
          builder: (_, state) => Scaffold(
              body: Text('Activity tab: ${state.uri.queryParameters['tab']}')))
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.byType(ActivityTile), findsNWidgets(3));
    expect(service.lastLimit, 3);
    await tester.tap(find.text(fixtures.fixture('0').mediaTitle!).first);
    await tester.pump();
    await tester.pump();
    expect(find.text('Post 0'), findsOneWidget);
    final route = ModalRoute.of(tester.element(find.text('Post 0')))!;
    expect(route.transitionDuration, Duration.zero);
    expect(route.animation!.isCompleted, isTrue);
    router.pop();
    await tester.pumpAndSettle();
    scroll.jumpTo(70);
    await tester.pumpAndSettle();
    final originalOffset = scroll.offset;
    expect(originalOffset, greaterThan(0));
    await tester.tap(find.text('View post').first);
    await tester.pumpAndSettle();
    expect(find.text('Post 0'), findsOneWidget);
    await tester.dragFrom(const Offset(1, 250), const Offset(700, 0));
    await tester.pumpAndSettle();
    expect(find.byType(ActivityTile), findsNWidgets(3));
    expect(service.lastLimit, 3);
    expect(service.loads, 1);
    expect(scroll.offset, originalOffset);
    final offset = scroll.offset;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(service.loads, 1);
    expect(scroll.offset, offset);
    await section.currentState!.refresh();
    await tester.pumpAndSettle();
    expect(service.loads, 2);
    await tester.ensureVisible(find.text('See all'));
    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();
    expect(find.text('Activity tab: community'), findsOneWidget);
  });
  testWidgets(
      'Home retries failed public feed and clears old account posts immediately',
      (tester) async {
    final service = HomeFeedFixture()..fail = true;
    Widget home(String id) => MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: HomeCommunitySection(userId: id, service: service))));
    await tester.pumpWidget(home('first'));
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t load Around Flixie.'), findsOneWidget);
    service.fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.byType(ActivityTile), findsNWidgets(3));
    expect(service.lastLimit, 3);
    service.pending = Completer<CommunityPage>();
    await tester.pumpWidget(home('second'));
    await tester.pump();
    expect(find.byType(ActivityTile), findsNothing);
    service.pending!.complete(const CommunityPage([], null));
    await tester.pumpAndSettle();
    expect(find.text('Explore Around Flixie'), findsOneWidget);
  });
}
