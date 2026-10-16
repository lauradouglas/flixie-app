import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
import '../../support/fake_game_audio.dart';
import '../movies/movie_detail_action_flow_test.dart' show ActionAuth;
import 'guest_popcorn_test.dart' show GuestRoundService;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GuestAccess.clear();
    GameAudioSession.backendFactory = FakeGameAudioBackend.new;
  });
  tearDown(() {
    GameAudioSession.backendFactory = NativeGameAudioBackend.new;
    GuestAccess.clear();
  });
  for (final size in [const Size(375, 667), const Size(1024, 768)]) {
    testWidgets(
        'guest plays before signup and keeps score when joining on $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
      for (var i = 0; i < 65; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final c =
          tester.widget<PopcornArena>(find.byType(PopcornArena)).controller;
      for (var i = 0; i < 650 && c.phase == PopcornPhase.playing; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      if (c.phase == PopcornPhase.roundComplete) {
        c.finishRun();
        await tester.pump();
      }
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
