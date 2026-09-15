import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:flixie_app/features/authentication/presentation/pages/getting_started_guide_screen.dart';
import 'package:flixie_app/features/library_import/data/library_export_links.dart';

class _RecordingLauncher extends UrlLauncherPlatform {
  @override
  Null get linkDelegate => null;

  final opened = <String>[];

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    opened.add(url);
    expect(options.mode, PreferredLaunchMode.externalApplication);
    return true;
  }
}

void main() {
  testWidgets('guide covers Flixie core journeys', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GettingStartedGuideScreen(openedFromSettings: true),
      ),
    );

    expect(find.textContaining('Favourite on a movie'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.textContaining('movie log'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Move in without starting over'), findsOneWidget);
    expect(find.text('Open IMDb ratings'), findsOneWidget);
    expect(find.text('Open IMDb watchlist'), findsOneWidget);
    expect(find.text('Open Letterboxd export'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Watch Providers'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Watch Plan'), findsOneWidget);
    expect(find.textContaining('create a group'), findsOneWidget);
    expect(find.textContaining('Chat directly'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(
      find.text('Choose selected friends who can add to a joint list'),
      findsOneWidget,
    );
    expect(find.text('Flixie is better with friends'), findsOneWidget);
    expect(find.text('Invite a film friend'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('library guide links open the exact export pages',
      (tester) async {
    final original = UrlLauncherPlatform.instance;
    final launcher = _RecordingLauncher();
    UrlLauncherPlatform.instance = launcher;
    addTearDown(() => UrlLauncherPlatform.instance = original);

    await tester.pumpWidget(
      const MaterialApp(
        home: GettingStartedGuideScreen(openedFromSettings: true),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    for (final entry in {
      'Open IMDb ratings': imdbRatingsExportUrl,
      'Open IMDb watchlist': imdbWatchlistExportUrl,
      'Open Letterboxd export': letterboxdExportUrl,
    }.entries) {
      await tester.ensureVisible(find.text(entry.key));
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(launcher.opened.last, entry.value);
    }
  });

  testWidgets('library guide remains usable on a small phone with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
          ),
          child: child!,
        ),
        home: const GettingStartedGuideScreen(openedFromSettings: true),
      ),
    );
    expect(tester.takeException(), isNull, reason: 'initial guide page');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'keep track page');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'library import page');

    expect(find.text('Move in without starting over'), findsOneWidget);
    await tester.ensureVisible(find.text('Open Letterboxd export'));
    expect(tester.takeException(), isNull);
  });
}
