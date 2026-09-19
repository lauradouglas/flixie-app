import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/app/theme/appearance_controller.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/settings/presentation/widgets/appearance_setting.dart';
import 'package:flixie_app/features/watchlist/presentation/pages/watchlist_screen.dart';
import 'watchlist_screen_states_test.dart' show ScreenAuth, handle;

void main() {
  setUpAll(() async {
    await (FontLoader('Manrope')
          ..addFont(
              rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('appearance persists across restart and safely defaults to dark',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final first = AppearanceController(prefs);
    expect(first.mode, ThemeMode.dark);
    await first.setMode(ThemeMode.light);
    expect(AppearanceController(prefs).mode, ThemeMode.light);
    await first.setMode(ThemeMode.system);
    expect(AppearanceController(prefs).mode, ThemeMode.system);
    first.dispose();
  });
  test('theme changes colours without changing component geometry', () {
    final dark = AppTheme.darkTheme;
    final light = AppTheme.lightTheme;
    expect(light.appBarTheme.centerTitle, dark.appBarTheme.centerTitle);
    expect(light.elevatedButtonTheme.style?.padding,
        dark.elevatedButtonTheme.style?.padding);
    expect(light.elevatedButtonTheme.style?.shape,
        dark.elevatedButtonTheme.style?.shape);
    expect(light.bottomSheetTheme.shape, dark.bottomSheetTheme.shape);
    expect(light.inputDecorationTheme.border, dark.inputDecorationTheme.border);
    expect(const FlixiePalette(Brightness.light).background,
        const Color(0xFFF3EDFC));
  });
  testWidgets(
      'setting updates current route, persists, and follows system appearance',
      (tester) async {
    final appearance =
        AppearanceController(await SharedPreferences.getInstance());
    addTearDown(appearance.dispose);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: appearance,
        child: ListenableBuilder(
            listenable: appearance,
            builder: (_, __) => MaterialApp(
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: appearance.mode,
                home: const Scaffold(body: AppearanceSetting())))));
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(appearance.mode, ThemeMode.light);
    expect(Theme.of(tester.element(find.byType(AppearanceSetting))).brightness,
        Brightness.light);
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(AppearanceSetting))).brightness,
        Brightness.dark);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(AppearanceSetting))).brightness,
        Brightness.light);
    expect(tester.takeException(), isNull);
  });
  for (final size in [
    const Size(320, 568),
    const Size(430, 932),
    const Size(834, 1194),
    const Size(844, 390)
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('light watchlist $size text $scale', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = ScreenAuth();
        addTearDown(auth.dispose);
        final key = GlobalKey();
        await http.runWithClient(() async {
          await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
              value: auth,
              child: MaterialApp(
                  theme: AppTheme.lightTheme,
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!),
                  home: RepaintBoundary(
                      key: key,
                      child: const ColoredBox(
                          color: Color(0xFFF3EDFC),
                          child: WatchlistScreen())))));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
              DefaultTextStyle.of(tester.element(find.text('All'))).style.color,
              const Color(0xFF261735));
          final heading = tester.widget<Text>(find.text('Watchlist').first);
          expect(heading.style?.color, const Color(0xFF261735));
          if (Platform.environment['LIGHT_CAPTURE'] == '1' && scale == 1) {
            await tester.runAsync(() async {
              final image = await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
              final bytes =
                  await image.toByteData(format: ui.ImageByteFormat.png);
              await File('/tmp/light-watchlist-${size.width.toInt()}.png')
                  .writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.ensureVisible(find.text('Genre'));
          await tester.tap(find.text('Genre'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Rom com'));
          await tester.tap(find.text('Rom com'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }, () => MockClient((request) async => handle(request)));
      });
    }
  }
}
