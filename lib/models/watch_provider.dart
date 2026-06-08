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
  final Set<String> availabilityTypes;

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
    this.availabilityTypes = const {},
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
      availabilityTypes: _parseAvailabilityTypes(json),
    );
  }

  String get logoUrl => 'https://image.tmdb.org/t/p/w92$logoPath';

  bool get hasExplicitAvailabilityType => availabilityTypes.isNotEmpty;

  bool get isStreaming =>
      availabilityTypes.isEmpty ||
      availabilityTypes.any((type) =>
          type == 'stream' || type == 'streaming' || type == 'flatrate');

  bool get isRental =>
      availabilityTypes.any((type) => type == 'rent' || type == 'rental');
}

Set<String> _parseAvailabilityTypes(Map<String, dynamic> json) {
  final raw = <dynamic>[
    json['availabilityType'],
    json['availabilityTypes'],
    json['providerType'],
    json['providerTypes'],
    json['type'],
    json['types'],
    json['monetizationType'],
    json['monetizationTypes'],
  ];

  return raw
      .expand((value) {
        if (value == null) return const <String>[];
        if (value is Iterable) return value.map((item) => item.toString());
        return [value.toString()];
      })
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .toSet();
}
