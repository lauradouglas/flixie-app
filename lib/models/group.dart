class Group {
  final String? id;
  final String name;
  final String? abbreviation;
  final String? description;
  final String ownerId;
  final String? visibility;
  final String? status;
  final int? memberCount;
  final int? maxMembers;
  final String? password;
  final int? movieId;
  final int? showId;
  final String? createdAt;
  final String? updatedAt;

  const Group({
    this.id,
    required this.name,
    this.abbreviation,
    this.description,
    required this.ownerId,
    this.visibility,
    this.status,
    this.memberCount,
    this.maxMembers,
    this.password,
    this.movieId,
    this.showId,
    this.createdAt,
    this.updatedAt,
  });

  bool get isPublic => visibility == 'PUBLIC';

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as String?,
      name: json['name'] as String,
      abbreviation: json['abbreviation'] as String?,
      description: json['description'] as String?,
      ownerId: json['ownerId'] as String,
      visibility: json['visibility'] as String?,
      status: json['status'] as String?,
      memberCount: json['memberCount'] as int?,
      maxMembers: json['maxMembers'] as int?,
      password: json['password'] as String?,
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
      'abbreviation': abbreviation,
      'description': description,
      'ownerId': ownerId,
      'visibility': visibility,
      'status': status,
      'memberCount': memberCount,
      'maxMembers': maxMembers,
      'password': password,
      'movieId': movieId,
      'showId': showId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
