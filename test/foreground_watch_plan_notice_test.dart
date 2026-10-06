import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/auth/foreground_watch_plan_notice.dart';

Map<String, dynamic> payload({bool group = false}) => {
      'category': 'WATCH_PLAN',
      'event': 'SCHEDULE_PROPOSED',
      'actorId': 'friend',
      'recipientId': 'viewer',
      'watchPlanId': 'plan',
      'scheduleProposalId': 'proposal',
      if (group) 'groupId': 'group',
    };

void main() {
  for (final group in [false, true]) {
    test(
        '${group ? 'group' : 'friend'} event opens the latest plan, not a stale proposal',
        () {
      final notice = ForegroundWatchPlanNotice.fromPayload(
          payload(group: group),
          currentUserId: 'viewer',
          title: 'Robin suggested another date',
          body: 'Saturday, date only');
      expect(
          notice!.path,
          group
              ? '/groups/group?tab=requests&requestId=plan'
              : '/watch-requests/plan');
      expect(notice.body, 'Saturday, date only');
    });
  }
  test(
      'logged-out, other-account, own and unrelated messages do not make banners',
      () {
    for (final user in <String?>[null, 'other', 'friend']) {
      expect(
          ForegroundWatchPlanNotice.fromPayload(payload(), currentUserId: user),
          isNull);
    }
    expect(
        ForegroundWatchPlanNotice.fromPayload({'category': 'CHAT'},
            currentUserId: 'viewer'),
        isNull);
  });
  testWidgets(
      'incoming updates replace the banner, deduplicate and open the newest plan',
      (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    final presenter = WatchPlanNoticePresenter();
    addTearDown(presenter.reset);
    await tester.pumpWidget(MaterialApp(
        navigatorKey: navigator, home: const Scaffold(body: Text('Home'))));
    var opened = '';
    final first = ForegroundWatchPlanNotice.fromPayload(payload(),
        currentUserId: 'viewer', messageId: 'one', title: 'First proposal')!;
    presenter.show(navigator.currentState!.overlay, first,
        onOpen: () => opened = 'first');
    await tester.pump();
    final second = ForegroundWatchPlanNotice.fromPayload(payload(group: true),
        currentUserId: 'viewer', messageId: 'two', title: 'Latest proposal')!;
    presenter.show(navigator.currentState!.overlay, second,
        onOpen: () => opened = second.path);
    presenter.show(navigator.currentState!.overlay, first,
        onOpen: () => opened = 'stale');
    await tester.pump();
    expect(find.text('First proposal'), findsNothing);
    expect(find.text('Latest proposal'), findsOneWidget);
    await tester.tap(find.text('View plan'));
    await tester.pump();
    expect(opened, second.path);
    expect(find.text('Latest proposal'), findsNothing);
  });
  testWidgets('delayed older push cannot replace a newer proposal banner',
      (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    final presenter = WatchPlanNoticePresenter();
    await tester.pumpWidget(
        MaterialApp(navigatorKey: navigator, home: const Scaffold()));
    final latest = ForegroundWatchPlanNotice.fromPayload(
        {...payload(), 'occurredAt': '2026-10-04T12:01:00Z'},
        currentUserId: 'viewer', messageId: 'latest', title: 'Latest date')!;
    final older = ForegroundWatchPlanNotice.fromPayload(
        {...payload(), 'occurredAt': '2026-10-04T12:00:00Z'},
        currentUserId: 'viewer', messageId: 'older', title: 'Old date')!;
    presenter.show(navigator.currentState!.overlay, latest, onOpen: () {});
    presenter.show(navigator.currentState!.overlay, older, onOpen: () {});
    await tester.pump();
    expect(find.text('Latest date'), findsOneWidget);
    expect(find.text('Old date'), findsNothing);
    presenter.reset();
    await tester.pump();
  });
  testWidgets(
      'dismiss and logout clear the banner; a repeated event does not reopen it',
      (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    final presenter = WatchPlanNoticePresenter();
    addTearDown(presenter.reset);
    await tester.pumpWidget(
        MaterialApp(navigatorKey: navigator, home: const Scaffold()));
    final notice = ForegroundWatchPlanNotice.fromPayload(payload(),
        currentUserId: 'viewer')!;
    presenter.show(navigator.currentState!.overlay, notice,
        onOpen: () => fail('Dismiss must not navigate'));
    await tester.pump();
    await tester.tap(find.byTooltip('Dismiss update'));
    await tester.pump();
    presenter.show(navigator.currentState!.overlay, notice, onOpen: () {});
    await tester.pump();
    expect(find.byType(WatchPlanNoticeBanner), findsNothing);
    presenter.reset();
    presenter.show(navigator.currentState!.overlay, notice, onOpen: () {});
    await tester.pump();
    expect(find.byType(WatchPlanNoticeBanner), findsOneWidget);
    presenter.reset();
    await tester.pump();
    expect(find.byType(WatchPlanNoticeBanner), findsNothing);
  });
  for (final size in [
    const Size(320, 568),
    const Size(844, 390),
    const Size(1024, 1366)
  ]) {
    testWidgets(
        'banner remains readable and scrollable at $size and large text',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final navigator = GlobalKey<NavigatorState>();
      final presenter = WatchPlanNoticePresenter();
      addTearDown(presenter.reset);
      await tester.pumpWidget(MaterialApp(
          navigatorKey: navigator,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!),
          home: const Scaffold()));
      final notice = ForegroundWatchPlanNotice.fromPayload(payload(),
          currentUserId: 'viewer',
          title: 'Robin suggested a different date for your Watch Plan',
          body:
              'Your friend proposed Saturday for Spider-Man: No Way Home. Open the plan to review the latest date before agreeing.')!;
      presenter.show(navigator.currentState!.overlay, notice, onOpen: () {});
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('View plan'));
      expect(find.text('View plan').hitTestable(), findsOneWidget);
      presenter.reset();
      await tester.pump();
    });
  }
}
