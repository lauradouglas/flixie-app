import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'support/api_fixture.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/settings/presentation/widgets/around_flixie_sharing_setting.dart';

void main() {
  testWidgets(
      'default Settings control persists the shared account preference across visits',
      (tester) async {
    var stored = false;
    final writes = <Map<String, dynamic>>[];
    useApiFixture(MockClient((request) async {
      expect(request.url.path, '/community/settings');
      if (request.method == 'PUT') {
        final body = Map<String, dynamic>.from(jsonDecode(request.body));
        writes.add(body);
        stored = body['communitySharing'] == true;
      }
      return http.Response(jsonEncode({'communitySharing': stored}), 200);
    }));
    Widget screen(String visit) => MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(
          child: AroundFlixieSharingSetting(key: ValueKey(visit)),
        )));
    await tester.pumpWidget(screen('first'));
    await tester.pumpAndSettle();
    expect(writes, isEmpty);
    expect(find.textContaining('Turning this off does not delete them'),
        findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(writes, [
      {'communitySharing': true}
    ]);
    await tester.pumpWidget(screen('second'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, true);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(writes.last, {'communitySharing': false});
  });

  testWidgets(
      'existing consent loads, saves both directions and rolls back failed changes',
      (tester) async {
    final writes = <bool>[];
    var fail = false;
    Completer<void>? pending;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
      child: AroundFlixieSharingSetting(
          load: () async => true,
          save: (value) async {
            writes.add(value);
            if (fail) throw StateError('offline');
            if (pending != null) await pending!.future;
          }),
    ))));
    await tester.pumpAndSettle();
    final toggle = find.byType(SwitchListTile);
    expect(tester.widget<SwitchListTile>(toggle).value, true);
    expect(writes, isEmpty);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(writes, [false]);
    expect(tester.widget<SwitchListTile>(toggle).value, false);
    fail = true;
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, false);
    expect(find.text('Sharing wasn’t changed. Try again.'), findsOneWidget);
    fail = false;
    pending = Completer<void>();
    await tester.tap(toggle);
    await tester.pump();
    expect(tester.widget<SwitchListTile>(toggle).onChanged, isNull);
    pending!.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, true);
    expect(writes, [false, true, true]);
  });

  testWidgets(
      'failed loading is retryable without writing consent at large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var attempts = 0;
    var writes = 0;
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2)),
      child: Scaffold(
          body: SingleChildScrollView(
              child: AroundFlixieSharingSetting(
        load: () async {
          if (++attempts == 1) throw StateError('offline');
          return false;
        },
        save: (_) async {
          writes++;
        },
      ))),
    )));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNull);
    await tester.ensureVisible(find.text('Retry'));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        false);
    expect(writes, 0);
    expect(tester.takeException(), isNull);
  });
}
