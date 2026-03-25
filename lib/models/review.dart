import 'user.dart';

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
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as String,
      userId: json['userId'] as String,
      movieId: json['movieId'] as int?,
      showId: json['showId'] as int?,
      rating: json['rating'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
      upvotes: json['upvotes'] as int? ?? 0,
      downvotes: json['downvotes'] as int? ?? 0,
      containsSpoilers: json['containsSpoilers'] as bool? ?? false,
      language: json['language'] as String? ?? 'en',
      recommended: json['recommended'] as bool? ?? true,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
      user: json['user'] != null 
          ? User.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
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
      if (user != null) 'user': {
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

