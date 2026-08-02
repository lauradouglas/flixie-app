import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/models/favorite_movie.dart';
import 'package:flixie_app/models/watched_movie.dart';
import 'package:flixie_app/models/watchlist_movie.dart';
import 'package:flixie_app/models/profile_avatar.dart';

class User {
  final String id;
  final String? externalId;
  final String? firstName;
  final String? lastName;
  final String username;
  final String email;
  final String? bio;
  final int iconColorId;
  final int? countryId;
  final int? languageId;
  final bool completedSetup;
  final bool darkMode;
  final String? createdAt;
  final String? updatedAt;
  final String? initials;

  // Nested objects
  final Map<String, dynamic>? country;
  final Map<String, dynamic>? language;
  final Map<String, dynamic>? iconColor;
  final ProfileAvatar? avatar;
  final List<String> profileBadges;

  // Lists
  final List<WatchedMovie>? watchedMovies;
  final List<dynamic>? watchedShows;
  final List<WatchlistMovie>? movieWatchlist;
  final List<dynamic>? showWatchlist;
  final List<FavoriteMovie>? favoriteMovies;
  final List<dynamic>? favoriteShows;
  final List<dynamic>? favoritePeople;
  final List<dynamic>? favoriteGenres;

  const User({
    required this.id,
    this.externalId,
    this.firstName,
    this.lastName,
    required this.username,
    required this.email,
    this.bio,
    required this.iconColorId,
    this.countryId,
    this.languageId,
    required this.completedSetup,
    required this.darkMode,
    this.createdAt,
    this.updatedAt,
    this.initials,
    this.country,
    this.language,
    this.iconColor,
    this.avatar,
    this.profileBadges = const [],
    this.watchedMovies,
    this.watchedShows,
    this.movieWatchlist,
    this.showWatchlist,
    this.favoriteMovies,
    this.favoriteShows,
    this.favoritePeople,
    this.favoriteGenres,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: _stringOrFallback(json['id']),
      externalId: _nullableString(json['externalId']),
      firstName: _nullableString(json['firstName']),
      lastName: _nullableString(json['lastName']),
      username: _stringOrFallback(json['username'], fallback: 'user'),
      email: _stringOrFallback(json['email']),
      bio: _nullableString(json['bio']),
      iconColorId: _intValue(json['iconColorId']) ?? 0,
      countryId: _intValue(json['countryId']),
      languageId: _intValue(json['languageId']),
      completedSetup: _boolValue(json['completedSetup']) ?? false,
      darkMode: _boolValue(json['darkMode']) ?? false,
      createdAt: _nullableString(json['createdAt']),
      updatedAt: _nullableString(json['updatedAt']),
      initials: _nullableString(json['initials']),
      country: _asStringMapOrNull(json['country']),
      language: _asStringMapOrNull(json['language']),
      iconColor: _asStringMapOrNull(json['iconColor']),
      avatar: json['avatar'] == null
          ? null
          : ProfileAvatar.fromJson(json['avatar'] as Map<String, dynamic>),
      profileBadges: (json['profileBadges'] as List<dynamic>? ?? const [])
          .map((badge) => badge is Map ? badge['badge'] : badge)
          .whereType<String>()
          .toList(),
      watchedMovies: json['watchedMovies'] != null
          ? (json['watchedMovies'] as List<dynamic>)
              .map((e) => WatchedMovie.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      watchedShows: json['watchedShows'] as List<dynamic>?,
      movieWatchlist: json['movieWatchlist'] != null
          ? (json['movieWatchlist'] as List<dynamic>)
              .map((e) => WatchlistMovie.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      showWatchlist: json['showWatchlist'] as List<dynamic>?,
      favoriteMovies: json['favoriteMovies'] != null
          ? (json['favoriteMovies'] as List<dynamic>)
              .map((e) => FavoriteMovie.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      favoriteShows: json['favoriteShows'] as List<dynamic>?,
      favoritePeople: json['favoritePeople'] as List<dynamic>?,
      favoriteGenres: json['favoriteGenres'] as List<dynamic>?,
    );
  }

  static String? _nullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static String _stringOrFallback(dynamic value, {String fallback = ''}) {
    return _nullableString(value) ?? fallback;
  }

  static int? _intValue(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static bool? _boolValue(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return null;
  }

  static Map<String, dynamic>? _asStringMapOrNull(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  // Helper methods to check movie status
  bool isMovieInWatchlist(int movieId) =>
      movieWatchlist?.any((item) => item.movieId == movieId) ?? false;

  bool isMovieWatched(int movieId) =>
      watchedMovies?.any((item) => item.movieId == movieId) ?? false;

  bool isMovieFavorite(int movieId) =>
      favoriteMovies?.any((item) => item.movieId == movieId) ?? false;

  String? get countryAbbreviation => _countryString('abbreviation');

  String? _countryString(String key) {
    final value = country?[key];
    if (value is String && value.trim().isNotEmpty) return value;
    return null;
  }

  bool isPersonFavorite(int personId) {
    if (favoritePeople == null) return false;
    try {
      return favoritePeople!.any((item) {
        if (item is Map<String, dynamic>) {
          return item['personId'] == personId || item['id'] == personId;
        }
        if (item is int) return item == personId;
        return false;
      });
    } catch (e) {
      logger.w('Error checking person favorite: $e');
      return false;
    }
  }

  // Create a copy of User with updated fields
  User copyWith({
    String? id,
    String? externalId,
    String? firstName,
    String? lastName,
    String? username,
    String? email,
    String? bio,
    int? iconColorId,
    int? countryId,
    int? languageId,
    bool? completedSetup,
    bool? darkMode,
    String? createdAt,
    String? updatedAt,
    String? initials,
    Map<String, dynamic>? country,
    Map<String, dynamic>? language,
    Map<String, dynamic>? iconColor,
    ProfileAvatar? avatar,
    List<String>? profileBadges,
    bool clearAvatar = false,
    List<WatchedMovie>? watchedMovies,
    List<dynamic>? watchedShows,
    List<WatchlistMovie>? movieWatchlist,
    List<dynamic>? showWatchlist,
    List<FavoriteMovie>? favoriteMovies,
    List<dynamic>? favoriteShows,
    List<dynamic>? favoritePeople,
    List<dynamic>? favoriteGenres,
  }) {
    return User(
      id: id ?? this.id,
      externalId: externalId ?? this.externalId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      username: username ?? this.username,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      iconColorId: iconColorId ?? this.iconColorId,
      countryId: countryId ?? this.countryId,
      languageId: languageId ?? this.languageId,
      completedSetup: completedSetup ?? this.completedSetup,
      darkMode: darkMode ?? this.darkMode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      initials: initials ?? this.initials,
      country: country ?? this.country,
      language: language ?? this.language,
      iconColor: iconColor ?? this.iconColor,
      avatar: clearAvatar ? null : avatar ?? this.avatar,
      profileBadges: profileBadges ?? this.profileBadges,
      watchedMovies: watchedMovies ?? this.watchedMovies,
      watchedShows: watchedShows ?? this.watchedShows,
      movieWatchlist: movieWatchlist ?? this.movieWatchlist,
      showWatchlist: showWatchlist ?? this.showWatchlist,
      favoriteMovies: favoriteMovies ?? this.favoriteMovies,
      favoriteShows: favoriteShows ?? this.favoriteShows,
      favoritePeople: favoritePeople ?? this.favoritePeople,
      favoriteGenres: favoriteGenres ?? this.favoriteGenres,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'externalId': externalId,
      'firstName': firstName,
      'lastName': lastName,
      'username': username,
      'email': email,
      'bio': bio,
      'iconColorId': iconColorId,
      'countryId': countryId,
      'languageId': languageId,
      'completedSetup': completedSetup,
      'darkMode': darkMode,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'initials': initials,
      'country': country,
      'language': language,
      'iconColor': iconColor,
      'avatar': avatar?.toJson(),
      'profileBadges': profileBadges,
      'watchedMovies': watchedMovies?.map((e) => e.toJson()).toList(),
      'watchedShows': watchedShows,
      'movieWatchlist': movieWatchlist?.map((e) => e.toJson()).toList(),
      'showWatchlist': showWatchlist,
      'favoriteMovies': favoriteMovies?.map((e) => e.toJson()).toList(),
      'favoriteShows': favoriteShows,
      'favoritePeople': favoritePeople,
      'favoriteGenres': favoriteGenres,
    };
  }
}
