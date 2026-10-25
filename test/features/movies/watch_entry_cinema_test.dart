import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/features/movies/models/watch_log_details.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import '../../support/api_fixture.dart';

void main() {
  test(
      'cinema setting survives API create, read and clear with legacy omission',
      () async {
    final bodies = <Map<String, dynamic>>[];
    var cinema = false;
    useApiFixture(MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      bodies.add(body);
      cinema = body['watchedAtCinema'] as bool? ?? cinema;
      return http.Response(
          jsonEncode({
            'id': 'watch',
            'userId': 'fixture',
            'movieId': 348,
            'removed': false,
            'watchedAtCinema': cinema
          }),
          200);
    }));
    final saved = await UserService.logMovieWatch('fixture',
        const LogMovieWatchRequest(movieId: 348, watchedAtCinema: true));
    expect(saved.watchedAtCinema, isTrue);
    expect(MovieWatchEntry.fromJson(saved.toJson()).watchedAtCinema, isTrue);
    final cleared = await UserService.updateMovieWatch('fixture', 'watch',
        const UpdateMovieWatchRequest(watchedAtCinema: false));
    expect(cleared.watchedAtCinema, isFalse);
    expect(bodies.map((b) => b['watchedAtCinema']), [true, false]);
    expect(
        const UpdateMovieWatchRequest(notes: 'Only editing a comment')
            .toJson()
            .containsKey('watchedAtCinema'),
        isFalse);
    expect(
        MovieWatchEntry.fromJson({
          'id': 'old',
          'userId': 'fixture',
          'movieId': 348,
          'removed': false
        }).watchedAtCinema,
        isFalse);
  });

  for (final view in [
    (size: const Size(390, 844), scale: 1.0),
    (size: const Size(360, 780), scale: 1.5),
    (size: const Size(820, 1000), scale: 1.0),
    (size: const Size(844, 390), scale: 1.0)
  ]) {
    testWidgets(
        'edit cinema independently from date at ${view.size} ${view.scale}',
        (tester) async {
      tester.view.physicalSize = view.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.binding.setSurfaceSize(view.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      WatchLogDetails? details;
      String? savedDate;
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(view.scale)),
              child: child!),
          home: Scaffold(
              body: RewatchLogSheet(
            initial: const MovieWatchEntry(
                id: 'watch',
                userId: 'fixture',
                movieId: 348,
                removed: false,
                watchedAt: '2026-10-12T18:00:00Z',
                watchedAtCinema: true),
            onDetailsChanged: (v) => details = v,
            onSubmit: (
                {required watchedAt,
                required rating,
                required recommended,
                required notes}) async {
              savedDate = watchedAt;
            },
          ))));
      final cinema = find.byKey(const ValueKey('cinema-checkbox'));
      final unknown = find.byKey(const ValueKey('unknown-date-checkbox'));
      expect(tester.widget<CheckboxListTile>(cinema).value, isTrue);
      if (view.scale == 1 && view.size.width == 390) {
        expect(tester.getTopLeft(find.text('Date unsure')).dy,
            tester.getTopLeft(find.text('At cinema')).dy);
      }
      await tester.ensureVisible(cinema);
      await tester.tap(cinema);
      await tester.pump();
      await tester.ensureVisible(unknown);
      await tester.tap(unknown);
      await tester.pump();
      expect(find.text('Date unknown'), findsOneWidget);
      expect(tester.widget<CheckboxListTile>(cinema).value, isFalse);
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(details!.watchedAtCinema, isFalse);
      expect(savedDate, isNull);
      expect(tester.takeException(), isNull);
    });
  }
}
