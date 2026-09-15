import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/library_import/data/library_import_parser.dart';

LibraryImportFile csv(String name, String text) =>
    LibraryImportFile(name, Uint8List.fromList(utf8.encode(text)));

void main() {
  test('Distinct Letterboxd films sharing title and year are not merged', () {
    final data = parseLibraryImport([
      csv('ratings.csv',
          'Date,Name,Year,Letterboxd URI,Rating\n2024-01-01,Film,2020,https://boxd.it/a,3\n2024-01-01,Film,2020,https://boxd.it/b,4\n')
    ]);
    expect(data.rows.length, 2);
  });
  test('IMDb scores and external IDs are preserved; episodes are skipped', () {
    final data = parseLibraryImport([
      csv(
          'ratings.csv',
          'Const,Your Rating,Date Rated,Title,Title Type,Year\r\n'
              'tt0133093,9,2024-02-01,The Matrix,movie,1999\r\n'
              'tt0903747,10,2024-02-02,Breaking Bad,tvSeries,2008\r\n'
              'tt1234567,8,2024-02-02,An episode,tvEpisode,2008\r\n')
    ]);
    expect(data.rows.length, 2);
    expect(data.rows.first.imdbId, 'tt0133093');
    expect(data.rows.first.rating, 9);
    expect(data.rows.first.ratingDate, '2024-02-01');
    expect(data.rows.last.mediaType, 'show');
    expect(data.notices.single, contains('1 episodes'));
  });

  test(
      'IMDb watchlist optional rating columns do not turn it into a ratings export',
      () {
    final data = parseLibraryImport([
      csv(
          'watchlist.csv',
          'Const,Created,Title,Title Type,Year,Your Rating,Date Rated\n'
              'tt0133093,2024-01-01,The Matrix,Movie,1999,,\n')
    ]);
    expect(data.rows.single.watchlist, isTrue);
    expect(data.rows.single.rating, isNull);
  });

  test(
      'Letterboxd ZIP combines ratings and watchlist and ignores private extras',
      () {
    final archive = Archive();
    void add(String name, String text) {
      final bytes = utf8.encode(text);
      archive.add(ArchiveFile(name, bytes.length, bytes));
    }

    add('ratings.csv',
        '\uFEFFDate,Name,Year,Letterboxd URI,Rating\n2024-01-01,"A, Film",2020,https://boxd.it/abc,3.5\n');
    add('watchlist.csv',
        'Date,Name,Year,Letterboxd URI\n2024-01-01,"A, Film",2020,https://boxd.it/abc\n');
    add('profile.csv', 'This must not be parsed');
    add('lists/watchlist.csv', 'This must not be parsed');
    final data = parseLibraryImport([
      LibraryImportFile(
          'export.zip', Uint8List.fromList(ZipEncoder().encode(archive)))
    ]);
    expect(data.rows.single.title, 'A, Film');
    expect(data.rows.single.rating, 7);
    expect(data.rows.single.watchlist, isTrue);
    expect(data.notices.single, contains('1 duplicate'));
  });

  test('Malformed and out-of-range ratings are reported, never rounded', () {
    final data = parseLibraryImport([
      csv(
          'ratings.csv',
          'Date,Name,Year,Letterboxd URI,Rating\n'
              '2024-01-01,Good,2020,https://boxd.it/a,0.5\n'
              '2024-01-01,Bad,2020,https://boxd.it/b,3.3\n'
              '2024-01-01,Too high,2020,https://boxd.it/c,6\n')
    ]);
    expect(data.rows.single.rating, 1);
    expect(data.notices.single, contains('2 rows skipped'));
  });

  test('Newer duplicate rating wins, including when watchlist came first', () {
    final data = parseLibraryImport([
      csv('watchlist.csv',
          'Date,Name,Year,Letterboxd URI\n2024-01-01,Film,2020,https://boxd.it/a\n'),
      csv('ratings.csv',
          'Date,Name,Year,Letterboxd URI,Rating\n2024-01-01,Film,2020,https://boxd.it/a,3\n2024-03-01,Film,2020,https://boxd.it/a,4\n')
    ]);
    expect(data.rows.single.rating, 8);
    expect(data.rows.single.ratingDate, '2024-03-01');
    expect(data.rows.single.watchlist, isTrue);
  });

  test('Unrelated CSV and Letterboxd watched export are rejected', () {
    expect(() => parseLibraryImport([csv('random.csv', 'title,score\nFilm,7')]),
        throwsFormatException);
    expect(
        () => parseLibraryImport([
              csv('watched.csv',
                  'Date,Name,Year,Letterboxd URI\n2024-01-01,Film,2020,https://boxd.it/a')
            ]),
        throwsFormatException);
  });

  test('Invalid calendar dates are never treated as watched or rating dates',
      () {
    final data = parseLibraryImport([
      csv('ratings.csv',
          'Date,Name,Year,Letterboxd URI,Rating\n2024-02-31,Film,2020,https://boxd.it/a,4\n')
    ]);
    expect(data.rows.single.ratingDate, isNull);
  });
}
