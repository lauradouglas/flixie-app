import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:flixie_app/features/profile/presentation/widgets/profile_header.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_library_totals.dart';
import 'profile_screen_test.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_stats_content.dart';
import 'package:flixie_app/models/movie_wrapped.dart';

void main() {
  testWidgets('Stats reflows on tablet and retains its ratings action',
      (t) async {
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    t.view.devicePixelRatio = 1;
    var opened = false;
    for (final width in [834.0, 1194.0, 390.0]) {
      t.view.physicalSize = Size(width, 900);
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
        child: ProfileStatsContent(
          wrapped: MovieWrapped.fromJson({'year': 2026, 'totalWatchCount': 14}),
          failed: false,
          onRetry: () {},
          ratings: const [],
          reviewCount: 0,
          favoriteGenres: const [],
          directorPeople: const {},
          onWrapped: () {},
          onFindMovies: () {},
          onSeeRatings: () {
            opened = true;
          },
        ),
      ))));
      await t.pumpAndSettle();
      final watching = t.getRect(find.text('Movie watching · 2026'));
      final ratings = t.getRect(find.text('Your ratings · All time'));
      if (width >= 700) {
        expect(ratings.left, greaterThan(watching.right));
      } else {
        expect(ratings.top, greaterThan(watching.bottom));
      }
      await t.ensureVisible(find.text('– / 10 average · 0 movie ratings'));
      await t.tap(find.text('– / 10 average · 0 movie ratings'));
      expect(opened, isTrue);
      expect(t.takeException(), isNull);
    }
  });

  testWidgets('tablet profile totals share header and activity tab still opens',
      (t) async {
    t.view.physicalSize = const Size(1194, 834);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final f = ProfileScreenFixture();
    addTearDown(f.dispose);
    await http.runWithClient(() async {
      await t.pumpWidget(f.app(1));
      await t.pumpAndSettle();
      final header = t.getRect(find.byType(ProfileHeader));
      final totals = t.getRect(find.byType(ProfileLibraryTotals));
      expect(totals.left, greaterThan(header.right));
      expect(totals.top, lessThan(header.bottom));
      await openProfileTab(t, 'Activity');
      expect(find.text('Favourite films'), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(f.app(2));
      await t.pumpAndSettle();
      expect(t.getRect(find.byType(ProfileLibraryTotals)).top,
          greaterThanOrEqualTo(t.getRect(find.byType(ProfileHeader)).bottom));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    }, () => f.client);
  });
}
