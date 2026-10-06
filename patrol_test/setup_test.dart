import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import '../test/setup_flow_test.dart' show SetupFixture, setupApp;

void main() {
  patrolTest('setup saves movie and TV taste picks and adds a recommendation',
      ($) async {
    final fixture = SetupFixture();
    await $.pumpWidgetAndSettle(setupApp(fixture));
    await $.tester.ensureVisible(find.byKey(const ValueKey('taste-movie:1')));
    await $(find.byKey(const ValueKey('taste-movie:1'))).tap();
    await $.tester.ensureVisible(find.text('Shows'));
    await $('Shows').tap();
    await $.tester.ensureVisible(find.byKey(const ValueKey('taste-show:1')));
    await $(find.byKey(const ValueKey('taste-show:1'))).tap();
    await $.tester.ensureVisible(find.text('Continue'));
    await $('Continue').tap();
    expect(fixture.taste.map((t) => t.key), ['movie:1', 'show:1']);
    await $('Choose country').tap();
    await $('United Kingdom').tap();
    await $.tester.ensureVisible(find.text('Show my first picks'));
    await $('Show my first picks').tap();
    await $.tester.ensureVisible(find.text('Add to watchlist'));
    await $('Add to watchlist').tap();
    await $('Saved').waitUntilVisible();
    expect(fixture.added.single.isShow, isTrue);
    await $.platform.mobile.pressHome();
    await $.platform.mobile.openApp();
    await $('Saved').waitUntilVisible();
  });
}
