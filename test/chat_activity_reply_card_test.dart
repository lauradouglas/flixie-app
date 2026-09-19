import 'package:go_router/go_router.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/social/presentation/utils/activity_reply_payload.dart';
import 'package:flixie_app/features/social/presentation/widgets/chat_bubble.dart';

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
  const activity = ActivityReplyPayload(
      username: 'LauraD',
      activityLabel: 'rating',
      title: 'The Odyssey',
      link: 'flixie://movies/1',
      posterUrl: '',
      rating: 10,
      recommended: true);
  Widget bubble(ActivityReplyPayload payload, {bool isMe = false}) =>
      ChatBubble(
          message: payload.withMessage('noice'),
          senderUsername: 'Dougasaur',
          currentUsername: 'LauraD',
          isMe: isMe,
          sentAt: DateTime(2026, 9, 13, 21, 58));
  Widget app(Widget child, double scale) => MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Manrope'),
      home: Scaffold(
          backgroundColor: const Color(0xFF120A24),
          body: MediaQuery(
              data: MediaQueryData.fromView(
                      WidgetsBinding.instance.platformDispatcher.views.first)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: SingleChildScrollView(child: child))));

  testWidgets('original activity precedes the reply at all sizes',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [320.0, 430.0, 768.0, 1024.0]) {
      tester.view.physicalSize = Size(width, 1100);
      for (final scale in [1.0, 2.0]) {
        for (final mine in [false, true]) {
          await tester.pumpWidget(app(bubble(activity, isMe: mine), scale));
          expect(tester.takeException(), isNull);
          expect(tester.getTopLeft(find.text('The Odyssey')).dy,
              lessThan(tester.getTopLeft(find.text('noice')).dy));
          expect(find.text('10/10'), findsOneWidget);
          expect(find.text('Recommends'), findsOneWidget);
          expect(find.text('Replied to your rating'), findsOneWidget);
          expect(find.text('Open movie'), findsNothing);
          final avatar = tester.getRect(find.byType(ProfileAvatarView));
          final title = tester.getRect(find.text('The Odyssey'));
          expect(avatar.bottom, lessThan(title.top));
          if (mine) {
            expect(avatar.center.dx, greaterThan(width / 2));
            expect(find.text('You'), findsOneWidget);
          } else {
            expect(avatar.center.dx, lessThan(width / 2));
          }
        }
      }
    }
  });

  testWidgets('spoiler review text is not exposed in the quoted activity',
      (tester) async {
    const review = ActivityReplyPayload(
        username: 'LauraD',
        activityLabel: 'review',
        title: 'The Odyssey',
        link: 'flixie://movies/1',
        posterUrl: '',
        reviewTitle: 'The ending',
        reviewBody: 'A spoiler',
        containsSpoilers: true);
    await tester.pumpWidget(app(bubble(review), 1));
    expect(find.text('Contains spoilers'), findsOneWidget);
    expect(find.text('A spoiler'), findsNothing);
    expect(find.text('The ending'), findsNothing);
    expect(find.text('Open movie'), findsNothing);
  });

  testWidgets('poster and title open the movie and ownership survives a rename',
      (tester) async {
    const owned = ActivityReplyPayload(
        userId: 'me',
        username: 'OldUsername',
        activityLabel: 'rating',
        title: 'The Odyssey',
        link: 'flixie://movies/1',
        posterUrl: '');
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, state) => Scaffold(
              body: ChatBubble(
                  message: owned.withMessage('noice'),
                  senderUsername: 'Dougasaur',
                  currentUserId: 'me',
                  currentUsername: 'LauraD',
                  isMe: false,
                  sentAt: DateTime(2026)))),
      GoRoute(
          path: '/movies/:id',
          builder: (_, state) => const Scaffold(body: Text('Movie opened'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text('Replied to your rating'), findsOneWidget);
    await tester.tap(find.text('The Odyssey'));
    await tester.pumpAndSettle();
    expect(find.text('Movie opened'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.movie_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Movie opened'), findsOneWidget);
  });

  testWidgets('option B activity reply appearance', (tester) async {
    tester.view.physicalSize = const Size(430, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(
        Column(children: [bubble(activity), bubble(activity, isMe: true)]), 1));
    await tester.pumpAndSettle();
    await expectLater(find.byType(Scaffold),
        matchesGoldenFile('goldens/chat_activity_reply_option_b.png'));
  });
}
