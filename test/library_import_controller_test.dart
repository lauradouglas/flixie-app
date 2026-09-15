import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/features/library_import/data/library_import_controller.dart';
import 'package:flixie_app/features/library_import/data/library_import_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
      'Preview never commits; lost-response retry preserves progress and account ownership',
      () async {
    var fail = true;
    var commits = 0;
    final controller = LibraryImportController(
        userId: 'user-a',
        isCurrentUser: () => true,
        request: (action, body) async {
          expect(body['userId'], 'user-a');
          if (action == 'resolve') {
            return {
              'match': {'id': 603, 'mediaType': 'movie', 'title': 'The Matrix'},
              'candidates': []
            };
          }
          commits++;
          expect(body['id'], 603);
          expect(body.containsKey('imdbId'), isFalse);
          if (fail) throw StateError('Lost response');
          return {'rating': 'kept', 'watchlist': 'added'};
        });
    await controller.setData(LibraryImportData([
      LibraryImportRow(
          title: 'The Matrix',
          source: 'IMDb',
          imdbId: 'tt0133093',
          rating: 9,
          watchlist: true)
    ], []));
    await controller.resolve();
    expect(commits, 0);
    expect(controller.readyCount, 1);
    await controller.commit();
    expect(controller.doneCount, 0);
    expect(controller.error, isNotNull);
    fail = false;
    await controller.commit();
    expect(controller.doneCount, 1);
    final restored =
        LibraryImportController(userId: 'user-a', isCurrentUser: () => true);
    await restored.restore();
    expect(restored.doneCount, 1);
    final otherUser =
        LibraryImportController(userId: 'user-b', isCurrentUser: () => true);
    await otherUser.restore();
    expect(otherUser.data, isNull);
    controller.dispose();
    restored.dispose();
    otherUser.dispose();
  });

  test('Account change stops work before sending another title', () async {
    var current = true;
    var calls = 0;
    final controller = LibraryImportController(
        userId: 'user-a',
        isCurrentUser: () => current,
        request: (_, __) async {
          calls++;
          current = false;
          return {'match': null, 'candidates': []};
        });
    await controller.setData(LibraryImportData([
      LibraryImportRow(title: 'One', source: 'Letterboxd'),
      LibraryImportRow(title: 'Two', source: 'Letterboxd'),
    ], []));
    await controller.resolve();
    expect(calls, 1);
    expect(controller.pendingCount, 1);
    controller.dispose();
  });

  test('Missing server route is reported as an unavailable importer', () async {
    final controller = LibraryImportController(
        userId: 'user-a',
        isCurrentUser: () => true,
        request: (_, __) async => throw const ApiException(
              statusCode: 404,
              message: 'Cannot POST /users/me/library-import/resolve',
            ));
    await controller.setData(LibraryImportData([
      LibraryImportRow(title: 'Arrival', source: 'Letterboxd'),
    ], []));

    await controller.resolve();

    expect(controller.error, contains('temporarily unavailable'));
    expect(controller.error, isNot(contains('Check your connection')));
    controller.dispose();
  });
}
