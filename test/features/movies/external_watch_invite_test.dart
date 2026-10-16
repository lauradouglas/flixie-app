import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/movies/presentation/widgets/watch_invite_signup_context.dart';
import 'package:flixie_app/features/movies/presentation/pages/watch_invite_saved_screen.dart';
import '../../app/router/watch_invite_startup_test.dart' show InviteAuth;
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/pending_watch_invite_store.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/watch_companion_picker.dart';
import 'package:flixie_app/features/movies/presentation/pages/external_watch_invite_screen.dart';
import 'package:flixie_app/features/movies/models/watch_log_details.dart';
import 'package:flixie_app/features/social/data/starred_people.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import '../../support/api_fixture.dart';
import '../../../patrol_test/support/store_screenshot_fixture.dart';

void main() {
  setUpAll(() async {
    for (final family in ['Manrope', '.SF Pro Display', 'Roboto']) {
      await (FontLoader(family)
            ..addFont(
                rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
          .load();
    }
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StarredPeople.instance.loaded = true;
  });
  for (final size in [
    const Size(375, 667),
    const Size(844, 390),
    const Size(1024, 768)
  ]) {
    testWidgets('external name can be entered with keyboard at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      WatchLogDetails? details;
      final previewKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: previewKey,
          child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                  body: Builder(
                      builder: (context) => TextButton(
                          onPressed: () => showMovieWatchLogSheet(
                              context: context,
                              builder: (_) => RewatchLogSheet(
                                  movieTitle: 'Alien',
                                  loadFriends: () async => [],
                                  onDetailsChanged: (value) => details = value,
                                  onSubmit: (
                                      {required watchedAt,
                                      required rating,
                                      required recommended,
                                      required notes}) async {})),
                          child: const Text('Open')))))));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add someone'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Someone who isn’t on Flixie'));
      await tester.pumpAndSettle();
      if (Platform.environment['FLIXIE_INVITE_PREVIEW'] == '1') {
        final boundary = previewKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
              'output/watch-together-mockups/external-invite-${size.width.toInt()}x${size.height.toInt()}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      tester.view.viewInsets = const FakeViewPadding(bottom: 216);
      await tester.pumpAndSettle();
      await tester.enterText(
          find.descendant(
              of: find.byType(WatchCompanionPicker),
              matching: find.byType(TextField)),
          'Sophie');
      await tester.pumpAndSettle();
      await tester
          .ensureVisible(find.widgetWithText(FilledButton, 'Add to my watch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to my watch'));
      await tester.pumpAndSettle();
      expect(find.byType(WatchCompanionPicker), findsNothing);
      expect(details!.externalCompanionName, 'Sophie');
      expect(details!.companion, isNull);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'external invite request carries the name and history retains pending invite',
      (tester) async {
    Map? write;
    useApiFixture(MockClient((request) async {
      write = jsonDecode(request.body) as Map;
      return http.Response(
          jsonEncode({
            'id': 'watch',
            'userId': 'viewer',
            'movieId': 348,
            'removed': false,
            'externalInvite': {
              'id': 'invite',
              'displayName': 'Sophie',
              'expiresAt':
                  DateTime.now().add(const Duration(days: 30)).toIso8601String()
            }
          }),
          200);
    }));
    final watch = await UserService.logMovieWatch(
        'viewer',
        const LogMovieWatchRequest(
            movieId: 348, draftId: 'draft', externalCompanionName: 'Sophie'));
    expect(write!['externalCompanionName'], 'Sophie');
    expect(write!['companionId'], isNull);
    expect(watch.externalInvite!.displayName, 'Sophie');
    expect(
        MovieWatchEntry.fromJson(watch.toJson()).externalInvite!.id, 'invite');
  });
  testWidgets(
      'recipient confirms before claiming and opens the exact watch editor',
      (tester) async {
    final token = 'a' * 43;
    final calls = <String>[];
    await PendingWatchInviteStore.save(token);
    useApiFixture(MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      return http.Response(
          jsonEncode(request.method == 'POST'
              ? {'requestId': 'specific-watch'}
              : {
                  'movie': {'id': 348, 'title': 'Alien'},
                  'watchedAt': null,
                  'owner': {
                    'id': 'laura',
                    'username': 'Laura',
                    'profileBadges': ['EARLY_ADOPTER']
                  }
                }),
          200);
    }));
    final auth = StoreScreenshotAuth();
    final router = GoRouter(initialLocation: '/invite', routes: [
      GoRoute(
          path: '/invite',
          builder: (_, __) => ExternalWatchInviteScreen(token: token)),
      GoRoute(
          path: '/watch-requests/:id',
          builder: (_, state) => Text(
              'Open ${state.pathParameters['id']} log=${state.uri.queryParameters['log']}'))
    ]);
    addTearDown(auth.dispose);
    addTearDown(router.dispose);
    await tester.pumpWidget(storeScreenshotApp(auth, router));
    await tester.pumpAndSettle();
    expect(find.text('Laura says you watched Alien together.'), findsOneWidget);
    expect(calls.where((v) => v.startsWith('POST')), isEmpty);
    await tester.tap(find.text('Log my watch'));
    await tester.pumpAndSettle();
    expect(find.text('Open specific-watch log=true'), findsOneWidget);
    expect(await PendingWatchInviteStore.read(), isNull);
    expect(await PendingWatchInviteStore.readLog('store-viewer'),
        'specific-watch');
    expect(calls.where((v) => v.startsWith('POST')).length, 1);
  });
  testWidgets(
      'Rate now preserves context through signup and automatically opens the invited viewing',
      (tester) async {
    final token = 'b' * 43, calls = <String>[];
    final auth = InviteAuth()..current = AuthStatus.unauthenticated;
    useApiFixture(MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      return http.Response(
          jsonEncode(request.method == 'POST'
              ? {'requestId': 'interstellar-watch'}
              : {
                  'movie': {'id': 157336, 'title': 'Interstellar'},
                  'owner': {
                    'id': 'doug',
                    'username': 'Dougasaur',
                    'profileBadges': ['EARLY_ADOPTER']
                  }
                }),
          200);
    }));
    late GoRouter router;
    router = GoRouter(initialLocation: '/invite', routes: [
      GoRoute(
          path: '/invite',
          builder: (_, __) => ExternalWatchInviteScreen(token: token)),
      GoRoute(
          path: '/auth/signup',
          builder: (_, __) => Scaffold(
                  body: Column(children: [
                const WatchInviteSignupContext(),
                FilledButton(
                    onPressed: () {
                      auth.current = AuthStatus.authenticated;
                      router.go('/invite');
                    },
                    child: const Text('Complete fixture sign-up'))
              ]))),
      GoRoute(
          path: '/watch-requests/:id',
          builder: (_, state) =>
              Scaffold(body: Text('Rate ${state.pathParameters['id']}'))),
    ]);
    addTearDown(router.dispose);
    addTearDown(auth.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp.router(
            theme: AppTheme.darkTheme, routerConfig: router)));
    await tester.pumpAndSettle();
    expect(find.text('Dougasaur says you watched Interstellar together.'),
        findsOneWidget);
    expect(calls, contains('GET /guest/watch-invites/$token'));
    expect(calls.where((v) => v.startsWith('POST')), isEmpty);
    await tester.tap(find.text('Rate now'));
    await tester.pumpAndSettle();
    expect(find.text('Interstellar with Dougasaur'), findsOneWidget);
    expect(await PendingWatchInviteStore.shouldResume(token), isTrue);
    await tester.tap(find.text('Complete fixture sign-up'));
    await tester.pumpAndSettle();
    expect(find.text('Rate interstellar-watch'), findsOneWidget);
    expect(auth.dbUser!.completedSetup, isFalse);
    expect(calls.where((v) => v.startsWith('POST')).length, 1);
    expect(
        await PendingWatchInviteStore.readLog('fixture'), 'interstellar-watch');
  });
  testWidgets(
      'saved invite watch keeps onboarding optional until the member continues',
      (tester) async {
    final auth = InviteAuth()..current = AuthStatus.authenticated;
    await PendingWatchInviteStore.beginLog('plan', 'fixture');
    final router = GoRouter(initialLocation: '/saved', routes: [
      GoRoute(
          path: '/saved',
          builder: (_, __) => const WatchInviteSavedScreen(
              requestId: 'plan', movieTitle: 'Interstellar', rating: 8)),
      GoRoute(
          path: '/onboarding',
          builder: (_, __) => const Scaffold(body: Text('Set up Flixie'))),
    ]);
    addTearDown(router.dispose);
    addTearDown(auth.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp.router(
            theme: AppTheme.darkTheme, routerConfig: router)));
    await tester.pumpAndSettle();
    expect(find.text('8 / 10'), findsOneWidget);
    expect(auth.dbUser!.completedSetup, isFalse);
    await tester.tap(find.text('Finish setting up Flixie'));
    await tester.pumpAndSettle();
    expect(find.text('Set up Flixie'), findsOneWidget);
    expect(await PendingWatchInviteStore.readLog('fixture'), isNull);
  });
}
