import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/widgets/preference_switch.dart';
import 'package:flixie_app/features/settings/data/availability_alert_service.dart';
import 'package:flixie_app/features/authentication/presentation/controllers/onboarding_controller.dart';
import 'package:flixie_app/features/authentication/presentation/widgets/onboarding/onboarding_account_choices.dart';
import 'package:flixie_app/models/country.dart';
import 'signup_journey_test.dart' show JourneySetup;

class ChoicesSetup extends JourneySetup {
  final events = <String>[];
  bool failAlerts = false;
  bool sharingEnabled = true;
  Completer<AvailabilityAlertSettings>? pending;
  @override
  Future<bool> sharing() async => sharingEnabled;
  @override
  Future<void> setSharing(bool value) async {
    sharingEnabled = value;
    events.add('sharing:$value');
  }

  @override
  Future<AvailabilityAlertSettings> availabilityAlerts() =>
      pending?.future ??
      Future.value(const AvailabilityAlertSettings(enabled: false));
  @override
  Future<void> saveWatching(
      String id, Country country, Set<int> providers) async {
    events.add('services');
  }

  @override
  Future<void> saveAvailabilityAlerts(bool enabled) async {
    events.add('alerts:$enabled');
    if (failAlerts) throw StateError('offline');
  }

  @override
  Future<bool> enableAvailabilityPush() async {
    events.add('permission');
    return false;
  }
}

void main() {
  OnboardingController owner(ChoicesSetup s) => OnboardingController(
      service: s, userId: 'casey', countryId: 1, isCurrentUser: () => true);
  test(
      'services save before opt-in and permission; failed alerts retain choice for retry',
      () async {
    final s = ChoicesSetup();
    final c = owner(s);
    addTearDown(c.dispose);
    await c.load(includeTaste: false);
    c.selectProvider(1, true);
    c.chooseAvailabilityAlerts(true);
    s.failAlerts = true;
    await expectLater(c.persistWatching(), throwsStateError);
    expect(s.events, ['services', 'alerts:true']);
    expect(c.availabilityAlertsChoice, true);
    s.failAlerts = false;
    await c.persistWatching();
    expect(s.events,
        ['services', 'alerts:true', 'services', 'alerts:true', 'permission']);
    expect(c.availabilityAlertsChoice, isNull);
  });
  test(
      'no prompt or permission without explicit opt-in; off never asks permission',
      () async {
    final s = ChoicesSetup();
    final c = owner(s);
    addTearDown(c.dispose);
    await c.load(includeTaste: false);
    await c.persistWatching();
    expect(s.events, ['services']);
    c.chooseAvailabilityAlerts(false);
    await c.persistWatching();
    expect(s.events, ['services', 'services', 'alerts:false']);
  });
  testWidgets(
      'unloaded alert has no false switch; sharing loads true and can be disabled',
      (t) async {
    final s = ChoicesSetup()..pending = Completer<AvailabilityAlertSettings>();
    final c = owner(s);
    await c.load(includeTaste: false);
    c.selectProvider(1, true);
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: OnboardingAccountChoices(controller: c)))));
    await t.pump();
    final toggles =
        t.widgetList<PreferenceSwitch>(find.byType(PreferenceSwitch)).toList();
    expect(toggles.first.value, isNull);
    expect(toggles.last.value, true);
    expect(s.events, isEmpty);
    s.pending!.complete(const AvailabilityAlertSettings(enabled: true));
    await t.pumpAndSettle();
    expect(
        t
            .widgetList<PreferenceSwitch>(find.byType(PreferenceSwitch))
            .first
            .value,
        true);
    await t.ensureVisible(find.byType(PreferenceSwitch).last);
    await t.tap(find.byType(PreferenceSwitch).last);
    await t.pumpAndSettle();
    expect(s.sharingEnabled, false);
    expect(s.events, ['sharing:false']);
    await t.pumpWidget(const SizedBox.shrink());
    c.dispose();
  });
}
