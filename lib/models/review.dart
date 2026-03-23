class Review {
  final String? id;
  final String userId;
  final int? movieId;
  final int? showId;
  final int rating;
  final String title;
  final String body;
  final bool? containsSpoilers;
  final String? language;
  final bool? recommended;
  final int? upvotes;
  final int? downvotes;
  final String? createdAt;
  final String? updatedAt;

  const Review({
    this.id,
    required this.userId,
    this.movieId,
    this.showId,
    required this.rating,
    required this.title,
    required this.body,
    this.containsSpoilers,
    this.language,
    this.recommended,
    this.upvotes,
    this.downvotes,
    this.createdAt,
    this.updatedAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as String?,
      userId: json['userId'] as String,
      movieId: json['movieId'] as int?,
      showId: json['showId'] as int?,
      rating: json['rating'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
      containsSpoilers: json['containsSpoilers'] as bool?,
      language: json['language'] as String?,
      recommended: json['recommended'] as bool?,
      upvotes: json['upvotes'] as int?,
      downvotes: json['downvotes'] as int?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
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
      'containsSpoilers': containsSpoilers,
      'language': language,
      'recommended': recommended,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
