import 'package:flixie_app/models/user.dart';

class Review {
  final String id;
  final String userId;
  final int? movieId;
  final int? showId;
  final int rating;
  final String title;
  final String body;
  final int upvotes;
  final int downvotes;
  final bool containsSpoilers;
  final String language;
  final bool recommended;
  final String createdAt;
  final String updatedAt;
  final User? user;
  final String? movieTitle;
  final String? moviePosterPath;
  final Map<String, int> reactions;
  final String? myReaction;

  const Review({
    required this.id,
    required this.userId,
    this.movieId,
    this.showId,
    required this.rating,
    required this.title,
    required this.body,
    required this.upvotes,
    required this.downvotes,
    required this.containsSpoilers,
    required this.language,
    required this.recommended,
    required this.createdAt,
    required this.updatedAt,
    this.user,
    this.movieTitle,
    this.moviePosterPath,
    this.reactions = const {},
    this.myReaction,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: _stringOrFallback(json['id']),
      userId: _stringOrFallback(json['userId']),
      movieId: _intValue(json['movieId']),
      showId: _intValue(json['showId']),
      rating: _intValue(json['rating']) ?? 0,
      title: _stringOrFallback(json['title'], fallback: 'Untitled review'),
      body: _stringOrFallback(json['body']),
      upvotes: _intValue(json['upvotes']) ?? 0,
      downvotes: _intValue(json['downvotes']) ?? 0,
      containsSpoilers: json['containsSpoilers'] as bool? ?? false,
      language: _stringOrFallback(json['language'], fallback: 'en'),
      recommended: json['recommended'] as bool? ?? true,
      createdAt: _stringOrFallback(json['createdAt']),
      updatedAt: _stringOrFallback(json['updatedAt']),
      user: json['user'] != null
          ? User.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      movieTitle: json['movie'] != null
          ? _nullableString((json['movie'] as Map<String, dynamic>)['title'])
          : _nullableString(json['movieTitle']),
      moviePosterPath: json['movie'] is Map<String, dynamic>
          ? _nullableString((json['movie'] as Map<String, dynamic>)['posterPath'])
          : _nullableString(json['moviePosterPath']),
      reactions: (json['reactions'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toInt())) ??
          {},
      myReaction: _nullableString(json['myReaction']),
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'movieId': movieId,
      'showId': showId,
      'rating': rating,
      'title': title,
      'body': body,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'containsSpoilers': containsSpoilers,
      'language': language,
      'recommended': recommended,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      if (user != null)
        'user': {
          'id': user!.id,
          'externalId': user!.externalId,
          'firstName': user!.firstName,
          'lastName': user!.lastName,
          'username': user!.username,
          'email': user!.email,
          'bio': user!.bio,
          'iconColorId': user!.iconColorId,
          'countryId': user!.countryId,
          'languageId': user!.languageId,
          'completedSetup': user!.completedSetup,
          'darkMode': user!.darkMode,
          'createdAt': user!.createdAt,
          'updatedAt': user!.updatedAt,
        },
    };
  }
}
