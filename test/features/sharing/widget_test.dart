import 'package:flixie_app/features/social/data/starred_people.dart';
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
  testWidgets('starred recipient is first and filtering preserves selection',
      (tester) async {
    final auth = ShareAuth();
    addTearDown(auth.dispose);
    StarredPeople.instance.selectAccount('fixture-viewer');
    StarredPeople.instance.ids = {'friend-1'};
    addTearDown(() => StarredPeople.instance.selectAccount(null));
    useApiFixture(MockClient(
        (r) async => http.Response(jsonEncode(friendsPayload(3)), 200)));
    await tester.pumpWidget(shareHost(auth));
    await tester.pumpAndSettle();
    await openPicker(tester, false);
    expect(tester.getTopLeft(find.text('OdysseyFan1')).dy,
        lessThan(tester.getTopLeft(find.text('AlienFan')).dy));
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    final search = find.byType(TextField).first;
    await tester.enterText(search, 'Alien');
    await tester.pumpAndSettle();
    expect(find.text('OdysseyFan1'), findsNothing);
    expect(find.text('AlienFan'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    await tester.enterText(search, '');
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
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
        await tester.ensureVisible(find.byType(TextField).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
