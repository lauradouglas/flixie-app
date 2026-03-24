class Person {
  final int id;
  final String name;
  final String? biography;
  final String? birthday;
  final String? deathday;
  final int? gender;
  final String? knownForDepartment;
  final double? popularity;
  final String? profilePath;

  const Person({
    required this.id,
    required this.name,
    this.biography,
    this.birthday,
    this.deathday,
    this.gender,
    this.knownForDepartment,
    this.popularity,
    this.profilePath,
  });

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id'] as int,
      name: json['name'] as String,
      biography: json['biography'] as String?,
      birthday: json['birthday'] as String?,
      deathday: json['deathday'] as String?,
      gender: json['gender'] as int?,
      knownForDepartment: json['knownForDepartment'] as String?,
      popularity: (json['popularity'] as num?)?.toDouble(),
      profilePath: json['profilePath'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'biography': biography,
      'birthday': birthday,
      'deathday': deathday,
      'gender': gender,
      'knownForDepartment': knownForDepartment,
      'popularity': popularity,
      'profilePath': profilePath,
    };
  }
}
