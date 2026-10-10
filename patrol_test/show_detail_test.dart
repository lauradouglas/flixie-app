import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:flixie_app/features/movies/presentation/widgets/show_episode_card.dart';
import '../test/features/movies/show_detail_screen_test.dart'
    show TvDetailFixture, tvDetailApp, openTvEpisodes, scrollTvControlIntoView;

void main() {
  patrolTest('TV watchlist at favourites capacity and episode save Undo',
      ($) async {
    final fixture = TvDetailFixture()..install();
    addTearDown(fixture.dispose);
    await $.pumpWidgetAndSettle(tvDetailApp(fixture));
    await $('Alien: Earth').waitUntilVisible();
    await $('Watchlist').tap();
    await $('Added to watchlist').waitUntilVisible();
    expect(fixture.auth.account!.showWatchlist!.length, 1);
    await $('Favourite').tap();
    await $(find.byIcon(Icons.close_rounded)).tap();
    expect(
        fixture.writes.where((r) => r.url.path.contains('favourite')), isEmpty);
    await openTvEpisodes($.tester);
    final first = find.byType(ShowEpisodeCard).first;
    await scrollTvControlIntoView(
        $.tester, find.descendant(of: first, matching: find.byType(Checkbox)));
    expect(find.text('Pilot reveal'), findsNothing);
    await $(find.descendant(of: first, matching: find.byType(Checkbox))).tap();
    await $('Pilot reveal').waitUntilVisible();
    expect(fixture.watched[1], true);
    await $('Undo').tap();
    await $.pumpAndSettle();
    expect(fixture.watched[1], false);
    expect(find.text('Pilot reveal'), findsNothing);
    final upcoming = find.byType(ShowEpisodeCard).last;
    await scrollTvControlIntoView($.tester,
        find.descendant(of: upcoming, matching: find.byType(Checkbox)));
    expect(
        $.tester
            .widget<Checkbox>(
                find.descendant(of: upcoming, matching: find.byType(Checkbox)))
            .onChanged,
        isNull);
    expect($.tester.takeException(), isNull);
  });
}
