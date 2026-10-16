import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/settings/data/availability_alert_service.dart';
import 'package:flixie_app/features/settings/presentation/widgets/availability_alert_setting.dart';
import '../../support/api_fixture.dart';

const off = AvailabilityAlertSettings(
    enabled: false, countryName: 'United Kingdom', services: ['Netflix']);
Widget host(Widget child) => MaterialApp(
    theme: AppTheme.darkTheme,
    home: Scaffold(body: SingleChildScrollView(child: child)));
void main() {
  testWidgets(
      'explicit opt-in persists to authenticated endpoint; failed opt-out retains confirmed value',
      (tester) async {
    var enabled = false;
    useApiFixture(MockClient((request) async {
      expect(request.url.path, '/availability-alerts');
      if (request.method == 'POST') {
        final data = jsonDecode(request.body);
        expect(data, {'enabled': true});
        enabled = true;
      }
      return http.Response(
          jsonEncode({
            'enabled': enabled,
            'countryName': 'United Kingdom',
            'services': [
              {'providerName': 'Netflix'}
            ]
          }),
          200);
    }));
    await tester.pumpWidget(host(const AvailabilityAlertSetting(
        userId: 'fictional', showPushChoice: false)));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(enabled, isTrue);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue);
    await tester.pumpWidget(host(AvailabilityAlertSetting(
        userId: 'fictional',
        showPushChoice: false,
        save: (_) async => throw Exception('offline'))));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue);
    expect(find.textContaining('Alerts weren’t changed'), findsOneWidget);
  });
  testWidgets('missing setup disables opt-in; load failure offers retry',
      (tester) async {
    var loads = 0;
    await tester.pumpWidget(host(AvailabilityAlertSetting(
        userId: 'fixture',
        showPushChoice: false,
        load: () async {
          if (loads++ == 0) throw Exception('offline');
          return const AvailabilityAlertSettings(enabled: false);
        })));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNull);
    expect(find.textContaining('Choose your country in Account details'),
        findsOneWidget);
  });
  testWidgets('late load from previous account is ignored', (tester) async {
    final pending = Completer<AvailabilityAlertSettings>();
    await tester.pumpWidget(host(AvailabilityAlertSetting(
        userId: 'first', showPushChoice: false, load: () => pending.future)));
    await tester.pumpWidget(host(AvailabilityAlertSetting(
        userId: 'second', showPushChoice: false, load: () async => off)));
    await tester.pumpAndSettle();
    pending.complete(const AvailabilityAlertSettings(
        enabled: true, countryName: 'France', services: ['Other']));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse);
    expect(find.textContaining('France'), findsNothing);
  });
}
