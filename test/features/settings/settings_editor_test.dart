import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/settings/presentation/pages/settings_screen.dart';
import '../../settings_country_test.dart' show CountryAuth;

void main() {
  const before = bool.fromEnvironment('SETTINGS_BEFORE');
  for (final reset in ['Al', 'Viewer']) {
    testWidgets('editor cancels obsolete username after reset to $reset',
        (tester) async {
      final auth = CountryAuth();
      addTearDown(auth.dispose);
      var countries = 0;
      var checks = 0;
      await http.runWithClient(() async {
        await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: Builder(
                  builder: (context) => Scaffold(
                        body: TextButton(
                            onPressed: () =>
                                showSettingsEditDetailsSheet(context),
                            child: const Text('Edit')),
                      ))),
        ));
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'Alien');
        await tester.pump(const Duration(milliseconds: 200));
        await tester.enterText(find.byType(TextField).first, reset);
        await tester.pump(const Duration(milliseconds: 700));
        expect(checks, before ? 1 : 0);
        expect(countries, 1);
        await tester.pumpWidget(const SizedBox());
      },
          () => MockClient((request) async {
                if (request.url.path.endsWith('/utils/countries')) {
                  countries++;
                  return http.Response(
                      '[{"id":1,"name":"United Kingdom","abbreviation":"GB"}]',
                      200);
                }
                if (request.url.path.endsWith('/exists')) {
                  checks++;
                  return http.Response('false', 200);
                }
                throw StateError('Unexpected request: ${request.url}');
              }));
    });
  }
  testWidgets(
      'account change during save stops remaining writes and cache publication',
      (tester) async {
    final auth = CountryAuth();
    addTearDown(auth.dispose);
    final pending = Completer<http.Response>();
    var writes = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Builder(
                builder: (context) => Scaffold(
                      body: TextButton(
                          onPressed: () =>
                              showSettingsEditDetailsSheet(context),
                          child: const Text('Edit')),
                    ))),
      ));
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Alienfan');
      await tester.pump(const Duration(milliseconds: 700));
      await tester.enterText(find.byType(TextField).at(1), 'A changed bio');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pump();
      expect(writes, 1);
      auth.current = auth.current.copyWith(id: 'other-account');
      pending.complete(http.Response(
          '{"id":"viewer","username":"Alienfan","email":""}', 200));
      await tester.pump();
      expect(writes, 1);
      expect(auth.dbUser.id, 'other-account');
      expect(auth.dbUser.username, 'Viewer');
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/utils/countries')) {
                return http.Response(
                    '[{"id":1,"name":"United Kingdom","abbreviation":"GB"}]',
                    200);
              }
              if (request.url.path.endsWith('/exists')) {
                return http.Response('false', 200);
              }
              if (request.method != 'GET') {
                writes++;
                return pending.future;
              }
              throw StateError('Unexpected ${request.url}');
            }));
  });

  for (final size in [
    const Size(320, 568),
    const Size(844, 390),
    const Size(1024, 1366)
  ]) {
    testWidgets('editor remains scrollable at $size with enlarged text',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = CountryAuth();
      addTearDown(auth.dispose);
      await http.runWithClient(() async {
        await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
              theme: AppTheme.darkTheme,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!),
              home: Builder(
                  builder: (context) => Scaffold(
                      body: TextButton(
                          onPressed: () =>
                              showSettingsEditDetailsSheet(context),
                          child: const Text('Edit'))))),
        ));
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Save Changes'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
          () => MockClient((_) async => http.Response(
              '[{"id":1,"name":"United Kingdom","abbreviation":"GB"}]', 200)));
    });
  }
}
