import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patrol/patrol.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/popcorn_catch/models/popcorn_challenge.dart';
import 'package:flixie_app/features/popcorn_catch/models/popcorn_leaderboard.dart';
import 'package:flixie_app/features/popcorn_catch/presentation/pages/popcorn_catch_screen.dart';
import 'package:flixie_app/features/popcorn_catch/presentation/widgets/popcorn_challenge_card.dart';
import '../tool/preview_popcorn_catch.dart';

const fixture = PopcornChallenge(
    id: 'fictional-challenge',
    score: 480,
    senderId: 'fictional-casey',
    recipientId: 'fictional-robin',
    senderName: 'Casey',
    recipientName: 'Robin',
    sourceRoundId: 'fictional-round');

class _FirstAttemptService extends PreviewPopcornService {
  int replies = 0;
  @override
  Future<PopcornChallenge> challenge(String id) async => fixture;
  @override
  Future<PopcornRound> startChallenge(String id) async =>
      const PopcornRound('fictional-attempt', 1, personalBest: 480);
  @override
  Future<List<int>?> pendingReply(String userId, String id) async => null;
  @override
  Future<void> rememberReply(
      String userId, String id, List<int> targets) async {}
  @override
  Future<void> clearReply(String userId, String id) async {}
  @override
  Future<int> reply(String id, List<int> targets) async {
    replies++;
    return 10;
  }
}

void main() {
  patrolTest(
      'friend accepts one attempt and its verified result replies without public posting',
      ($) async {
    final service = _FirstAttemptService();
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
              body: SingleChildScrollView(
                  child: PopcornChallengeCard(
                      challenge: fixture,
                      currentUserId: 'fictional-robin',
                      service: service)))),
      GoRoute(
          path: '/play/popcorn-catch',
          builder: (context, state) => PopcornCatchScreen(
              userId: 'fictional-robin',
              service: service,
              challengeId: state.uri.queryParameters['challenge'],
              autoStartChallenge: state.extra == true))
    ]);
    addTearDown(router.dispose);
    await $.pumpWidgetAndSettle(
        MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router));
    await $.tester.tap(find.text('Take the challenge'));
    await $.pumpAndSettle();
    expect(find.textContaining('Your first result will be sent back'),
        findsOneWidget);
    await $.tester.tap(find.text('Start my attempt'));
    for (var i = 0; i < 680; i++) {
      await $.pump(const Duration(milliseconds: 50));
    }
    await $.pumpAndSettle();
    expect(find.text('First result sent to your friend'), findsOneWidget);
    expect(service.replies, 1);
    expect(service.best, isNull);
    expect(find.text('Post to leaderboard'), findsNothing);
    expect($.tester.takeException(), isNull);
  });
}
