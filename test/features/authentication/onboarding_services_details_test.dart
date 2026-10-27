import 'package:flixie_app/features/authentication/presentation/pages/signup_screen.dart';
import 'package:flixie_app/models/country.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/authentication/presentation/controllers/onboarding_controller.dart';
import 'package:flixie_app/features/authentication/presentation/widgets/onboarding/onboarding_services_step.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'signup_journey_test.dart'
    show JourneySetup, JourneyAuth, JourneyData, pumpJourney;

class _Providers extends JourneySetup {
  static const netflix = WatchProvider(
      id: 8,
      providerName: 'Netflix',
      displayPriority: 1,
      logoPath: '/netflix-fixture.png',
      tvShows: true,
      movies: true,
      isVisible: true,
      supportsGb: true,
      supportsUs: true);
  static const missing = WatchProvider(
      id: 9,
      providerName: 'Unavailable artwork',
      displayPriority: 2,
      logoPath: '',
      tvShows: true,
      movies: true,
      isVisible: true,
      supportsGb: true,
      supportsUs: true);
  @override
  Future<List<WatchProvider>> providers() async => [netflix, missing];
}

// Real Image.network decoding, with deterministic fixture bytes rather than a CDN.
class _Images implements HttpClient {
  final requested = <Uri>[];
  final bytes = File('assets/icon/flixie_text_1024.png').readAsBytesSync();
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requested.add(url);
    return _Request(bytes);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request implements HttpClientRequest {
  _Request(this.bytes);
  final List<int> bytes;
  @override
  Future<HttpClientResponse> close() async => _Response(bytes);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.bytes);
  final List<int> bytes;
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
      Stream.value(bytes).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('country selector tolerates a transient negative keyboard inset',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: const MediaQuery(
            data: MediaQueryData(
                size: Size(834, 1210),
                viewInsets: EdgeInsets.only(bottom: -80)),
            child: Scaffold(
                body: SignupCountryPickerSheet(countries: [
              Country(
                  id: 1,
                  abbreviation: 'GB',
                  name: 'United Kingdom',
                  nativeName: 'United Kingdom')
            ], selected: null)))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('United Kingdom'), findsOneWidget);
    expect(find.text('Select Country'), findsOneWidget);
  });

  testWidgets('signup reuses the existing provider selector and country sheet',
      (tester) async {
    final router =
        await pumpJourney(tester, 'watchlist', JourneyData(), JourneyAuth());
    addTearDown(router.dispose);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingServicesStep), findsOneWidget);
    expect(find.text('Select country'), findsOneWidget);
    await tester.tap(find.text('Select country'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'United Kingdom'));
    await tester.pumpAndSettle();
    expect(find.text('United Kingdom'), findsOneWidget);
    expect(find.text('Search streaming services'), findsOneWidget);
    expect(find.widgetWithText(CheckboxListTile, 'Netflix'), findsOneWidget);
    expect(find.text('Save services & open watchlist'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
  });

  for (final size in [const Size(320, 640), const Size(1024, 768)]) {
    testWidgets(
        'provider details, decoded logo, fallback and search at $size with large text',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final images = _Images();
      final previous = debugNetworkImageHttpClientProvider;
      debugNetworkImageHttpClientProvider = () => images;
      addTearDown(() {
        debugNetworkImageHttpClientProvider = previous;
        PaintingBinding.instance.imageCache.clear();
      });
      final controller = OnboardingController(
          service: _Providers(),
          userId: 'fixture',
          countryId: 1,
          isCurrentUser: () => true);
      final search = TextEditingController();
      addTearDown(controller.dispose);
      addTearDown(search.dispose);
      await controller.load(includeTaste: false);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
              data: MediaQueryData(
                  size: size, textScaler: const TextScaler.linear(2)),
              child: Scaffold(
                  body: SingleChildScrollView(
                      child: AnimatedBuilder(
                          animation: controller,
                          builder: (_, __) => OnboardingServicesStep(
                              controller: controller,
                              search: search,
                              onCountry: () {})))))));
      await tester.runAsync(() => precacheImage(
          NetworkImage(_Providers.netflix.logoUrl),
          tester.element(find.byType(OnboardingServicesStep))));
      await tester.pumpAndSettle();
      // Flutter checks debug globals before addTearDown callbacks run.
      debugNetworkImageHttpClientProvider = previous;
      final row = find.widgetWithText(CheckboxListTile, 'Netflix');
      final logo = find.descendant(of: row, matching: find.byType(RawImage));
      expect(tester.widget<RawImage>(logo).image, isNotNull);
      final image = tester.widget<Image>(
          find.descendant(of: row, matching: find.byType(Image)));
      expect((image.image as NetworkImage).url, _Providers.netflix.logoUrl);
      expect(image.width, 36);
      expect(image.height, 36);
      expect(images.requested.map((u) => u.toString()),
          contains(_Providers.netflix.logoUrl));
      expect(
          find.descendant(
              of: find.widgetWithText(CheckboxListTile, 'Unavailable artwork'),
              matching: find.byIcon(Icons.tv_outlined)),
          findsOneWidget);
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(row).value, true);
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'netf');
      await tester.pumpAndSettle();
      expect(find.text('Netflix'), findsOneWidget);
      expect(find.text('Unavailable artwork'), findsNothing);
      await tester.enterText(find.byType(TextField), 'no matching service');
      await tester.pumpAndSettle();
      expect(
          find.text(
              'No matching services. You can continue without selecting one.'),
          findsOneWidget);
      expect(controller.selectedProviders, contains(8));
      expect(tester.takeException(), isNull);
    });
  }
}
