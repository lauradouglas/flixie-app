class LibraryImportRow {
  LibraryImportRow(
      {required this.title,
      required this.source,
      this.year,
      this.imdbId,
      this.sourceUri,
      this.mediaType = 'movie',
      this.rating,
      this.ratingDate,
      this.watchlist = false});

  final String title;
  final String source;
  final int? year;
  final String? imdbId;
  final String? sourceUri;
  final String mediaType;
  int? rating;
  String? ratingDate;
  bool watchlist;
  String status = 'pending';
  Map<String, dynamic>? match;
  List<Map<String, dynamic>> candidates = [];
  Map<String, dynamic>? result;

  String get key =>
      imdbId ?? sourceUri ?? '$mediaType:${title.toLowerCase()}:$year';
  Map<String, dynamic> lookup() => {
        'title': title,
        'mediaType': mediaType,
        if (year != null) 'year': year,
        if (imdbId != null) 'imdbId': imdbId,
      };
  Map<String, dynamic> toJson() => {
        ...lookup(),
        'source': source,
        'sourceUri': sourceUri,
        'rating': rating,
        'ratingDate': ratingDate,
        'watchlist': watchlist,
        'status': status,
        'match': match,
        'candidates': candidates,
        'result': result,
      };
  factory LibraryImportRow.fromJson(Map<String, dynamic> json) =>
      LibraryImportRow(
        title: json['title'],
        source: json['source'],
        year: json['year'],
        imdbId: json['imdbId'],
        sourceUri: json['sourceUri'],
        mediaType: json['mediaType'],
        rating: json['rating'],
        ratingDate: json['ratingDate'],
        watchlist: json['watchlist'],
      )
        ..status = json['status'] ?? 'pending'
        ..match = json['match'] == null
            ? null
            : Map<String, dynamic>.from(json['match'])
        ..candidates = (json['candidates'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        ..result = json['result'] == null
            ? null
            : Map<String, dynamic>.from(json['result']);
}

class LibraryImportData {
  LibraryImportData(this.rows, this.notices);
  final List<LibraryImportRow> rows;
  final List<String> notices;
  Map<String, dynamic> toJson() => {
        'rows': rows.map((e) => e.toJson()).toList(),
        'notices': notices,
      };
  factory LibraryImportData.fromJson(Map<String, dynamic> json) =>
      LibraryImportData(
        (json['rows'] as List)
            .map((e) => LibraryImportRow.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        List<String>.from(json['notices'] ?? []),
      );
}
