class Country {
  final int id;
  final String abbreviation;
  final String name;
  final String nativeName;

  const Country({
    required this.id,
    required this.abbreviation,
    required this.name,
    required this.nativeName,
  });

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      id: json['id'] as int,
      abbreviation: (json['abbreviation'] as String?) ?? '',
      name: json['name'] as String,
      nativeName: (json['nativeName'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'abbreviation': abbreviation,
      'name': name,
      'nativeName': nativeName,
    };
  }
}
