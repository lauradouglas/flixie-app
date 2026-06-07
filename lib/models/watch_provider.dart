class WatchProvider {
  final int id;
  final String providerName;
  final int displayPriority;
  final String logoPath;
  final bool tvShows;
  final bool movies;
  final bool isVisible;
  final bool supportsGb;
  final bool supportsUs;

  const WatchProvider({
    required this.id,
    required this.providerName,
    required this.displayPriority,
    required this.logoPath,
    required this.tvShows,
    required this.movies,
    required this.isVisible,
    required this.supportsGb,
    required this.supportsUs,
  });

  factory WatchProvider.fromJson(Map<String, dynamic> json) {
    return WatchProvider(
      id: json['id'],
      providerName: json['providerName'],
      displayPriority: json['displayPriority'],
      logoPath: json['logoPath'],
      tvShows: json['tvShows'] ?? false,
      movies: json['movies'] ?? false,
      isVisible: json['isVisible'] ?? true,
      supportsGb: json['supportsGb'] ?? false,
      supportsUs: json['supportsUs'] ?? false,
    );
  }

  String get logoUrl => 'https://image.tmdb.org/t/p/w92$logoPath';
}
