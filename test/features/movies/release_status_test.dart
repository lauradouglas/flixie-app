import 'package:flixie_app/models/show.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/movies/domain/release_status.dart';

void main() {
  test('show label only applies before any episode has aired', () {
    final now = DateTime(2026, 10, 17);
    const aired = TvEpisode(
        id: 1,
        seasonNumber: 1,
        episodeNumber: 1,
        name: 'Pilot',
        airDate: '2026-10-17');
    expect(
        isShowNotReleasedYet(
            const TvShow(
                id: 1,
                name: 'Upcoming',
                firstAirDate: '2027-01-01',
                status: 'Planned'),
            now: now),
        isTrue);
    expect(
        isShowNotReleasedYet(
            const TvShow(
                id: 1,
                name: 'Returning',
                firstAirDate: '2025-01-01',
                status: 'In Production'),
            now: now),
        isFalse);
    expect(
        isShowNotReleasedYet(
            const TvShow(
                id: 1,
                name: 'Stale premiere',
                firstAirDate: '2027-01-01',
                episodes: [aired]),
            now: now),
        isFalse);
    expect(
        isShowNotReleasedYet(
            const TvShow(
                id: 1,
                name: 'Nested episode',
                status: 'Planned',
                seasons: [
                  TvSeason(
                      id: 1,
                      seasonNumber: 1,
                      name: 'Season 1',
                      episodes: [aired])
                ]),
            now: now),
        isFalse);
    expect(
        isShowNotReleasedYet(
            const TvShow(
                id: 1,
                name: 'Already started',
                status: 'Planned',
                lastAirDate: '2026-10-16'),
            now: now),
        isFalse);
    expect(isShowNotReleasedYet(const TvShow(id: 1, name: 'Unknown'), now: now),
        isFalse);
  });

  test('future release, release day and missing catalogue dates', () {
    final now = DateTime(2026, 10, 17, 12);
    expect(isNotReleasedYet(date: '2026-10-18', now: now), isTrue);
    expect(isNotReleasedYet(date: '2026-10-17', now: now), isFalse);
    expect(
        isNotReleasedYet(date: '2025-01-01', status: 'In Production', now: now),
        isFalse);
    expect(isNotReleasedYet(status: 'Returning Series', now: now), isFalse);
    expect(isNotReleasedYet(status: 'Planned', now: now), isTrue);
    expect(isNotReleasedYet(now: now), isFalse);
    expect(releaseCalendarDate('2026-02-31'), isNull);
    expect(expectedReleaseLabel(null), 'Release date to be announced');
  });
}
