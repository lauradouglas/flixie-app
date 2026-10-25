import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';

final identity = <String, dynamic>{
  'id': 'fictional-casey',
  'externalId': 'fixture-casey',
  'username': 'casey',
  'firstName': 'Casey',
  'completedSetup': true,
  'profileBadges': ['FOUNDER']
};
final full = {
  ...identity,
  for (final field in [
    'watchedMovies',
    'watchedShows',
    'movieWatchlist',
    'showWatchlist',
    'favoriteMovies',
    'favoriteShows',
    'favoritePeople',
    'favoriteGenres'
  ])
    field: []
};

void main() {
  test(
      'startup opts out of collections while normal profile retains its contract',
      () async {
    final paths = <Uri>[];
    await http.runWithClient(() async {
      final startup =
          await UserService.getStartupUserByExternalId('fixture-casey');
      expect(startup.hasLibrarySnapshot, false);
      expect(startup.movieWatchlist, isNull);
      expect(startup.profileBadges, ['FOUNDER']);
      final library = await UserService.getUserByExternalId('fixture-casey');
      expect(library.hasLibrarySnapshot, true);
      expect(library.movieWatchlist, isEmpty);
    },
        () => MockClient((request) async {
              paths.add(request.url);
              return http.Response(
                  jsonEncode(
                      request.url.queryParameters['profileOnly'] == 'true'
                          ? identity
                          : full),
                  200);
            }));
    expect(paths[0].queryParameters, {'profileOnly': 'true'});
    expect(paths[1].queryParameters, isEmpty);
  });
  test(
      'an older server full response is recognised without a second library fetch',
      () async {
    final user = await http.runWithClient(
        () => UserService.getStartupUserByExternalId('fixture-casey'),
        () => MockClient((_) async => http.Response(jsonEncode(full), 200)));
    expect(user.hasLibrarySnapshot, true);
  });
}
