import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/show.dart';

void main() {
  final now = DateTime.utc(2026, 8, 7);

  TvEpisode episode(int id, int season, int number,
          {bool watched = false, String? airDate}) =>
      TvEpisode(
        id: id,
        seasonNumber: season,
        episodeNumber: number,
        name: 'Episode $number',
        watched: watched,
        airDate: airDate ?? '2026-08-01',
      );

  TvShow show(List<TvEpisode> episodes, {String status = 'Returning Series'}) =>
      TvShow(id: 10, name: 'Test show', episodes: episodes, status: status);

  test('never-started show offers its first released episode', () {
    final progress = TvShowEpisodeProgress(
      show([episode(1, 1, 1), episode(2, 1, 2)]),
      now: now,
    );
    expect(progress.hasStarted, isFalse);
    expect(progress.watchedCount, 0);
    expect(progress.nextReleased?.id, 1);
  });

  test('partially watched season reports released episodes remaining', () {
    final progress = TvShowEpisodeProgress(
      show([episode(1, 1, 1, watched: true), episode(2, 1, 2)]),
      now: now,
    );
    expect(progress.watchedCount, 1);
    expect(progress.remainingCount, 1);
    expect(progress.nextReleased?.episodeNumber, 2);
  });

  test('caught-up returning show excludes an unreleased next episode', () {
    final progress = TvShowEpisodeProgress(
      show([
        episode(1, 1, 1, watched: true),
        episode(2, 1, 2, airDate: '2026-08-14'),
      ]),
      now: now,
    );
    expect(progress.isCaughtUp, isTrue);
    expect(progress.releasedCount, 1);
    expect(progress.nextReleased, isNull);
    expect(progress.nextScheduled?.id, 2);
  });

  test('fully watched ended show is complete', () {
    final progress = TvShowEpisodeProgress(
      show([
        episode(1, 1, 1, watched: true),
        episode(2, 1, 2, watched: true),
      ], status: 'Ended'),
      now: now,
    );
    expect(progress.isCaughtUp, isTrue);
    expect(progress.remainingCount, 0);
  });

  test('specials remain Season 0 and sort before Season 1', () {
    final progress = TvShowEpisodeProgress(
      show([episode(2, 1, 1), episode(1, 0, 1)]),
      now: now,
    );
    expect(progress.allEpisodes.map((item) => item.seasonNumber), [0, 1]);
  });

  test('missing air dates are safely treated as available', () {
    final progress = TvShowEpisodeProgress(
      const TvShow(
        id: 10,
        name: 'Missing data',
        episodes: [
          TvEpisode(id: 1, seasonNumber: 1, episodeNumber: 1, name: 'Pilot'),
        ],
      ),
      now: now,
    );
    expect(progress.releasedCount, 1);
    expect(progress.nextReleased?.id, 1);
  });

  test('parses multiple episode watches when supplied by the API', () {
    final parsed = TvEpisode.fromJson({
      'id': 4,
      'seasonNumber': 2,
      'episodeNumber': 3,
      'name': 'Again',
      'userState': {'watched': true, 'watchCount': 3},
    });
    expect(parsed.watched, isTrue);
    expect(parsed.watchCount, 3);
  });

  test('show safely accepts missing artwork and providers', () {
    final parsed = TvShow.fromJson({'id': 5, 'name': 'Sparse show'});
    expect(parsed.posterPath, isNull);
    expect(parsed.watchProviders, isEmpty);
    expect(parsed.seasons, isEmpty);
  });

  test('parses show friend summary counts and compact friend rows', () {
    final summary = TvShowFriendSummary.fromJson({
      'friendCount': 2,
      'watchedCount': 2,
      'watchlistCount': 1,
      'favouriteCount': 1,
      'shouldIWatchThis': {
        'recommendedCount': 1,
        'friends': [
          {
            'userId': 'friend-1',
            'username': 'Laura',
            'rating': 9,
            'recommends': true,
            'watchedAt': '2026-08-01T12:00:00Z',
          }
        ],
      },
    });
    expect(summary.friendCount, 2);
    expect(summary.ratedCount, 1);
    expect(summary.recommendedCount, 1);
    expect(summary.watchlistCount, 1);
    expect(summary.favouriteCount, 1);
    expect(summary.friends.single.watched, isTrue);
    expect(summary.friends.single.rating, 9);
  });

  test('parses the backend show credits response shape', () {
    final credits = TvShowCredits.fromJson({
      'castMembers': [
        {
          'id': 101,
          'name': 'Sarah Snook',
          'character': 'Shiv Roy',
          'profileImage': 'https://image.example/sarah.jpg',
        }
      ],
      'crewMembers': [
        {'id': 202, 'name': 'Jesse Armstrong', 'job': 'Creator'}
      ],
    });
    expect(credits.cast.single.name, 'Sarah Snook');
    expect(credits.cast.single.character, 'Shiv Roy');
    expect(credits.cast.single.profilePath, 'https://image.example/sarah.jpg');
    expect(credits.crew.single.role, 'Creator');
  });

  test('parses canonical cast and crew keys', () {
    final credits = TvShowCredits.fromJson({
      'cast': [
        {'id': 1, 'name': 'Actor', 'character': 'Lead'}
      ],
      'crew': [
        {'id': 2, 'name': 'Creator', 'job': 'Creator'}
      ],
    });
    expect(credits.cast.single.name, 'Actor');
    expect(credits.crew.single.name, 'Creator');
  });
}
