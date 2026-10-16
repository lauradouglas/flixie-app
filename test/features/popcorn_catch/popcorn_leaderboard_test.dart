import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/popcorn_catch/models/popcorn_leaderboard.dart';
import 'package:flixie_app/features/popcorn_catch/presentation/controllers/popcorn_controller.dart';
import 'package:flixie_app/features/popcorn_catch/presentation/pages/popcorn_leaderboard_screen.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';

void main() {
  testWidgets(
      'leaderboard preserves borders, score and round, and accessible footer actions',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final size in [
      const Size(320, 568),
      const Size(393, 852),
      const Size(844, 390),
      const Size(1024, 768)
    ]) {
      for (final scale in [1.0, 2.0]) {
        tester.view.physicalSize = size;
        final c = PopcornController(userId: null);
        c.board = const PopcornLeaderboard(
            personalBest: 2450,
            personalRank: 4,
            items: [
              PopcornEntry(
                  rank: 1,
                  score: 4280,
                  roundReached: 9,
                  userId: 'robin',
                  username: 'Robin',
                  profileBadges: ['EARLY_ADOPTER']),
              PopcornEntry(
                  rank: 4,
                  score: 2450,
                  roundReached: 6,
                  userId: 'casey',
                  username: 'Casey with a long display name',
                  profileBadges: ['FOUNDER']),
            ]);
        var plays = 0, removes = 0;
        await tester.pumpWidget(MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    padding: const EdgeInsets.only(top: 59, bottom: 34),
                    textScaler: TextScaler.linear(scale)),
                child: child!),
            home: PopcornLeaderboardScreen(
                controller: c,
                userId: 'casey',
                onRemove: () => removes++,
                onPlay: () => plays++,
                playLabel: 'Play again')));
        await tester.pumpAndSettle();
        expect(find.text('Popcorn legends'), findsOneWidget);
        expect(find.text('2,450'), findsOneWidget);
        expect(find.text('Round 6'), findsOneWidget);
        final avatars = tester
            .widgetList<ProfileAvatarView>(find.byType(ProfileAvatarView))
            .toList();
        expect(avatars.last.profileBadges, ['FOUNDER']);
        for (final label in ['Play again', 'Remove my score']) {
          await tester.ensureVisible(find.text(label));
          await tester.pumpAndSettle();
          expect(find.text(label).hitTestable(), findsOneWidget);
          expect(tester.getRect(find.text(label)).bottom,
              lessThanOrEqualTo(size.height - 34));
          await tester.tap(find.text(label));
        }
        expect(plays, 1);
        expect(removes, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        c.dispose();
      }
    }
  });
}
