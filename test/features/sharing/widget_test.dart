import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';
import '../../support/api_fixture.dart';
import 'fixture.dart';
import 'journey.dart';

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
  testWidgets('friend selection, send failure and retry',
      (tester) => sendJourney(tester, group: false));
  testWidgets('group selection, show send failure and retry',
      (tester) => sendJourney(tester, group: true));
  testWidgets(
      'dismiss during conversation creation cannot send or pop underlying page',
      dismissJourney);
  testWidgets('account change clears active composer', (tester) async {
    final auth = ShareAuth();
    addTearDown(auth.dispose);
    useApiFixture(MockClient(
        (r) async => http.Response(jsonEncode(friendsPayload(100)), 200)));
    await tester.pumpWidget(shareHost(auth));
    await tester.pumpAndSettle();
    await openPicker(tester, false);
    auth.change('other');
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Account changed. Close this sheet to continue.'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  for (final size in [
    const Size(320, 640),
    const Size(430, 932),
    const Size(844, 390),
    const Size(1024, 1366)
  ]) {
    for (final group in [false, true]) {
      testWidgets('composer $group fits $size at 2x text', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = ShareAuth();
        addTearDown(auth.dispose);
        useApiFixture(MockClient((r) async => http.Response(
            jsonEncode(group ? groupsPayload(100) : friendsPayload(100)),
            200)));
        await tester.pumpWidget(shareHost(auth, scale: 2));
        await tester.pumpAndSettle();
        await openPicker(tester, group);
        await tester.ensureVisible(find.byType(TextField));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
