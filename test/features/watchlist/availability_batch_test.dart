import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/features/watchlist/presentation/widgets/watchlist_movie_row.dart';
import 'package:flixie_app/features/watchlist/presentation/pages/watchlist_screen.dart';
import '../../support/availability_batch_fixture.dart';

void main() {
  for (final (size, scale) in [
    (const Size(320, 640), 2.0),
    (const Size(430, 900), 1.0),
    (const Size(1000, 720), 1.0),
    (const Size(640, 320), 2.0),
  ]) {
    testWidgets(
        'movie batch opens dated watchlist and untoggles at $size scale $scale',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final now = DateTime.now();
      final day =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final fixture = AvailabilityBatchFixture(date: day);
      ApiClient.useClientForTesting(fixture.client);
      addTearDown(() {
        ApiClient.useClientForTesting(null);
        fixture.dispose();
      });
      await tester.pumpWidget(fixture.app(textScale: scale));
      expect(find.text('2 films from your watchlist'), findsOneWidget);
      final cta = find.text('View what’s available');
      await tester.ensureVisible(cta);
      await tester.tap(cta);
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<WatchlistScreen>(find.byType(WatchlistScreen))
              .availableOn,
          day);
      expect(find.text('Newly available today'), findsOneWidget);
      expect(fixture.availabilityRequests, 1);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Newly available today'));
      await tester.pumpAndSettle();
      // Search after removing the date filter must find the unrelated saved film.
      final search = find.byType(TextField).first;
      await tester.ensureVisible(search);
      await tester.enterText(search, 'The Odyssey');
      await tester.pumpAndSettle();
      final row = find.byType(WatchlistMovieRow);
      await tester.scrollUntilVisible(row, 300,
          scrollable: find
              .descendant(
                  of: find.byKey(const ValueKey('watchlist-cards')),
                  matching: find.byType(Scrollable))
              .first);
      await tester.pumpAndSettle();
      expect(find.text('The Odyssey'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('older movie batch keeps its original date', (tester) async {
    final fixture = AvailabilityBatchFixture(date: '2020-01-02');
    ApiClient.useClientForTesting(fixture.client);
    addTearDown(() {
      ApiClient.useClientForTesting(null);
      fixture.dispose();
    });
    await tester.pumpWidget(fixture.app());
    await tester.tap(find.text('View what’s available'));
    await tester.pumpAndSettle();
    expect(find.text('Newly available · Jan 2, 2020'), findsOneWidget);
    expect(find.text('Newly available today'), findsNothing);
  });
}
