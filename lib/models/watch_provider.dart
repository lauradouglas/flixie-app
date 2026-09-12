class WatchProvider {
  final String? watchUrl;
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
    this.watchUrl,
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
      watchUrl: _stringValue(json['watchUrl']),
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

  /// Only a destination supplied by the availability source is actionable.
  /// TMDB supplies a title/country watch page, not individual service deep links.
  Uri? get verifiedWatchUri {
    final uri = Uri.tryParse(watchUrl ?? '');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        !{'www.themoviedb.org', 'themoviedb.org'}.contains(uri.host) ||
        !RegExp(r'^/(movie|tv)/[^/]+/watch(?:/|$)').hasMatch(uri.path)) {
      return null;
    }
    return uri;
  }

  bool get isIncludedOffer => availabilityTypes.any((type) =>
      {'stream', 'streaming', 'flatrate', 'free', 'ads'}.contains(type));
  bool get isFree =>
      availabilityTypes.contains('free') || availabilityTypes.contains('ads');
  bool get isAddOn =>
      RegExp(r'channel|amazon channel|apple tv channel', caseSensitive: false)
          .hasMatch(providerName);

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

  /// TMDB occasionally exposes the same service through a refreshed provider
  /// record (and therefore a different numeric ID/logo). Use this only as a
  /// fallback after the exact ID comparison when identifying a user's saved
  /// service in availability UI.
  String get matchKey => canonicalWatchProviderName(providerName);
}

String canonicalWatchProviderName(String value) => value
    .toLowerCase()
    .replaceAll('&', 'and')
    .replaceAll(RegExp(r'[^a-z0-9]'), '');

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

/// Reject malformed responses so a failed lookup never becomes “no offers”.
List<WatchProvider> parseWatchProviderOffers(dynamic data) {
  if (data is Map<String, dynamic> &&
      data['watchProviders'] is Map<String, dynamic>) {
    return parseWatchProviderOffers(data['watchProviders']);
  }
  final rows = <Map<String, dynamic>>[];
  if (data is List) {
    for (final row in data) {
      if (row is! Map<String, dynamic>) {
        throw const FormatException('Invalid provider');
      }
      rows.add(row);
    }
  } else if (data is Map<String, dynamic>) {
    const groups = {
      'stream': 'stream',
      'flatrate': 'flatrate',
      'free': 'free',
      'ads': 'ads',
      'buy': 'buy',
      'rent': 'rent',
      'providers': 'stream',
      'results': 'stream',
      'streaming': 'stream',
      'watchProviders': 'stream'
    };
    if (!groups.keys.any(data.containsKey)) {
      throw const FormatException('Missing offer groups');
    }
    for (final group in groups.entries) {
      if (!data.containsKey(group.key)) continue;
      final values = data[group.key];
      if (values is! List) throw const FormatException('Invalid offer group');
      for (final row in values) {
        if (row is! Map<String, dynamic>) {
          throw const FormatException('Invalid provider');
        }
        rows.add({
          ...row,
          'availabilityType': row['availabilityType'] ?? group.value
        });
      }
    }
  } else {
    throw const FormatException('Missing availability response');
  }
  final offers = rows.map(WatchProvider.fromJson).toList();
  if (offers.any((p) => p.id <= 0 || p.providerName == 'Provider')) {
    throw const FormatException('Invalid provider identity');
  }
  return offers;
}
