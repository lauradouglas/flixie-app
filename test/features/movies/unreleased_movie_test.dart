import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../../support/api_fixture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/movie_detail_hero.dart';
import 'package:flixie_app/features/movies/presentation/widgets/show_detail_hero.dart';
import 'package:flixie_app/models/movie.dart';
import 'package:flixie_app/models/show.dart';

void main() {
  testWidgets('compact quick-log metadata is fetched before showing the editor',
      (t) async {
    var lookups = 0;
    useApiFixture(MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, endsWith('/movies/id/999991'));
      lookups++;
      return http.Response(
          jsonEncode({
            'id': 999991,
            'title': 'Obsession fixture',
            'releaseDate': '2999-01-01'
          }),
          200);
    }));
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showMovieWatchLogSheet<void>(
                        context: context,
                        movieId: 999991,
                        builder: (_) => const Text('Watch editor')),
                    child: const Text('Log watch'))))));
    await t.tap(find.text('Log watch'));
    await t.pumpAndSettle();
    expect(lookups, 1);
    expect(find.text('This film isn’t out yet'), findsOneWidget);
    expect(find.textContaining('Obsession fixture hasn’t'), findsOneWidget);
    // Dismissing with Back is cancellation, never implicit approval.
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text('Watch editor'), findsNothing);
  });
  for (final size in [
    const Size(320, 568),
    const Size(844, 390),
    const Size(820, 1180)
  ]) {
    testWidgets(
        'warning cancels without opening editor, override opens editor at $size',
        (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      t.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      var opened = 0;
      await t.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => showMovieWatchLogSheet<void>(
                          context: context,
                          movieId: 1,
                          movieTitle: 'The Odyssey',
                          releaseDate: '2999-07-15',
                          builder: (_) {
                            opened++;
                            return const SizedBox(
                                height: 100, child: Text('Watch editor'));
                          }),
                      child: const Text('Log watch'))))));
      await t.tap(find.text('Log watch'));
      await t.pumpAndSettle();
      expect(find.text('This film isn’t out yet'), findsOneWidget);
      expect(opened, 0);
      await t.ensureVisible(find.text('Go back'));
      await t.tap(find.text('Go back'));
      await t.pumpAndSettle();
      expect(opened, 0);
      expect(find.text('This film isn’t out yet'), findsNothing);
      await t.tap(find.text('Log watch'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Log watch anyway'));
      await t.tap(find.text('Log watch anyway'));
      await t.pumpAndSettle();
      expect(opened, 1);
      expect(find.text('Watch editor'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
    for (final show in [false, true]) {
      testWidgets(
          'unreleased ${show ? 'show' : 'movie'} label reflows at $size',
          (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        t.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        await t.pumpWidget(MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
                body: CustomScrollView(slivers: [
              if (show)
                const ShowDetailHero(
                    show: TvShow(
                        id: 1,
                        name: 'Spider-Man: a fictional upcoming series',
                        firstAirDate: '2999-07-15'))
              else
                SliverToBoxAdapter(
                    child: MovieDetailHero(
                        movie: const Movie(
                            id: 1,
                            title: 'The Odyssey',
                            releaseDate: '2999-07-15'),
                        onShowScoreInfo: () {}))
            ]))));
        await t.pumpAndSettle();
        expect(find.text('Not released yet'), findsOneWidget);
        expect(find.text('Expected 15 Jul 2999'), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  }
  for (final editing in [false, true]) {
    testWidgets(
        'released movies and existing watch edits skip warning: $editing',
        (t) async {
      await t.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => showMovieWatchLogSheet<void>(
                          context: context,
                          movieId: 1,
                          releaseDate: editing ? '2999-01-01' : '2000-01-01',
                          editingExisting: editing,
                          builder: (_) => const SizedBox(
                              height: 100, child: Text('Watch editor'))),
                      child: const Text('Log watch'))))));
      await t.tap(find.text('Log watch'));
      await t.pumpAndSettle();
      expect(find.text('Watch editor'), findsOneWidget);
      expect(find.text('This film isn’t out yet'), findsNothing);
    });
  }
}
