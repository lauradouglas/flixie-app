import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:flixie_app/features/movies/presentation/trailers/trailer_player_sheet.dart';

class _Launcher extends UrlLauncherPlatform {
  @override
  Null get linkDelegate => null;
  String? launched;
  bool succeeds = true;
  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched = url;
    return succeeds;
  }
}

void main() {
  final systemCalls = <MethodCall>[];
  setUp(() {
    systemCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      systemCalls.add(call);
      return null;
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
  test(
      'iPhone native configuration permits both trailer landscape orientations',
      () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final orientations = RegExp(
      r'<key>UISupportedInterfaceOrientations</key>\s*<array>([\s\S]*?)</array>',
    ).firstMatch(plist)!.group(1)!;
    expect(orientations, contains('UIInterfaceOrientationLandscapeLeft'));
    expect(orientations, contains('UIInterfaceOrientationLandscapeRight'));
    expect(orientations, contains('UIInterfaceOrientationPortrait'));
  });

  const id = 'dQw4w9WgXcQ';
  test('normalises supported trailer sources and rejects unrelated URLs', () {
    for (final source in [
      id,
      ' $id ',
      'https://www.youtube.com/watch?v=$id&t=4',
      'https://youtube.com/embed/$id',
      'https://youtu.be/$id',
      'https://www.youtube-nocookie.com/embed/$id',
      'https://m.youtube.com/shorts/$id'
    ]) {
      expect(trailerVideoId(source), id, reason: source);
    }
    for (final source in [
      '',
      'bad-id',
      'https://evil.com/watch?v=$id',
      'https://youtube.com.evil.com/embed/$id',
      'javascript:alert(1)',
      'https://youtube.com/watch?v=invalid'
    ]) {
      expect(trailerVideoId(source), isNull, reason: source);
    }
  });

  Future<void> mount(WidgetTester tester, {String source = id}) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
      builder: (context) => TextButton(
          onPressed: () => showTrailerPlayerSheet(context,
              source: source,
              title: 'Alien trailer',
              playerBuilder: (videoId) => AspectRatio(
                  aspectRatio: 16 / 9, child: Text('Playing $videoId'))),
          child: const Text('Watch trailer')),
    ))));
    await tester.tap(find.text('Watch trailer'));
    await tester.pumpAndSettle();
  }

  testWidgets('trailer tap opens in-app sheet and close returns to page',
      (tester) async {
    await mount(tester);
    expect(find.text('Alien trailer'), findsOneWidget);
    expect(find.text('Playing $id'), findsOneWidget);
    expect(
        systemCalls
            .where((c) => c.method == 'SystemChrome.setPreferredOrientations')
            .first
            .arguments,
        [
          'DeviceOrientation.landscapeLeft',
          'DeviceOrientation.landscapeRight'
        ]);
    expect(find.byTooltip('Close trailer'), findsOneWidget);
    expect(tester.getRect(find.byTooltip('Close trailer')).top, lessThan(80));
    await tester.tap(find.byTooltip('Close trailer'));
    await tester.pumpAndSettle();
    expect(find.text('Alien trailer'), findsNothing);
    expect(find.byTooltip('Close trailer'), findsNothing);
    expect(find.text('Watch trailer'), findsOneWidget);
    expect(
        systemCalls
            .where((c) => c.method == 'SystemChrome.setPreferredOrientations')
            .last
            .arguments,
        ['DeviceOrientation.portraitUp']);
    expect(
        systemCalls
            .where((c) => c.method == 'SystemChrome.setEnabledSystemUIMode')
            .last
            .arguments,
        'SystemUiMode.edgeToEdge');
  });

  testWidgets('closing hides the player until portrait restoration completes',
      (tester) async {
    await mount(tester);
    final portrait = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations' &&
          (call.arguments as List).contains('DeviceOrientation.portraitUp')) {
        await portrait.future;
      }
      return null;
    });
    await tester.tap(find.byTooltip('Close trailer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Playing $id'), findsNothing);
    expect(find.text('Watch trailer'), findsNothing);
    portrait.complete();
    await tester.pumpAndSettle();
    expect(find.text('Watch trailer'), findsOneWidget);
  });

  testWidgets('invalid trailer shows recovery without creating a player',
      (tester) async {
    await mount(tester, source: 'invalid');
    expect(find.text('This trailer is unavailable.'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets(
      'YouTube fallback launches canonical URL and closes playback sheet',
      (tester) async {
    final previous = UrlLauncherPlatform.instance;
    final launcher = _Launcher();
    UrlLauncherPlatform.instance = launcher;
    addTearDown(() => UrlLauncherPlatform.instance = previous);
    await mount(tester);
    await tester.tap(find.text('Open in YouTube'));
    await tester.pumpAndSettle();
    expect(launcher.launched, 'https://www.youtube.com/watch?v=$id');
    expect(find.text('Alien trailer'), findsNothing);
  });

  testWidgets(
      'failed external launch retains the player and shows retry feedback',
      (tester) async {
    final previous = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = _Launcher()..succeeds = false;
    addTearDown(() => UrlLauncherPlatform.instance = previous);
    await mount(tester);
    await tester.tap(find.text('Open in YouTube'));
    await tester.pumpAndSettle();
    expect(find.text('Alien trailer'), findsOneWidget);
    expect(
        find.text('Couldn’t open YouTube. Please try again.'), findsOneWidget);
  });

  for (final size in [
    const Size(320, 568),
    const Size(844, 390),
    const Size(1024, 1366)
  ]) {
    testWidgets('player and actions fit $size with enlarged text',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await mount(tester);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Open in YouTube'));
      expect(find.text('Open in YouTube'), findsOneWidget);
    });
  }
}
