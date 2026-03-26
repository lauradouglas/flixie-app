class PersonCreditItem {
  final int id;
  final String title;
  final String type;
  final List<String> characters;
  final String? releaseDate;
  final String? posterPath;
  final double voteAverage;
  final int voteCount;
  final double popularity;
  final int? episodes;

  const PersonCreditItem({
    required this.id,
    required this.title,
    required this.type,
    required this.characters,
    this.releaseDate,
    this.posterPath,
    required this.voteAverage,
    required this.voteCount,
    required this.popularity,
    this.episodes,
  });

  factory PersonCreditItem.fromJson(Map<String, dynamic> json) {
    return PersonCreditItem(
      id: json['id'] as int,
      title: json['title'] as String,
      type: json['type'] as String,
      characters: (json['characters'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      releaseDate: json['releaseDate'] as String?,
      posterPath: json['posterPath'] as String?,
      voteAverage: (json['voteAverage'] as num).toDouble(),
      voteCount: json['voteCount'] as int,
      popularity: (json['popularity'] as num).toDouble(),
      episodes: json['episodes'] as int?,
    );
  }
}

class PersonCrewCreditItem {
  final int id;
  final String title;
  final String type;
  final String? releaseDate;
  final String? posterPath;
  final double voteAverage;
  final int voteCount;
  final double popularity;
  final String department;
  final String job;

  const PersonCrewCreditItem({
    required this.id,
    required this.title,
    required this.type,
    this.releaseDate,
    this.posterPath,
    required this.voteAverage,
    required this.voteCount,
    required this.popularity,
    required this.department,
    required this.job,
  });

  factory PersonCrewCreditItem.fromJson(Map<String, dynamic> json) {
    return PersonCrewCreditItem(
      id: json['id'] as int,
      title: json['title'] as String,
      type: json['type'] as String,
      releaseDate: json['releaseDate'] as String?,
      posterPath: json['posterPath'] as String?,
      voteAverage: (json['voteAverage'] as num).toDouble(),
      voteCount: json['voteCount'] as int,
      popularity: (json['popularity'] as num).toDouble(),
      department: json['department'] as String,
      job: json['job'] as String,
    );
  }
}

class PersonCredits {
  final List<PersonCreditItem> allCredits;
  final List<PersonCreditItem> knownForCredits;
  final List<PersonCrewCreditItem> crewCredits;

  const PersonCredits({
    required this.allCredits,
    required this.knownForCredits,
    required this.crewCredits,
  });

  factory PersonCredits.fromJson(Map<String, dynamic> json) {
    return PersonCredits(
      allCredits: (json['allCredits'] as List<dynamic>)
          .map((e) => PersonCreditItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      knownForCredits: (json['knownForCredits'] as List<dynamic>)
          .map((e) => PersonCreditItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      crewCredits: (json['crewCredits'] as List<dynamic>)
          .map((e) => PersonCrewCreditItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PersonImage {
  final int personId;
  final double? aspectRatio;
  final String imageUrl;
  final String? imageType;

  const PersonImage({
    required this.personId,
    this.aspectRatio,
    required this.imageUrl,
    this.imageType,
  });

  factory PersonImage.fromJson(Map<String, dynamic> json) {
    return PersonImage(
      personId: json['personId'] as int,
      aspectRatio: (json['aspectRatio'] as num?)?.toDouble(),
      imageUrl: json['imageUrl'] as String,
      imageType: json['imageType'] as String?,
    );
  }
}

class Person {
  final int id;
  final String name;
  final String? biography;
  final String? dateOfBirth;
  final String? dateOfDeath;
  final String? placeOfBirth;
  final String? profileImgUrl;
  final String? department;
  final String? imdbId;
  final String? instagramId;
  final List<PersonImage> images;

  const Person({
    required this.id,
    required this.name,
    this.biography,
    this.dateOfBirth,
    this.dateOfDeath,
    this.placeOfBirth,
    this.profileImgUrl,
    this.department,
    this.imdbId,
    this.instagramId,
    this.images = const [],
  });

  factory Person.fromJson(Map<String, dynamic> json) {
    final dod = json['dateOfDeath'] as String?;
    return Person(
      id: json['id'] as int,
      name: json['name'] as String,
      biography: json['biography'] as String?,
      dateOfBirth: json['dateOfBirth'] as String?,
      dateOfDeath: (dod != null && dod.isNotEmpty) ? dod : null,
      placeOfBirth: json['placeOfBirth'] as String?,
      profileImgUrl: json['profileImgUrl'] as String?,
      department: json['department'] as String?,
      imdbId: json['imdbId'] as String?,
      instagramId: json['instagramId'] as String?,
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => PersonImage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
