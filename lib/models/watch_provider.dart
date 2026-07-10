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
      id: _intValue(json['id'] ?? json['providerId'] ?? json['provider_id']) ??
          0,
      providerName:
          _stringValue(json['providerName'] ?? json['provider_name']) ??
              'Provider',
      displayPriority:
          _intValue(json['displayPriority'] ?? json['display_priority']) ?? 0,
      logoPath: _stringValue(json['logoPath'] ?? json['logo_path']) ?? '',
      tvShows: json['tvShows'] ?? false,
      movies: json['movies'] ?? false,
      isVisible: json['isVisible'] ?? true,
      supportsGb: json['supportsGb'] ?? false,
      supportsUs: json['supportsUs'] ?? false,
      availabilityTypes: _parseAvailabilityTypes(json),
    );
  }

  String get logoUrl => logoPath.startsWith('http')
      ? logoPath
      : 'https://image.tmdb.org/t/p/w92$logoPath';

  bool get hasExplicitAvailabilityType => availabilityTypes.isNotEmpty;

  bool get isStreaming =>
      availabilityTypes.isEmpty ||
      availabilityTypes.any((type) =>
          type == 'stream' || type == 'streaming' || type == 'flatrate');

  bool get isRental =>
      availabilityTypes.any((type) => type == 'rent' || type == 'rental');

  bool get isPurchase => availabilityTypes.any(
        (type) => type == 'buy' || type == 'purchase' || type == 'purchasable',
      );
}

int? _intValue(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String? _stringValue(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
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
