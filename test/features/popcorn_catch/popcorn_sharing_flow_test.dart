import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/popcorn_catch/data/popcorn_service.dart';
import 'package:flixie_app/features/popcorn_catch/models/popcorn_challenge.dart';
import 'package:flixie_app/features/popcorn_catch/presentation/widgets/popcorn_challenge_card.dart';
import 'package:flixie_app/features/popcorn_catch/presentation/widgets/popcorn_share_sheet.dart';
import 'package:flixie_app/models/friendship.dart';

const challenge = PopcornChallenge(
    id: 'fixture',
    score: 480,
    senderId: 'casey',
    recipientId: 'robin',
    senderName: 'Casey',
    recipientName: 'Robin',
    sourceRoundId: 'round');

class ShareFixture extends PopcornService {
  int sends = 0;
  String? to, key;
  @override
  Future<PopcornChallenge> challenge(String id) async => const PopcornChallenge(
      id: 'fixture',
      score: 480,
      senderId: 'casey',
      recipientId: 'robin',
      senderName: 'Casey',
      recipientName: 'Robin',
      sourceRoundId: 'round');
  @override
  Future<List<int>?> pendingReply(String userId, String id) async => null;
  @override
  Future<PopcornChallenge> share(
      String roundId, String recipientId, String requestKey) async {
    sends++;
    to = recipientId;
    key = requestKey;
    return const PopcornChallenge(
        id: 'fixture',
        score: 480,
        senderId: 'casey',
        recipientId: 'robin',
        senderName: 'Casey',
        recipientName: 'Robin',
        sourceRoundId: 'round');
  }
}

void main() {
  testWidgets(
      'challenge requires explicit first-attempt consent before navigating',
      (t) async {
    final service = ShareFixture();
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (ctx, state) => Scaffold(
              body: SingleChildScrollView(
                  child: PopcornChallengeCard(
                      challenge: challenge,
                      currentUserId: 'robin',
                      service: service)))),
      GoRoute(
          path: '/play/popcorn-catch',
          builder: (ctx, state) => Text(
              'Playing ${state.uri.queryParameters['challenge']} accepted ${state.extra}'))
    ]);
    addTearDown(router.dispose);
    await t.pumpWidget(
        MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router));
    await t.pumpAndSettle();
    await t.tap(find.text('Take the challenge'));
    await t.pumpAndSettle();
    expect(find.text('Ready to challenge Casey?'), findsOneWidget);
    expect(find.textContaining('Your first result will be sent back'),
        findsOneWidget);
    expect(find.textContaining('Playing fixture'), findsNothing);
    await t.tap(find.text('Start my attempt'));
    await t.pumpAndSettle();
    expect(find.text('Playing fixture accepted true'), findsOneWidget);
  });
  testWidgets('friend selection sends a verified round once and opens its chat',
      (t) async {
    final service = ShareFixture();
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (ctx, state) => Scaffold(
              body: TextButton(
                  onPressed: () => showPopcornShareSheet(ctx,
                      roundId: 'round',
                      userId: 'casey',
                      service: service,
                      isCurrent: () => true,
                      loadFriends: () async => const [
                            FriendshipUser(
                                id: 'robin',
                                username: 'Robin',
                                profileBadges: ['FOUNDER'])
                          ]),
                  child: const Text('Share')))),
      GoRoute(
          path: '/chat/:id',
          builder: (ctx, state) => Text('Chat ${state.pathParameters['id']}'))
    ]);
    addTearDown(router.dispose);
    await t.pumpWidget(
        MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router));
    await t.pumpAndSettle();
    await t.tap(find.text('Share'));
    await t.pumpAndSettle();
    expect(service.sends, 0);
    await t.tap(find.text('Robin'));
    await t.pumpAndSettle();
    await t.tap(find.text('Challenge Robin'));
    await t.pumpAndSettle();
    expect(service.sends, 1);
    expect(service.to, 'robin');
    expect(service.key, matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(find.text('Chat robin'), findsOneWidget);
  });
}
