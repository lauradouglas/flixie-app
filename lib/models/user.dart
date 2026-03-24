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
    };
  }
}
