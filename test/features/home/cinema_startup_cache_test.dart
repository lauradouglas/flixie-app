import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/home/presentation/widgets/in_cinemas_section.dart';
import 'package:flixie_app/models/movie_short.dart';

void main() {
  testWidgets(
      'changing cinema country clears old titles and rejects late responses',
      (tester) async {
    final gb = Completer<List<MovieShort>>();
    final us = Completer<List<MovieShort>>();
    final countries = <String>[];
    Widget page(String region) => MaterialApp(
            home: Scaffold(
                body: InCinemasSection(
          region: region,
          loadingPlaceholder: const Text('Loading'),
          loader: (country) {
            countries.add(country);
            return country == 'GB' ? gb.future : us.future;
          },
          mediaBuilder: (movies) => Text(movies.single.name),
          onDetails: (_) {},
          onSave: (_) {},
          onTrailer: (_) {},
        )));
    await tester.pumpWidget(page('GB'));
    await tester.pumpWidget(page('US'));
    us.complete(const [MovieShort(id: 1, name: 'US release')]);
    await tester.pump();
    gb.complete(const [MovieShort(id: 2, name: 'UK release')]);
    await tester.pump();
    expect(countries, ['GB', 'US']);
    expect(find.text('US release'), findsOneWidget);
    expect(find.text('UK release'), findsNothing);
  });
  testWidgets(
      'bootstrap cinema titles stay visible while refreshing and on failure',
      (tester) async {
    final response = Completer<List<MovieShort>>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: InCinemasSection(
      region: 'GB',
      initialMovies: const [MovieShort(id: 348, name: 'Alien')],
      loadingPlaceholder: const Text('Waiting for catalogue'),
      mediaBuilder: (movies) => Text(movies.single.name),
      loader: (_) => response.future,
      onDetails: (_) {},
      onSave: (_) {},
      onTrailer: (_) {},
    ))));
    expect(find.text('Alien'), findsOneWidget);
    expect(find.text('Waiting for catalogue'), findsNothing);
    response.completeError(Exception('offline'));
    await tester.pump();
    expect(find.text('Alien'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
