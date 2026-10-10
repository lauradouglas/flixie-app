import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/show.dart';
import 'package:flixie_app/features/movies/presentation/widgets/show_status_badge.dart';
import 'package:flixie_app/features/movies/presentation/widgets/show_detail_hero.dart';
import 'package:flixie_app/features/movies/presentation/widgets/show_detail_metadata.dart';

void main() {
  test('years use final year for finished shows and present for active shows',
      () {
    TvShow show(String? status, String? first, String? last) => TvShow(
        id: 101,
        name: 'The Newsroom',
        status: status,
        firstAirDate: first,
        lastAirDate: last);
    expect(
        showYearRange(show('Ended', '2012-06-24', '2014-12-14')), '2012–2014');
    expect(showYearRange(show('Returning Series', '2012-06-24', '2025-12-14')),
        '2012–present');
    expect(showYearRange(show('Canceled', '2012-06-24', '2012-12-14')), '2012');
    expect(showYearRange(show('Ended', null, null)), isNull);
  });
  testWidgets(
      'status appears only in info and statuses have distinct badge colours',
      (tester) async {
    const show = TvShow(
        id: 101,
        name: 'The Newsroom',
        status: 'Ended',
        firstAirDate: '2012-06-24',
        lastAirDate: '2014-12-14');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CustomScrollView(slivers: [
      const ShowDetailHero(show: show),
      SliverToBoxAdapter(child: ShowInfoSection(show: show, credits: const []))
    ]))));
    expect(find.text('2012–2014'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(ShowDetailHero), matching: find.text('Ended')),
        findsNothing);
    expect(find.byType(ShowStatusBadge), findsOneWidget);
    final pill = tester.getRect(find.byType(ShowStatusBadge));
    final info = tester.getRect(find.byType(ShowInfoSection));
    expect(pill.right, info.right);
    expect(pill.width, lessThan(150));
    final colors = <Color?>{};
    for (final status in [
      'Ended',
      'Returning Series',
      'Canceled',
      'In Production'
    ]) {
      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: ShowStatusBadge(status: status))));
      colors.add(tester.widget<Text>(find.text(status)).style!.color);
    }
    expect(colors.length, 4);
    expect(tester.takeException(), isNull);
  });
}
