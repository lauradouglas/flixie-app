import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import '../test/support/api_fixture.dart';
import '../test/support/availability_batch_fixture.dart';

void main() {
  patrolTest(
      'movie notification opens dated matches and can return to full watchlist',
      ($) async {
    final fixture = AvailabilityBatchFixture(date: '2026-10-24');
    useApiFixture(fixture.client);
    addTearDown(fixture.dispose);
    await $.pumpWidgetAndSettle(fixture.app());
    await $(find.text('View what’s available')).tap();
    await $(find.textContaining('Newly available')).waitUntilVisible();
    expect(fixture.availabilityRequests, 1);
    await $(find.textContaining('Newly available')).tap();
    await $.pumpAndSettle();
    await $(find.byType(TextField).first).enterText('The Odyssey');
    await $.pumpAndSettle();
    await $(find.text('The Odyssey').last).scrollTo();
    expect(find.text('The Odyssey'), findsWidgets);
  });
}
