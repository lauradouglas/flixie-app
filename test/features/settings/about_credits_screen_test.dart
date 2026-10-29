import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:flixie_app/features/settings/presentation/pages/about_credits_screen.dart';

class RecordingLauncher extends UrlLauncherPlatform {
  @override
  Null get linkDelegate => null;
  final opened = <String>[];
  bool succeeds = true;
  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    opened.add(url);
    expect(options.mode, PreferredLaunchMode.externalApplication);
    return succeeds;
  }
}

void main() {
  testWidgets('About opens official Instagram externally and handles failure',
      (tester) async {
    final previous = UrlLauncherPlatform.instance;
    final launcher = RecordingLauncher();
    UrlLauncherPlatform.instance = launcher;
    addTearDown(() => UrlLauncherPlatform.instance = previous);
    await tester.pumpWidget(const MaterialApp(home: AboutCreditsScreen()));
    final link = find.text('Follow Flixie on Instagram · @flixie_co');
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(launcher.opened, ['https://www.instagram.com/flixie_co/']);
    launcher.succeeds = false;
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.text('Unable to open this link.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
