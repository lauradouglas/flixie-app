import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import '../test/setup_flow_test.dart' show SetupFixture, setupApp;

void main() {
  patrolTest('setup selects optional movie and TV favourites', ($) async {
    final fixture = SetupFixture();
    await $.pumpWidgetAndSettle(setupApp(fixture));
    await $('Skip for now').tap();
    await $.tester.ensureVisible(find.byKey(const ValueKey('taste-movie:1')));
    await $(find.byKey(const ValueKey('taste-movie:1'))).tap();
    await $.tester.ensureVisible(find.text('Shows'));
    await $('Shows').tap();
    await $.tester.ensureVisible(find.byKey(const ValueKey('taste-show:1')));
    await $(find.byKey(const ValueKey('taste-show:1'))).tap();
    await $.tester.ensureVisible(find.text('Continue'));
    await $('Continue').tap();
    expect(fixture.taste.map((t) => t.key), ['movie:1', 'show:1']);
    await $.tester.ensureVisible(find.text('Show my picks'));
    await $('Show my picks').tap();
    await $.tester.ensureVisible(find.text('Add to watchlist'));
    await $('Add to watchlist').tap();
    await $('Added').waitUntilVisible();
    expect(fixture.added.single.isShow, isTrue);
    await $.platform.mobile.pressHome();
    await $.platform.mobile.openApp();
    await $('Added').waitUntilVisible();
  });
}
