class MovieCredits {
  final List<MovieCastMember> castMembers;
  final List<CrewMember> crewMembers;

  const MovieCredits({
    required this.castMembers,
    required this.crewMembers,
  });

  factory MovieCredits.fromJson(Map<String, dynamic> json) {
    return MovieCredits(
      castMembers: (json['castMembers'] as List<dynamic>?)
              ?.map((e) => MovieCastMember.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      crewMembers: (json['crewMembers'] as List<dynamic>?)
              ?.map((e) => CrewMember.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'castMembers': castMembers.map((e) => e.toJson()).toList(),
      'crewMembers': crewMembers.map((e) => e.toJson()).toList(),
    };
  }
}

class MovieCastMember {
  final int id;
  final String name;
  final String character;
  final String? profileImage;
  final String knownForDepartment;
  final int gender;
  final int order;

  const MovieCastMember({
    required this.id,
    required this.name,
    required this.character,
    this.profileImage,
    required this.knownForDepartment,
    required this.gender,
    required this.order,
  });

  factory MovieCastMember.fromJson(Map<String, dynamic> json) {
    return MovieCastMember(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] as String,
      character: json['character'] as String,
      profileImage: json['profileImage'] as String?,
      knownForDepartment: json['knownForDepartment'] as String,
      gender: json['gender'] is int
          ? json['gender']
          : int.parse(json['gender'].toString()),
      order: json['order'] is int
          ? json['order']
          : int.parse(json['order'].toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'character': character,
      'profileImage': profileImage,
      'knownForDepartment': knownForDepartment,
      'gender': gender,
      'order': order,
    };
  }
}

class CrewMember {
  final int id;
  final String name;
  final String? profileImage;
  final String knownForDepartment;
  final int gender;
  final String department;
  final String job;

  const CrewMember({
    required this.id,
    required this.name,
    this.profileImage,
    required this.knownForDepartment,
    required this.gender,
    required this.department,
    required this.job,
  });

  factory CrewMember.fromJson(Map<String, dynamic> json) {
    return CrewMember(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] as String,
      profileImage: json['profileImage'] as String?,
      knownForDepartment: json['knownForDepartment'] as String,
      gender: json['gender'] is int
          ? json['gender']
          : int.parse(json['gender'].toString()),
      department: json['department'] as String,
      job: json['job'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'profileImage': profileImage,
      'knownForDepartment': knownForDepartment,
      'gender': gender,
      'department': department,
      'job': job,
    };
  }
}
