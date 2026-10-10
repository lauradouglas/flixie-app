import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/features/social/presentation/widgets/group_detail_activity_tab.dart';
import 'features/home/home_controller_test.dart' show SessionAuth, viewer;
import 'group_activity_loading_test.dart' show feed, response;
import 'support/api_fixture.dart';

Widget visit(SessionAuth auth, DateTime Function() now) =>
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
        home: DefaultTabController(
          length: 3,
          child: Builder(builder: (context) {
            final tabs = DefaultTabController.of(context);
            return Scaffold(
              appBar: AppBar(
                  bottom: const TabBar(tabs: [
                Tab(text: 'Activity'),
                Tab(text: 'Other'),
                Tab(text: 'Insights'),
              ])),
              body: AnimatedBuilder(
                  animation: tabs,
                  builder: (context, _) => TabBarView(children: [
                        GroupActivityTab(
                          active: tabs.index == 0 && !tabs.indexIsChanging,
                          now: now,
                          group: null,
                          memberCount: 2,
                          groupId: 'fixture',
                          initialRequests: const [],
                          initialActivity: const [],
                          groupLists: const [],
                          onRefresh: () async {},
                        ),
                        const Text('Other content'),
                        const Text('Insights content'),
                      ])),
            );
          }),
        ),
      ),
    );
Future<void> tab(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(Tab, label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'quick return retains feed, search, filter and scroll with one read; exit releases state',
      (tester) async {
    final auth = SessionAuth();
    addTearDown(auth.dispose);
    var reads = 0;
    final payload = feed('Alien');
    payload['items'] = List.generate(
        30,
        (i) => {
              ...(feed('Alien $i')['items'] as List).first
                  as Map<String, dynamic>,
            });
    useApiFixture(MockClient((_) async {
      reads++;
      return response(payload);
    }));
    await tester.pumpWidget(visit(auth, DateTime.now));
    await tester.pumpAndSettle();
    final state =
        tester.state<GroupActivityTabState>(find.byType(GroupActivityTab));
    await tester.tap(find.text('Rated'));
    await tester.tap(find.byTooltip('Search activity'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Alien');
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    final scroll = find
        .descendant(
            of: find.byType(GroupActivityTab),
            matching: find.byType(Scrollable))
        .first;
    await tester.drag(scroll, const Offset(0, -500));
    await tester.pumpAndSettle();
    final offset = tester.state<ScrollableState>(scroll).position.pixels;
    expect(offset, greaterThan(0));
    await tab(tester, 'Insights');
    expect(state.mounted, true);
    await tab(tester, 'Activity');
    expect(reads, 1);
    expect(tester.state<GroupActivityTabState>(find.byType(GroupActivityTab)),
        same(state));
    expect(tester.state<ScrollableState>(scroll).position.pixels,
        closeTo(offset, 1));
    await tester.drag(scroll, const Offset(0, 1000));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Alien');
    expect(
        tester
            .widget<FlixiePill>(find.widgetWithText(FlixiePill, 'Rated'))
            .selected,
        true);
    await tester.pumpWidget(const SizedBox());
    expect(state.mounted, false);
    auth.activity(); // Removed listeners must not touch disposed state.
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'hidden changes wait until return, stale visits revalidate, resume coalesces',
      (tester) async {
    final auth = SessionAuth();
    addTearDown(auth.dispose);
    var clock = DateTime(2026, 10, 9);
    var reads = 0;
    Completer<http.Response>? pending;
    useApiFixture(MockClient((_) async {
      reads++;
      if (pending != null) return pending.future;
      return response(feed('Alien'));
    }));
    await tester.pumpWidget(visit(auth, () => clock));
    await tester.pumpAndSettle();
    final state =
        tester.state<GroupActivityTabState>(find.byType(GroupActivityTab));
    await tab(tester, 'Insights');
    auth.activity();
    await tester.pump();
    expect(reads, 1);
    await tab(tester, 'Activity');
    expect(reads, 2);
    await tab(tester, 'Insights');
    clock = clock.add(const Duration(minutes: 2));
    pending = Completer<http.Response>();
    await tab(tester, 'Activity');
    expect(reads, 3);
    expect(find.text('Alien'), findsOneWidget);
    state.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(reads, 3);
    pending.complete(response(feed('Fresh Alien')));
    await tester.pumpAndSettle();
    expect(find.text('Fresh Alien'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'account change clears retained content and rejects an old in-flight response',
      (tester) async {
    final auth = SessionAuth();
    addTearDown(auth.dispose);
    var reads = 0;
    final old = Completer<http.Response>();
    useApiFixture(MockClient((_) async {
      reads++;
      if (reads == 1) return old.future;
      return response(feed('Other account'));
    }));
    await tester.pumpWidget(visit(auth, DateTime.now));
    await tester.pumpAndSettle();
    expect(find.text('No activity to show yet.'), findsNothing);
    // Real account replacement clears token-keyed HTTP deduplication too.
    ApiClient.setToken(null);
    ApiClient.setToken('fixture-second');
    addTearDown(() => ApiClient.setToken(null));
    auth.select(viewer('second'));
    await tester.pump();
    old.complete(response(feed('Old account')));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.text('Old account'), findsNothing);
    expect(find.text('Other account'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'changes during a read get a fresh follow-up; hidden resume and denial clear saved data',
      (tester) async {
    final auth = SessionAuth();
    addTearDown(auth.dispose);
    var reads = 0;
    final first = Completer<http.Response>();
    useApiFixture(MockClient((_) async {
      reads++;
      if (reads == 1) return first.future;
      if (reads == 2) return response(feed('Updated activity'));
      return response({'error': 'Membership removed'}, 403);
    }));
    await tester.pumpWidget(visit(auth, DateTime.now));
    await tester.pumpAndSettle();
    auth.activity();
    await tester.pump();
    expect(reads, 1);
    first.complete(response(feed('Outdated activity')));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.text('Outdated activity'), findsNothing);
    expect(find.text('Updated activity'), findsOneWidget);
    final state =
        tester.state<GroupActivityTabState>(find.byType(GroupActivityTab));
    await tab(tester, 'Insights');
    state.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(reads, 2);
    await tab(tester, 'Activity');
    expect(reads, 3);
    expect(find.text('Updated activity'), findsNothing);
    expect(find.text('Couldn’t refresh activity · Retry'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(state.mounted, false);
  });
}
