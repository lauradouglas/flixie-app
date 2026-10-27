import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flixie_app/features/authentication/models/signup_journey.dart';
import 'package:flixie_app/features/authentication/data/setup_service.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/features/guest/presentation/guest_access.dart';
import 'package:flixie_app/features/authentication/presentation/pages/signup_screen.dart';
import '../test/features/authentication/signup_journey_test.dart'
    show JourneyData, JourneyAuth, JourneySetup, pumpJourney;
import '../test/app/router/watch_invite_startup_test.dart' show InviteAuth;
import '../test/features/guest/guest_router_test.dart' show GuestReferrals;
import '../test/features/movies/movie_detail_action_flow_test.dart'
    show ActionAnalytics;

class PosterClient extends Fake implements HttpClient {
  PosterClient(this.images);
  final Map<String, Uint8List> images;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      PosterRequest(images[url.pathSegments.last]!);
}

class PosterRequest extends Fake implements HttpClientRequest {
  PosterRequest(this.bytes);
  final Uint8List bytes;
  @override
  Future<HttpClientResponse> close() async => PosterResponse(bytes);
}

class PosterResponse extends Stream<List<int>> implements HttpClientResponse {
  PosterResponse(this.bytes);
  final Uint8List bytes;
  @override
  int get statusCode => 200;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.value(bytes).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PosterJourneyData extends JourneyData {
  @override
  Future<List<SetupTitle>> suggestions(SetupTitle title) async => const [
        SetupTitle(
            157336, 'Interstellar', 'https://fixture.invalid/interstellar.jpg',
            reason: 'Related to Alien'),
        SetupTitle(557, 'Spider-Man', 'https://fixture.invalid/spider-man.jpg',
            reason: 'Trending now')
      ];
  @override
  Future<List<SetupTitle>> initialSuggestions() async => const [
        SetupTitle(348, 'Alien', 'https://fixture.invalid/alien.jpg'),
        SetupTitle(
            157336, 'Interstellar', 'https://fixture.invalid/interstellar.jpg'),
        SetupTitle(557, 'Spider-Man', 'https://fixture.invalid/spider-man.jpg')
      ];
  @override
  Future<SetupTitle> title(SignupJourney journey) async {
    final title = await super.title(journey);
    return SetupTitle(title.id, title.name,
        journey.isShow ? null : 'https://fixture.invalid/alien.jpg',
        isShow: title.isShow);
  }
}

void main() {
  late Map<String, Uint8List> images;
  setUpAll(() async {
    for (final family in ['Manrope', '.SF Pro Display', 'Roboto', 'Ahem']) {
      await (FontLoader(family)
            ..addFont(
                rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
          .load();
    }
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    Directory('output/signup-journeys-native').createSync(recursive: true);
    images = <String, Uint8List>{
      'alien.jpg':
          File('output/contextual-signup/assets/alien.jpg').readAsBytesSync(),
      'interstellar.jpg':
          File('output/contextual-signup/assets/interstellar.jpg')
              .readAsBytesSync(),
      'spider-man.jpg':
          File('output/diary-mockups/spider-man.jpg').readAsBytesSync(),
    };
  });
  tearDownAll(() {
    debugNetworkImageHttpClientProvider = null;
  });
  setUp(() {
    GuestAccess.clear();
    ApiClient.setToken('isolated-preview');
  });
  tearDown(() {
    GuestAccess.clear();
    ApiClient.setToken(null);
    ApiClient.useClientForTesting(null);
  });
  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future.wait(tester
          .widgetList<Image>(find.byType(Image))
          .map((image) => precacheImage(image.image, key.currentContext!)));
    });
    key.currentContext!.findRenderObject()!.reassemble();
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final pixels = await (key.currentContext!.findRenderObject()
              as RenderRepaintBoundary)
          .toImage(pixelRatio: 2);
      final data = await pixels.toByteData(format: ui.ImageByteFormat.png);
      await File('output/signup-journeys-native/$name.png')
          .writeAsBytes(data!.buffer.asUint8List());
      pixels.dispose();
    });
  }

  for (final action in [
    'watchlist',
    'rate',
    'review',
    'log',
    'episode',
    'home',
    'profile'
  ]) {
    testWidgets('render actual $action journey', (tester) async {
      debugNetworkImageHttpClientProvider = () => PosterClient(images);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      ApiClient.useClientForTesting(MockClient((request) async {
        if (request.url.path.endsWith('/review')) {
          final review = (jsonDecode(request.body) as Map)['review'] as Map;
          return http.Response(
              jsonEncode({...review, 'id': 'fixture-review', 'movieId': 348}),
              200);
        }
        return http.Response(
            jsonEncode(request.url.path.endsWith('/share')
                ? {'url': 'https://www.flixie.co.uk/invite?watch=fixture-only'}
                : {'friendships': []}),
            200);
      }));
      final key = GlobalKey();
      final auth = JourneyAuth();
      auth.account = auth.account!.copyWith(countryId: 1);
      final router = await pumpJourney(
          tester, action, PosterJourneyData(), auth,
          show: action == 'episode', boundary: key);
      await capture(tester, key, '$action-01');
      if (action == 'watchlist') {
        await tester.tap(find.text('Skip extra titles').first);
        await capture(tester, key, 'watchlist-02-providers');
      }
      if (action == 'rate') {
        await tester.tap(find.widgetWithText(FlixiePill, '8'));
        await tester.pump();
        await tester.ensureVisible(find.text('Save rating'));
        await tester.tap(find.text('Save rating'));
        await capture(tester, key, 'rate-02-favourites');
      }
      if (action == 'log') {
        await tester.ensureVisible(find.text('Add someone'));
        await tester.tap(find.text('Add someone'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Someone who isn’t on Flixie'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, 'Sam');
        await tester.pump();
        await tester.tap(find.text('Add to my watch'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Save watch'));
        await tester.tap(find.text('Save watch'));
        await capture(tester, key, 'log-02-invite');
      }
      if (action == 'review') {
        await tester.ensureVisible(find.text('8'));
        await tester.tap(find.widgetWithText(FlixiePill, '8'));
        await tester.pumpAndSettle();
        await tester.enterText(
            find.byType(TextFormField).first, 'Still a classic');
        await tester.enterText(
            find.byType(TextFormField).last, 'Still an incredible film.');
        await tester.ensureVisible(find.text('Post review'));
        await tester.tap(find.text('Post review'));
        await capture(tester, key, 'review-02-saved');
        await tester.tap(find.text('Add date & watched with'));
        await capture(tester, key, 'review-03-diary');
      }
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      debugNetworkImageHttpClientProvider = null;
    });
  }
  testWidgets('render actual signup form and optional referral',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    GuestAccess.destination = '/movies/348';
    GuestAccess.action = 'watchlist';
    GuestAccess.bookmarkTitle = 'Alien';
    final key = GlobalKey();
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: InviteAuth()),
          ChangeNotifierProvider<AnalyticsController>.value(
              value: ActionAnalytics())
        ],
        child: RepaintBoundary(
            key: key,
            child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.darkTheme,
                home: SignupScreen(referralStore: GuestReferrals())))));
    await capture(tester, key, 'signup-01');
    await tester.ensureVisible(find.text('Referred by a friend?'));
    await tester.tap(find.text('Referred by a friend?'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Password').first);
    await capture(tester, key, 'signup-02-referral-password');
    debugDefaultTargetPlatformOverride = null;
  });
}
