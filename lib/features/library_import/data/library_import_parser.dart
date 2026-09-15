import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'library_import_models.dart';

class LibraryImportFile {
  const LibraryImportFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

/// Pure parsing: source exports never leave the device and no ZIP is extracted.
LibraryImportData parseLibraryImport(List<LibraryImportFile> files) {
  const maxBytes = 20 * 1024 * 1024;
  final rows = <LibraryImportRow>[];
  final notices = <String>[];
  var totalBytes = 0;
  for (final file in files) {
    totalBytes += file.bytes.length;
    if (totalBytes > maxBytes) {
      throw const FormatException('Choose exports totalling 20 MB or less.');
    }
    if (file.name.toLowerCase().endsWith('.zip')) {
      final directory = ZipDirectory()..read(InputMemoryStream(file.bytes));
      if (directory.fileHeaders
              .fold<int>(0, (sum, entry) => sum + entry.uncompressedSize) >
          maxBytes) {
        throw const FormatException(
            'The unzipped export exceeds 20 MB. Choose ratings.csv and watchlist.csv separately.');
      }
      final archive = ZipDecoder().decodeBytes(file.bytes);
      var unpackedBytes = 0;
      var found = false;
      for (final entry in archive) {
        // Only the two account exports: lists/watchlist.csv is a custom list.
        final path = entry.name.replaceAll('\\', '/').toLowerCase();
        final parts = path.split('/');
        final name = parts.last;
        if (!entry.isFile ||
            entry.isSymbolicLink ||
            !{'ratings.csv', 'watchlist.csv'}.contains(name) ||
            parts.contains('lists') ||
            parts.contains('__macosx')) {
          continue;
        }
        unpackedBytes += entry.size;
        if (unpackedBytes > maxBytes) {
          throw const FormatException(
              'The export is too large. Choose ratings.csv and watchlist.csv separately.');
        }
        found = true;
        _parseCsv(name, entry.content, rows, notices);
      }
      if (!found) {
        throw const FormatException(
            'This ZIP has no ratings.csv or watchlist.csv. Choose your Letterboxd account export.');
      }
    } else if (file.name.toLowerCase().endsWith('.csv')) {
      _parseCsv(file.name, file.bytes, rows, notices);
    } else {
      throw const FormatException(
          'Choose a Letterboxd ZIP or an IMDb or Letterboxd CSV export.');
    }
    if (rows.length > 30000) {
      throw const FormatException('Import up to 30,000 rows at a time.');
    }
  }
  final merged = <String, LibraryImportRow>{};
  var duplicates = 0;
  var conflicts = 0;
  for (final row in rows) {
    final previous = merged[row.key];
    if (previous == null) {
      merged[row.key] = row;
    } else {
      duplicates++;
      previous.watchlist |= row.watchlist;
      if (row.rating != null) {
        if (previous.rating != null && previous.rating != row.rating) {
          conflicts++;
        }
        if (previous.rating == null ||
            (row.ratingDate ?? '').compareTo(previous.ratingDate ?? '') > 0) {
          previous.rating = row.rating;
          previous.ratingDate = row.ratingDate;
        }
      }
    }
  }
  if (duplicates > 0) notices.add('$duplicates duplicate rows combined.');
  if (conflicts > 0) {
    notices.add(
        '$conflicts conflicting ratings: the newest dated rating is used; ties keep the first.');
  }
  return LibraryImportData(merged.values.toList(), notices);
}

void _parseCsv(String name, List<int> bytes, List<LibraryImportRow> output,
    List<String> notices) {
  var text = utf8.decode(bytes).replaceFirst(RegExp(r'^\uFEFF'), '');
  // Normalise line endings, including those inside quoted fields.
  text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final table = const CsvToListConverter(
          shouldParseNumbers: false, eol: '\n', allowInvalid: false)
      .convert(text);
  if (table.isEmpty) {
    throw FormatException(
        '$name is empty. Choose an export with ratings or a watchlist.');
  }
  final header =
      table.first.map((e) => e.toString().trim().toLowerCase()).toList();
  final imdb = header.contains('const') && header.contains('title');
  final letterboxd =
      header.contains('name') && header.contains('letterboxd uri');
  if (!imdb && !letterboxd) {
    throw FormatException(
        '$name is not a supported IMDb or Letterboxd export.');
  }
  // IMDb watchlists can contain optional Your Rating/Date Rated columns too.
  final isRatings = imdb
      ? header.contains('your rating') && !header.contains('created')
      : header.contains('rating');
  final isWatchlist = !isRatings && (imdb || header.contains('year'));
  if (!isRatings && !isWatchlist) {
    throw FormatException(
        'Choose a ratings or watchlist export, rather than $name.');
  }
  // Letterboxd watched/diary exports have similar columns but are not watchlists.
  final base = name.toLowerCase().split('/').last;
  if (letterboxd &&
      !isRatings &&
      base != 'watchlist.csv' &&
      !base.startsWith('watchlist (')) {
    throw const FormatException(
        'Choose Letterboxd’s watchlist.csv or ratings.csv, or the complete export ZIP.');
  }
  var invalid = 0;
  var unsupported = 0;
  for (var index = 1; index < table.length; index++) {
    final cells = table[index];
    if (cells.every((e) => e.toString().trim().isEmpty)) continue;
    if (cells.length != header.length) {
      invalid++;
      continue;
    }
    String value(String field) {
      final i = header.indexOf(field);
      return i < 0 ? '' : cells[i].toString().trim();
    }

    final title = value(imdb ? 'title' : 'name');
    final type = value('title type').toLowerCase().replaceAll(' ', '');
    const movieTypes = {
      '',
      'movie',
      'tvmovie',
      'short',
      'tvshort',
      'video',
      'documentary'
    };
    const showTypes = {'tvseries', 'tvminiseries', 'tvmini-series'};
    if (imdb && !movieTypes.contains(type) && !showTypes.contains(type)) {
      unsupported++;
      continue;
    }
    final id = imdb ? value('const') : '';
    final uri = letterboxd
        ? value('letterboxd uri').replaceFirst(RegExp(r'/$'), '')
        : '';
    final yearText = value('year');
    final year = int.tryParse(yearText);
    if (title.isEmpty ||
        title.length > 500 ||
        (imdb && !RegExp(r'^tt\d{5,12}$').hasMatch(id)) ||
        (yearText.isNotEmpty && (year == null || year < 1870 || year > 2200))) {
      invalid++;
      continue;
    }
    int? rating;
    if (isRatings) {
      final raw = double.tryParse(value(imdb ? 'your rating' : 'rating'));
      final scaled = raw == null ? null : raw * (imdb ? 1 : 2);
      if (scaled == null ||
          !scaled.isFinite ||
          scaled < 1 ||
          scaled > 10 ||
          scaled != scaled.roundToDouble()) {
        invalid++;
        continue;
      }
      rating = scaled.toInt();
    }
    final rawDate = value(imdb ? 'date rated' : 'date');
    final date = DateTime.tryParse(rawDate);
    final validDate = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(rawDate) &&
        date != null &&
        date.toIso8601String().startsWith(rawDate) &&
        !date.isAfter(DateTime.now());
    output.add(LibraryImportRow(
        title: title,
        source: imdb ? 'IMDb' : 'Letterboxd',
        year: year,
        imdbId: imdb ? id : null,
        sourceUri: uri.isNotEmpty ? uri : null,
        mediaType: showTypes.contains(type) ? 'show' : 'movie',
        rating: rating,
        ratingDate: isRatings && validDate ? rawDate : null,
        watchlist: isWatchlist));
    if (output.length > 30000) {
      throw const FormatException('Import up to 30,000 rows at a time.');
    }
  }
  if (invalid > 0) {
    notices.add(
        '$name: $invalid rows skipped because a title, year or rating was invalid.');
  }
  if (unsupported > 0) {
    notices.add(
        '$name: $unsupported episodes or other unsupported title types skipped. Films and TV series are supported.');
  }
}
