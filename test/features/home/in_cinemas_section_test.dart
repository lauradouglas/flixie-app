import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/home/presentation/widgets/in_cinemas_section.dart';
import 'package:flixie_app/models/movie_short.dart';

void main() {
  const alien = MovieShort(
      id: 348,
      name: 'Alien',
      overview:
          'When the son of an L.A. family disappears. The story continues across several lines.',
      trailer: Trailer(key: 'fictional', site: 'YouTube'));
  Widget host(Widget child) =>
      MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

  testWidgets('cinema retry, refresh and catalogue actions work independently',
      (tester) async {
    final key = GlobalKey<InCinemasSectionState>();
    final regions = <String>[];
    var fail = true;
    final opened = <int>[], saved = <int>[], trailers = <int>[];
    await tester.pumpWidget(host(InCinemasSection(
        key: key,
        region: 'GB',
        loader: (region) async {
          regions.add(region);
          if (fail) throw Exception('offline');
          return [alien];
        },
        onDetails: (m) => opened.add(m.id),
        onSave: (m) => saved.add(m.id),
        onTrailer: (m) => trailers.add(m.id))));
    await tester.pump();
    expect(find.text('Couldn’t load cinema releases.'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('UK cinema releases'), findsOneWidget);
    final synopsis = tester.widget<Text>(find.text(alien.overview!));
    expect(synopsis.maxLines, 3);
    expect(synopsis.data, contains('The story continues'));
    await tester.tap(find.byTooltip('Watchlist'));
    await tester.ensureVisible(find.byTooltip('Details'));
    await tester.tap(find.byTooltip('Details'));
    await tester.tap(find.text('Trailer'));
    expect(opened, [348]);
    expect(saved, [348]);
    expect(trailers, [348]);
    await key.currentState!.refresh();
    await tester.pump();
    expect(regions, ['GB', 'GB', 'GB']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'country changes discard a stale response and show regional empty state',
      (tester) async {
    final pending = Completer<List<MovieShort>>();
    Future<List<MovieShort>> loader(String region) =>
        region == 'GB' ? pending.future : Future.value([]);
    Widget section(String region) => host(InCinemasSection(
        region: region,
        loader: loader,
        onDetails: (_) {},
        onSave: (_) {},
        onTrailer: (_) {}));
    await tester.pumpWidget(section('GB'));
    await tester.pumpWidget(section('US'));
    await tester.pump();
    pending.complete([alien]);
    await tester.pump();
    expect(find.text('US cinema releases'), findsOneWidget);
    expect(find.text('No cinema releases available for this region right now.'),
        findsOneWidget);
    expect(find.text('Alien'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
