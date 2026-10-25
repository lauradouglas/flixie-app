// ignore_for_file: invalid_use_of_visible_for_testing_member
// Native screenshot review of production widgets with isolated fixture state.
// No Firebase identity, account, review or watch is created by this target.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/features/authentication/models/signup_journey.dart';
import 'package:flixie_app/features/authentication/data/setup_service.dart';
import 'package:flixie_app/features/authentication/presentation/pages/signup_screen.dart';
import 'package:flixie_app/features/guest/presentation/guest_access.dart';
import 'package:flixie_app/models/watch_provider.dart';
import '../test/features/authentication/signup_journey_test.dart'
    show JourneyData, JourneyAuth, JourneySetup, pumpJourney;
import '../test/app/router/watch_invite_startup_test.dart' show InviteAuth;
import '../test/features/guest/guest_router_test.dart' show GuestReferrals;
import '../test/features/movies/movie_detail_action_flow_test.dart'
    show ActionAnalytics;

const host = String.fromEnvironment('SIGNUP_SCREENSHOT_HOST');
const confirmation = bool.fromEnvironment('SIGNUP_SCREENSHOT_CONFIRM');
String asset(String name) => '$host/assets/$name';

class _Network extends HttpOverrides {}

class _Data extends JourneyData {
  @override
  Future<SetupTitle> title(SignupJourney j) async => SetupTitle(
      j.mediaId,
      j.isShow ? 'Breaking Bad' : 'Alien',
      asset(j.isShow ? 'breaking-bad.jpg' : 'alien.jpg'),
      isShow: j.isShow);
  @override
  Future<List<SetupTitle>> suggestions(SetupTitle t) async => [
        SetupTitle(157336, 'Interstellar', asset('interstellar.jpg'),
            reason: 'Related to ${t.name}'),
        SetupTitle(557, 'Spider-Man', asset('spider-man.jpg'),
            reason: 'Trending now')
      ];
  @override
  Future<List<SetupTitle>> initialSuggestions() async => [
        SetupTitle(348, 'Alien', asset('alien.jpg')),
        SetupTitle(157336, 'Interstellar', asset('interstellar.jpg')),
        SetupTitle(1396, 'Breaking Bad', asset('breaking-bad.jpg'),
            isShow: true)
      ];
}

class _Setup extends JourneySetup {
  @override
  Future<List<SetupTitle>> search(String query, bool shows) async => [
        SetupTitle(348, 'Alien', asset('alien.jpg')),
        SetupTitle(157336, 'Interstellar', asset('interstellar.jpg')),
        SetupTitle(1396, 'Breaking Bad', asset('breaking-bad.jpg'),
            isShow: true),
      ]
          .where((t) =>
              t.isShow == shows &&
              t.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
  @override
  Future<List<WatchProvider>> providers() async => [
        for (final p in [
          (8, 'Netflix', 'netflix.jpg'),
          (9, 'Amazon Prime Video', 'prime.jpg'),
          (337, 'Disney Plus', 'disney.jpg')
        ])
          WatchProvider(
              id: p.$1,
              providerName: p.$2,
              displayPriority: 1,
              logoPath: asset(p.$3),
              tvShows: true,
              movies: true,
              isVisible: true,
              supportsGb: true,
              supportsUs: true)
      ];
}

void main() {
  patrolTest('capture every signup journey screen with real artwork',
      ($) async {
    final tester = $.tester;
    // ignore: invalid_use_of_protected_member
    (tester.binding as LiveTestWidgetsFlutterBinding).setLabel('');
    expect(host, isNotEmpty);
    HttpOverrides.global = _Network();
    String flow = '';
    Future<void> shot(String stage, int part) async {
      await $.pump(const Duration(milliseconds: 350));
      await tester.runAsync(() async {
        final client = HttpClient();
        try {
          final req = await client.postUrl(Uri.parse('$host/capture'));
          req.headers.set('X-Capture-Token',
              const String.fromEnvironment('SIGNUP_SCREENSHOT_TOKEN'));
          req.headers.contentType = ContentType.json;
          req.write(jsonEncode({
            'device': tester.view.physicalSize.shortestSide /
                        tester.view.devicePixelRatio >=
                    600
                ? 'tablet'
                : 'phone',
            'flow': flow,
            'step': stage,
            'part': part,
            'name': '$flow-$stage-$part'
          }));
          final res = await req.close();
          expect(res.statusCode, 200);
          await res.drain<void>();
        } finally {
          client.close(force: true);
        }
      });
    }

    Future<void> capture(String stage) async {
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Scaffold).first);
      await tester.runAsync(() async {
        await Future.wait(tester
                .widgetList<Image>(find.byType(Image))
                .map((i) => precacheImage(i.image, context)))
            .timeout(const Duration(seconds: 15));
      });
      await $.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      final scrolls = tester
          .stateList<ScrollableState>(find.byType(Scrollable))
          .where((s) =>
              s.position.axis == Axis.vertical &&
              s.position.maxScrollExtent > 30)
          .toList()
        ..sort((a, b) =>
            b.position.maxScrollExtent.compareTo(a.position.maxScrollExtent));
      if (scrolls.isEmpty) {
        await shot(stage, 1);
        return;
      }
      final p = scrolls.first.position;
      p.jumpTo(0);
      await shot(stage, 1);
      int part = 1;
      while (p.extentAfter > 20 && part < 6) {
        p.jumpTo(
            (p.pixels + p.viewportDimension * .78).clamp(0, p.maxScrollExtent));
        await shot(stage, ++part);
      }
      p.jumpTo(0);
      await $.pump();
    }

    Future<void> tap(String text) async {
      await tester.ensureVisible(find.text(text).first);
      await tester.tap(find.text(text).first);
      await tester.pumpAndSettle();
    }

    Future<void> searchPreview() async {
      final field = find.byType(TextField).first;
      await tester.ensureVisible(field);
      await tester.enterText(field, 'Interstellar');
      await $.pump(const Duration(milliseconds: 500));
      FocusManager.instance.primaryFocus?.unfocus();
      await capture('10-search-results');
      await tester.enterText(field, '');
      await $.pump(const Duration(milliseconds: 500));
      FocusManager.instance.primaryFocus?.unfocus();
    }

    Future<void> mount(Widget child, AuthProvider auth) async {
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<AnalyticsController>.value(
                value: ActionAnalytics())
          ],
          child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.darkTheme,
              home: child)));
      await tester.pumpAndSettle();
    }

    for (final variant in [
      'watchlist',
      'rate',
      'review',
      'log',
      'episode',
      'home',
      'home-log',
      'profile',
      'watchlist-tv',
      'rate-tv',
      'review-tv'
    ]) {
      if (confirmation &&
          !const {'rate', 'review', 'watchlist-tv', 'rate-tv', 'review-tv'}
              .contains(variant)) {
        continue;
      }
      final editorOnly = confirmation && !variant.endsWith('-tv');
      final action =
          variant == 'home-log' ? 'home' : variant.replaceAll('-tv', '');
      final show = action == 'episode' || variant.endsWith('-tv');
      flow = variant;
      GuestAccess.clear();
      GuestAccess.action = action;
      GuestAccess.destination = action == 'home'
          ? '/'
          : action == 'profile'
              ? '/profile'
              : show
                  ? '/shows/1396'
                  : '/movies/348';
      GuestAccess.bookmarkTitle = show ? 'Breaking Bad' : 'Alien';
      GuestAccess.poster = asset(show ? 'breaking-bad.jpg' : 'alien.jpg');
      ApiClient.useClientForTesting(MockClient((r) async {
        if (r.url.path.endsWith('/avatars')) {
          return http.Response(
              jsonEncode({
                'avatars': [
                  for (final a in [
                    (1, 'alien', 'Alien', 'avatar.png'),
                    (2, 'cat', 'Cat', 'cat.png'),
                    (3, 'corgi', 'Corgi', 'corgi.png')
                  ])
                    {
                      'id': a.$1,
                      'key': a.$2,
                      'displayName': a.$3,
                      'storagePath': 'fixture-only',
                      'imageUrl': asset(a.$4)
                    }
                ]
              }),
              200);
        }
        if (r.url.path.endsWith('/review')) {
          final review = (jsonDecode(r.body) as Map)['review'] as Map;
          return http.Response(
              jsonEncode({...review, 'id': 'fixture-review', 'movieId': 348}),
              200);
        }
        return http.Response(
            jsonEncode(r.url.path.endsWith('/share')
                ? {'url': 'https://www.flixie.co.uk/invite?watch=fixture-only'}
                : {'friendships': []}),
            200);
      }));
      if (!editorOnly && action != 'home' && action != 'profile') {
        await mount(const Scaffold(body: Center(child: Text('Selected title'))),
            InviteAuth());
        unawaited(GuestAccess.require(tester.element(find.byType(Scaffold)),
            path: GuestAccess.destination,
            intent: action,
            mediaTitle: GuestAccess.bookmarkTitle,
            mediaPoster: asset(show ? 'breaking-bad.jpg' : 'alien.jpg')));
        await capture('00-signup-prompt');
        await tap('Keep exploring');
      }
      if (!editorOnly) {
        await mount(
            SignupScreen(referralStore: GuestReferrals()), InviteAuth());
        await capture('01-account');
        await tap('Referred by a friend?');
        await capture('02-referral');
      }
      final auth = JourneyAuth();
      auth.account = auth.account!.copyWith(countryId: 1);
      final router = await pumpJourney(tester, action, _Data(), auth,
          show: show, setup: _Setup());
      await capture('04-first-action');
      if (editorOnly) {
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        router.dispose();
        GuestAccess.clear();
        ApiClient.useClientForTesting(null);
        continue;
      }
      if (action == 'watchlist') {
        await searchPreview();
        await tap('Continue');
        await capture('05-providers');
        await tap('United Kingdom');
        await capture('06-country-picker');
        await tester.tap(find.widgetWithText(ListTile, 'United Kingdom'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(CheckboxListTile, 'Netflix'));
        await tester.pumpAndSettle();
        await capture('07-provider-selection');
      }
      if (action == 'rate') {
        await tester.tap(find.widgetWithText(FlixiePill, '8'));
        await tester.pump();
        await tap('Save rating');
        await capture('05-favourites');
        await searchPreview();
      }
      if (variant == 'home-log') {
        await tap('Log something I’ve watched');
        await capture('12-log-title-picker');
        await tester.tap(find.byTooltip('Log Interstellar'));
        await tester.pumpAndSettle();
        await capture('13-home-log-editor');
      }
      if (action == 'home' && variant != 'home-log') {
        await tap('Add my favourites');
        await capture('05-favourites');
        await searchPreview();
      }
      if (action == 'profile') await searchPreview();
      if (action == 'review') {
        await tester.tap(find.widgetWithText(FlixiePill, '8'));
        await tester.pumpAndSettle();
        await tester.enterText(
            find.byType(TextFormField).first, 'Still a classic');
        await tester.enterText(
            find.byType(TextFormField).last, 'Still an incredible film.');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        await tap('Post review');
        await capture('05-posted');
        if (!show) {
          await tap('Add date & watched with');
          await capture('06-diary');
        }
      }
      if (action == 'log' || (action == 'review' && !show)) {
        await tap('Add someone');
        await capture('07-companion-picker');
        await capture('08-invite-name');
        await tester.enterText(find.byType(TextField).last, 'Sam');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tap('Add to my watch');
        await tap('Save watch');
        await capture('09-saved-invite');
      }
      if (find.text('Choose an avatar (optional)').evaluate().isNotEmpty) {
        await tap('Choose an avatar (optional)');
        await capture('11-optional-avatar');
      }
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      router.dispose();
      GuestAccess.clear();
      ApiClient.useClientForTesting(null);
    }
  }, skip: host.isEmpty, timeout: const Timeout(Duration(minutes: 12)));
}
