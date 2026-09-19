import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/conversation.dart';
import 'package:flixie_app/models/group_watch_request.dart';
import 'package:flixie_app/features/social/presentation/widgets/watch_request_chat_card.dart';

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
  Widget card(String status,
          {VoidCallback? open,
          VoidCallback? decline,
          VoidCallback? accept,
          bool mine = false,
          bool multiple = false}) =>
      WatchRequestChatCard(
          msg: ChatMessage(
              id: 'message',
              senderId: 'laura',
              text: '',
              createdAt: DateTime(2026, 9, 11, 12, 48)),
          cachedRequest: GroupWatchRequest.fromJson({
            'id': 'plan',
            'groupId': 'group',
            'requesterId': 'laura',
            'requesterUsername': 'Laura',
            'movieTitle': status == 'COMPLETED'
                ? 'Mutiny'
                : status == 'SCHEDULED'
                    ? 'The Odyssey'
                    : 'Inception',
            'status': status,
            'acceptedCount': 2,
            'scheduledFor': '2026-09-12T19:30:00',
            'location': 'Odeon Cinema',
            'message': 'Anyone up for this? I can book the tickets.',
            if (multiple)
              'candidates': [
                {
                  'id': 'one',
                  'movie': {'title': 'Inception'}
                },
                {
                  'id': 'two',
                  'movie': {'title': 'The Odyssey'}
                },
              ],
            'responses': [
              {
                'memberId': 'laura',
                'status': 'ACCEPTED',
                'username': 'Laura',
                if (status == 'COMPLETED') 'watchedAt': '2026-09-12'
              },
              {
                'memberId': 'friend',
                'status': 'ACCEPTED',
                'username': 'Jamie',
                if (status == 'COMPLETED') 'missedAt': '2026-09-12'
              },
            ],
          }),
          currentUserId: mine ? 'laura' : 'me',
          myStatus: status == 'OPEN' ? 'PENDING' : 'ACCEPTED',
          isResponding: false,
          onTap: open ?? () {},
          onAccept: accept,
          onDecline: decline ?? () {});
  Widget app(Widget child, {double scale = 1}) => MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Manrope'),
      home: Scaffold(
          backgroundColor: const Color(0xff100a20),
          body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: SingleChildScrollView(child: child))));

  testWidgets('missing plan explains how to find current progress',
      (tester) async {
    await tester.pumpWidget(app(WatchRequestChatCard(
      msg: ChatMessage(
          id: 'missing',
          senderId: 'laura',
          text: 'Watch Plan: Interstellar',
          createdAt: DateTime(2026)),
      isResponding: false,
      onTap: () {},
    )));
    expect(find.text('Plan details unavailable'), findsOneWidget);
    expect(find.text('Open the plan to check its latest progress.'),
        findsOneWidget);
    expect(find.text('Waiting for replies'), findsNothing);
  });

  testWidgets('outgoing open plan explains the next stage', (tester) async {
    await tester.pumpWidget(app(card('OPEN', mine: true)));
    expect(find.text('Waiting for replies'), findsOneWidget);
    expect(
        find.text('Once replies are in, agree when to watch.'), findsOneWidget);
  });

  testWidgets('invitation actions and message stay accessible', (tester) async {
    var opened = 0;
    var declined = 0;
    await tester.pumpWidget(
        app(card('OPEN', open: () => opened++, decline: () => declined++)));
    expect(find.text('Your reply needed'), findsOneWidget);
    expect(find.text('“Anyone up for this? I can book the tickets.”'),
        findsOneWidget);
    await tester.tap(find.text('View invitation'));
    await tester.tap(find.text('Can’t make it'));
    expect(opened, 1);
    expect(declined, 1);
  });
  testWidgets('option B accepts without opening and preserves plan navigation',
      (tester) async {
    var accepted = 0;
    var opened = 0;
    await tester.pumpWidget(
        app(card('OPEN', accept: () => accepted++, open: () => opened++)));
    await tester.tap(find.text("I'm in"));
    expect(accepted, 1);
    expect(opened, 0);
    await tester.tap(find.text('View plan'));
    expect(opened, 1);
  });
  testWidgets('outgoing plan sender sits above the card on the right',
      (tester) async {
    await tester.pumpWidget(app(card('OPEN', mine: true)));
    final avatar = tester.getRect(find.byType(ProfileAvatarView));
    final name = tester.getRect(find.text('You'));
    final title = tester.getRect(find.text('Inception'));
    expect(avatar.bottom, lessThan(title.top));
    expect(name.right, lessThan(avatar.left));
    expect(avatar.center.dx,
        greaterThan(tester.getSize(find.byType(Scaffold)).width / 2));
  });
  testWidgets('summary separates missed attendance from watched',
      (tester) async {
    await tester.pumpWidget(app(card('COMPLETED')));
    expect(find.text('1 watched'), findsOneWidget);
    expect(find.text('1 couldn’t make it'), findsOneWidget);
    expect(find.text('View summary'), findsOneWidget);
    expect(find.text('Can’t make it'), findsNothing);
  });
  testWidgets('cards fit narrow screens and large text', (tester) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final status in [
      'OPEN',
      'SCHEDULED',
      'COMPLETED',
      'CANCELLED',
      'EXPIRED'
    ]) {
      await tester.pumpWidget(app(card(status), scale: 1.8));
      expect(tester.takeException(), isNull, reason: status);
    }
  });
  testWidgets('all movie options appear before invitation actions',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(card('OPEN', multiple: true)));
    await tester.pumpAndSettle();
    expect(find.text('Inception'), findsOneWidget);
    expect(find.text('The Odyssey'), findsOneWidget);
    expect(tester.getTopLeft(find.text('The Odyssey')).dy,
        lessThan(tester.getTopLeft(find.text('View invitation')).dy));
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(Scaffold),
        matchesGoldenFile('goldens/watch_request_movie_options.png'));
  });

  testWidgets('chat card visual states', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(Column(children: [
      card('OPEN', accept: () {}),
      card('SCHEDULED'),
      card('COMPLETED')
    ])));
    await tester.pumpAndSettle();
    await expectLater(find.byType(Scaffold),
        matchesGoldenFile('goldens/watch_request_chat_cards.png'));
  });
}
