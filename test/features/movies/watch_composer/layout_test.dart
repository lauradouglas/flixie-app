import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import '../../../../patrol_test/support/watch_composer_journeys.dart';
import 'fixture.dart';

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(430, 932),
    const Size(844, 390),
    const Size(1024, 1366)
  ]) {
    for (final group in [false, true]) {
      patrolWidgetTest(
          'composer ${group ? 'group' : 'friend'} reflows at $size with 2x text',
          ($) async {
        $.tester.view.physicalSize = size;
        $.tester.view.devicePixelRatio = 1;
        addTearDown($.tester.view.resetPhysicalSize);
        addTearDown($.tester.view.resetDevicePixelRatio);
        await openComposer($, ComposerFixture(), group: group, scale: 2);
        expect($.tester.takeException(), isNull);
        if (!group) await composerTap($, 'Robin');
        final message = find.byType(TextField).last;
        await $.tester.ensureVisible(message);
        await $.pumpAndSettle();
        await $.tester.enterText(message, 'Alien tonight?');
        await $.pumpAndSettle();
        expect($.tester.takeException(), isNull);
        expect(find.text('Alien tonight?'), findsOneWidget);
      });
    }
  }
}
