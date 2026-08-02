class MovieCredits {
  final List<MovieCastMember> castMembers;
  final List<CrewMember> crewMembers;

  const MovieCredits({
    required this.castMembers,
    required this.crewMembers,
  });

  factory MovieCredits.fromJson(Map<String, dynamic> json) {
    return MovieCredits(
      castMembers: _listFrom(json['castMembers'] ?? json['cast'])
          .map(MovieCastMember.fromJson)
          .toList(),
      crewMembers: _listFrom(json['crewMembers'] ?? json['crew'])
          .map(CrewMember.fromJson)
          .toList(),
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

  String? get profileImageUrl => resolveCreditProfileImage(profileImage);

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
      id: _intValue(json['id']) ?? 0,
      name: _stringOrFallback(json['name'], fallback: 'Unknown'),
      character:
          _stringOrFallback(json['character'], fallback: 'Unknown Character'),
      profileImage:
          _nullableString(json['profileImage'] ?? json['profile_path']),
      knownForDepartment: _stringOrFallback(
        json['knownForDepartment'] ?? json['known_for_department'],
        fallback: 'Unknown',
      ),
      gender: _intValue(json['gender']) ?? 0,
      order: _intValue(json['order']) ?? 0,
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

  String? get profileImageUrl => resolveCreditProfileImage(profileImage);

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
      id: _intValue(json['id']) ?? 0,
      name: _stringOrFallback(json['name'], fallback: 'Unknown'),
      profileImage:
          _nullableString(json['profileImage'] ?? json['profile_path']),
      knownForDepartment: _stringOrFallback(
        json['knownForDepartment'] ?? json['known_for_department'],
        fallback: 'Unknown',
      ),
      gender: _intValue(json['gender']) ?? 0,
      department: _stringOrFallback(json['department'], fallback: 'Unknown'),
      job: _stringOrFallback(json['job'], fallback: 'Unknown'),
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

List<Map<String, dynamic>> _listFrom(dynamic value) {
  if (value is! List) return const [];
  return value.whereType<Map>().map((item) {
    if (item is Map<String, dynamic>) return item;
    return item.map((key, val) => MapEntry(key.toString(), val));
  }).toList(growable: false);
}

String? _nullableString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

String _stringOrFallback(dynamic value, {required String fallback}) {
  return _nullableString(value) ?? fallback;
}

int? _intValue(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String? resolveCreditProfileImage(String? value) {
  final image = value?.trim();
  if (image == null || image.isEmpty) return null;
  if (image.startsWith('http://') || image.startsWith('https://')) return image;
  final path = image.startsWith('/') ? image : '/$image';
  return 'https://image.tmdb.org/t/p/w185$path';
}
