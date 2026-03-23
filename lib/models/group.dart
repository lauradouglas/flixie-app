class Group {
  final String? id;
  final String name;
  final String? description;
  final String ownerId;
  final String? visibility;
  final int? movieId;
  final int? showId;
  final String? createdAt;
  final String? updatedAt;

  const Group({
    this.id,
    required this.name,
    this.description,
    required this.ownerId,
    this.visibility,
    this.movieId,
    this.showId,
    this.createdAt,
    this.updatedAt,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      ownerId: json['ownerId'] as String,
      visibility: json['visibility'] as String?,
      movieId: json['movieId'] as int?,
      showId: json['showId'] as int?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'ownerId': ownerId,
      'visibility': visibility,
      'movieId': movieId,
      'showId': showId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
