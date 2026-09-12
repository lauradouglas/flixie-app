import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:flixie_app/features/movies/presentation/widgets/watch_provider_link.dart';
import 'watchlist_movie_row_test.dart' show offer;

class RecordingLauncher extends UrlLauncherPlatform {
  @override
  Null get linkDelegate => null;
  String? opened;
  bool succeeds = true;
  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    opened = url;
    expect(options.mode, PreferredLaunchMode.externalApplication);
    return succeeds;
  }
}

void main() {
  testWidgets('provider opens the supplied movie or show URL in the browser',
      (tester) async {
    final original = UrlLauncherPlatform.instance;
    final launcher = RecordingLauncher();
    UrlLauncherPlatform.instance = launcher;
    addTearDown(() => UrlLauncherPlatform.instance = original);
    for (final type in ['movie', 'tv']) {
      final url = 'https://www.themoviedb.org/$type/123/watch?locale=GB';
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: WatchProviderLink(
        provider: offer('flatrate', url: url),
        child: const Text('Provider'),
      ))));
      await tester.tap(find.text('Provider'));
      await tester.pumpAndSettle();
      expect(launcher.opened, url);
    }
    launcher.succeeds = false;
    await tester.tap(find.text('Provider'));
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t open TMDB. Please try again.'), findsOneWidget);
  });

  testWidgets('missing or untrusted URLs do not create a link', (tester) async {
    for (final url in [null, 'https://example.com/watch']) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: WatchProviderLink(
        provider: offer('flatrate', url: url),
        child: const Text('Provider'),
      ))));
      expect(find.byType(InkWell), findsNothing);
    }
  });
}
