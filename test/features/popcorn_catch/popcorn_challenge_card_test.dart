import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/popcorn_catch/models/popcorn_challenge.dart';
import 'package:flixie_app/features/popcorn_catch/presentation/widgets/popcorn_challenge_card.dart';
import 'package:flixie_app/features/social/presentation/widgets/chat_bubble.dart';

void main() {
  testWidgets('trusted challenge and reply cards render in chat at large text',
      (t) async {
    t.view.physicalSize = const Size(320, 740);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    for (final score in [null, 560, 420, 480, 0]) {
      final c = PopcornChallenge(
          id: 'fixture',
          score: 480,
          senderId: 'casey',
          recipientId: 'robin',
          senderName: 'Casey',
          recipientName: 'Robin',
          sourceRoundId: 'round',
          resultScore: score);
      await t.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                  body: SingleChildScrollView(
                      child: ChatBubble(
                          message: 'Popcorn Catch',
                          senderUsername: 'Casey',
                          isMe: false,
                          sentAt: DateTime(2026),
                          profileBadges: const ['FOUNDER'],
                          richContent: PopcornChallengeCard(
                              challenge: c,
                              currentUserId: 'robin',
                              result: score != null)))))));
      await t.pumpAndSettle();
      expect(find.text(score == null ? 'Take the challenge' : 'Challenge back'),
          findsOneWidget);
      expect(find.text(score == null ? 'Pip’s Popcorn Catch' : c.resultLabel),
          findsOneWidget);
      expect(t.takeException(), isNull);
    }
  });
}
