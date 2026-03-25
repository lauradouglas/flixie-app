class User {
  final String id;
  final String externalId;
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
  
  // Lists
  final List<dynamic>? watchedMovies;
  final List<dynamic>? watchedShows;
  final List<dynamic>? movieWatchlist;
  final List<dynamic>? showWatchlist;
  final List<dynamic>? favoriteMovies;
  final List<dynamic>? favoriteShows;
  final List<dynamic>? favoritePeople;
  final List<dynamic>? favoriteGenres;

  const User({
    required this.id,
    required this.externalId,
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
      id: json['id'] as String,
      externalId: json['externalId'] as String,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      username: json['username'] as String,
      email: json['email'] as String,
      bio: json['bio'] as String?,
      iconColorId: json['iconColorId'] as int,
      countryId: json['countryId'] as int?,
      languageId: json['languageId'] as int?,
      completedSetup: json['completedSetup'] as bool,
      darkMode: json['darkMode'] as bool,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      initials: json['initials'] as String?,
      country: json['country'] as Map<String, dynamic>?,
      language: json['language'] as Map<String, dynamic>?,
      iconColor: json['iconColor'] as Map<String, dynamic>?,
      watchedMovies: json['watchedMovies'] as List<dynamic>?,
      watchedShows: json['watchedShows'] as List<dynamic>?,
      movieWatchlist: json['movieWatchlist'] as List<dynamic>?,
      showWatchlist: json['showWatchlist'] as List<dynamic>?,
      favoriteMovies: json['favoriteMovies'] as List<dynamic>?,
      favoriteShows: json['favoriteShows'] as List<dynamic>?,
      favoritePeople: json['favoritePeople'] as List<dynamic>?,
      favoriteGenres: json['favoriteGenres'] as List<dynamic>?,
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
      'watchedMovies': watchedMovies,
      'watchedShows': watchedShows,
      'movieWatchlist': movieWatchlist,
      'showWatchlist': showWatchlist,
      'favoriteMovies': favoriteMovies,
      'favoriteShows': favoriteShows,
      'favoritePeople': favoritePeople,
      'favoriteGenres': favoriteGenres,
    };
  }
}
