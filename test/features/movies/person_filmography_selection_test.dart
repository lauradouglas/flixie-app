import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/person.dart';
import 'package:flixie_app/features/movies/presentation/person_filmography_selection.dart';
import '../../../patrol_test/support/person_detail_fixture.dart';

void main() {
  final source = PersonCredits.fromJson(personFixtureCredits(count: 4));
  final credits = mergePersonCredits(source);
  List<PersonFilmCredit> select(PersonFilmographyFilters filters) =>
      selectPersonCredits(credits,
          filters: filters,
          library: PersonLibraryStatus(
              watched: [1], watchlist: [2], favourites: [1]),
          now: DateTime(2026, 10, 8));
  test('cast/crew merge keeps movie and TV IDs distinct and combines jobs', () {
    expect(credits.length, 5);
    final movie = credits.singleWhere((v) => v.id == 1 && v.isMovie);
    expect(movie.jobs, ['Director', 'Screenplay']);
    expect(movie.roles, ['Captain 1']);
    expect(
        credits.singleWhere((v) => v.id == 1 && !v.isMovie).jobs, ['Producer']);
  });
  for (final role in [
    PersonRoleFilter.director,
    PersonRoleFilter.writer,
    PersonRoleFilter.producer
  ]) {
    test('${role.label} selects the correct movie/show job', () {
      final result = select(PersonFilmographyFilters(role: role));
      expect(result.map((v) => v.title),
          [role == PersonRoleFilter.producer ? 'Alien: Earth' : 'Alien']);
    });
  }
  for (final personal in [
    PersonPersonalFilter.watched,
    PersonPersonalFilter.watchlist,
    PersonPersonalFilter.favourites
  ]) {
    test('${personal.label} never inherits personal flags from same-ID TV', () {
      final result = select(PersonFilmographyFilters(personal: personal));
      expect(result.map((v) => v.title), [
        personal == PersonPersonalFilter.watchlist ? 'The Odyssey' : 'Alien'
      ]);
      expect(result.single.isMovie, isTrue);
    });
  }
  test('search covers title and roles and combines media/year filters', () {
    expect(
        select(const PersonFilmographyFilters(query: '  screenplay '))
            .map((v) => v.title),
        ['Alien']);
    expect(
        select(const PersonFilmographyFilters(
                query: 'alien', media: PersonMediaFilter.tv, year: '2020'))
            .map((v) => v.title),
        ['Alien: Earth']);
    expect(select(const PersonFilmographyFilters(query: 'alien', year: '2027')),
        isEmpty);
  });
  test(
      'newest keeps unreleased titles below released work, all sorts preserve source',
      () {
    expect(select(const PersonFilmographyFilters()).last.title, 'The Odyssey');
    expect(
        select(const PersonFilmographyFilters(sort: PersonCreditSort.popular))
            .first
            .title,
        'Alien');
    expect(
        select(const PersonFilmographyFilters(sort: PersonCreditSort.rating))
            .first
            .title,
        'Alien');
    expect(
        select(const PersonFilmographyFilters(sort: PersonCreditSort.oldest))
            .last
            .title,
        'The Odyssey');
    expect(credits.map((v) => v.title).take(2), ['Alien', 'The Odyssey']);
  });
  test(
      'empty credits and unknown dates remain safe; year can be cleared explicitly',
      () {
    expect(
        selectPersonCredits([],
            filters: const PersonFilmographyFilters(),
            library: PersonLibraryStatus()),
        isEmpty);
    final unknown = PersonCreditItem.fromJson(
        {...personFixtureCredit(5), 'releaseDate': null});
    final result = mergePersonCredits(PersonCredits(
        allCredits: [unknown], knownForCredits: [], crewCredits: []));
    expect(
        selectPersonCredits(result,
                filters: const PersonFilmographyFilters(),
                library: PersonLibraryStatus())
            .single
            .year,
        isNull);
    expect(
        const PersonFilmographyFilters(year: '2027')
            .copyWith(clearYear: true)
            .year,
        isNull);
  });
}
