class IconColor {
  final int id;
  final String name;
  final String hexCode;

  const IconColor({
    required this.id,
    required this.name,
    required this.hexCode,
  });

  factory IconColor.fromJson(Map<String, dynamic> json) {
    return IconColor(
      id: json['id'] as int,
      name: json['name'] as String,
      hexCode: json['hexCode'] as String,
    );
  }
}
