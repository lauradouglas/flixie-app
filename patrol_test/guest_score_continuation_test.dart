import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/guest/presentation/guest_access.dart';
import 'package:flixie_app/features/pip_games/audio/game_audio.dart';
import 'package:flixie_app/features/popcorn_catch/presentation/pages/popcorn_catch_screen.dart';
import 'package:flixie_app/features/popcorn_catch/presentation/widgets/popcorn_arena.dart';
import 'package:flixie_app/features/popcorn_catch/presentation/controllers/popcorn_controller.dart';
import '../test/support/fake_game_audio.dart';
import '../test/features/movies/movie_detail_action_flow_test.dart'
    show ActionAuth;
import '../test/features/popcorn_catch/guest_popcorn_test.dart'
    show GuestRoundService;

void main() {
  setUp(() {
    // Native fixture storage never touches a real account.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    GuestAccess.clear();
    // Keep native fixture audio deterministic.
    // ignore: invalid_use_of_visible_for_testing_member
    GameAudioSession.backendFactory = FakeGameAudioBackend.new;
  });
  tearDown(() {
    // Keep native fixture audio deterministic.
    // ignore: invalid_use_of_visible_for_testing_member
    GameAudioSession.backendFactory = NativeGameAudioBackend.new;
    GuestAccess.clear();
  });
  for (final size in [const Size(375, 667)]) {
    patrolTest(
        'guest plays before signup and keeps score when joining on $size',
        ($) async {
      final tester = $.tester;
      final service = GuestRoundService(), auth = ActionAuth();
      late final GoRouter router;
      router = GoRouter(initialLocation: '/guest-game', routes: [
        GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: Text('Home after game'))),
        GoRoute(
            path: '/guest-game',
            builder: (_, __) =>
                PopcornCatchScreen(userId: null, service: service)),
        GoRoute(
            path: '/auth/signup',
            builder: (_, __) => Scaffold(
                body: TextButton(
                    onPressed: () => router.go('/member-game'),
                    child: const Text('Registration')))),
        GoRoute(
            path: '/member-game',
            builder: (_, __) => PopcornCatchScreen(
                userId: 'fictional-casey', service: service)),
      ]);
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp.router(
              theme: AppTheme.darkTheme, routerConfig: router)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Start round 1'));
      await tester.tap(find.text('Start round 1'));
      await tester.pump();
      final c =
          tester.widget<PopcornArena>(find.byType(PopcornArena)).controller;
      // Native frames use wall time. A fixed number of pumps can finish before
      // the countdown, and a slow device can legitimately pause after a hitch.
      final deadline = DateTime.now().add(const Duration(seconds: 75));
      while (c.phase != PopcornPhase.finished &&
          DateTime.now().isBefore(deadline)) {
        if (c.phase == PopcornPhase.paused) {
          await tester.tap(find.text('Resume round'));
        } else if (c.phase == PopcornPhase.roundComplete) {
          await tester.ensureVisible(find.text('Finish run & keep score'));
          await tester.tap(find.text('Finish run & keep score'));
        }
        await tester.pump(const Duration(milliseconds: 50));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(c.phase, PopcornPhase.finished,
          reason: 'Native guest round must finish before starting signup');
      await tester.pumpAndSettle();
      expect(find.text('Join to post this score'), findsOneWidget);
      expect(find.text('Challenge a friend'), findsNothing);
      expect(service.posts, 0);
      await tester.ensureVisible(find.text('Join to post this score'));
      await tester.tap(find.text('Join to post this score'));
      await tester.pumpAndSettle();
      expect(find.text('Put your score on the board'), findsOneWidget);
      await tester.ensureVisible(find.text('Keep exploring'));
      await tester.tap(find.text('Keep exploring'));
      await tester.pumpAndSettle();
      expect(find.text('Put your score on the board'), findsNothing);
      expect(find.text('Join to post this score'), findsOneWidget);
      await tester.ensureVisible(find.text('Join to post this score'));
      await tester.tap(find.text('Join to post this score'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create account'));
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(find.text('Registration'), findsOneWidget);
      expect(GuestAccess.destination, '/play/popcorn-catch');
      expect(await service.pendingGuestScore(), isNotNull);
      expect(service.posts, 0);
      expect(service.claims, 0);
      // Simulate completion of authentication; no real account is created.
      await tester.tap(find.text('Registration'));
      await tester.pumpAndSettle();
      expect(find.text('Post to leaderboard'), findsOneWidget);
      expect(service.posts, 0);
      expect(service.claims, 0);
      await tester.ensureVisible(find.text('Post to leaderboard'));
      await tester.tap(find.text('Post to leaderboard'));
      await tester.pumpAndSettle();
      expect(find.text('Score posted'), findsOneWidget);
      expect(service.posts, 1);
      expect(service.claims, 1);
      expect(await service.pendingGuestScore(), isNull);
      await tester.tap(find.byTooltip('Close game'));
      await tester.pumpAndSettle();
      expect(find.text('Home after game'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      auth.dispose();
    });
  }
}
