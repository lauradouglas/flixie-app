class ProfileAvatar {
  const ProfileAvatar({
    required this.id,
    required this.key,
    required this.displayName,
    required this.storagePath,
    this.imageUrl,
    this.iconStoragePath,
    this.iconImageUrl,
  });

  final int id;
  final String key;
  final String displayName;
  final String storagePath;
  final String? imageUrl;
  final String? iconStoragePath;
  final String? iconImageUrl;

  factory ProfileAvatar.fromJson(Map<String, dynamic> json) => ProfileAvatar(
        id: (json['id'] as num).toInt(),
        key: json['key'] as String,
        displayName: json['displayName'] as String,
        storagePath: json['storagePath'] as String,
        imageUrl: json['imageUrl'] as String?,
        iconStoragePath: json['iconStoragePath'] as String?,
        iconImageUrl: json['iconImageUrl'] as String?,
      );

  ProfileAvatar copyWith({String? imageUrl, String? iconImageUrl}) =>
      ProfileAvatar(
        id: id,
        key: key,
        displayName: displayName,
        storagePath: storagePath,
        imageUrl: imageUrl ?? this.imageUrl,
        iconStoragePath: iconStoragePath,
        iconImageUrl: iconImageUrl ?? this.iconImageUrl,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'key': key,
        'displayName': displayName,
        'storagePath': storagePath,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (iconStoragePath != null) 'iconStoragePath': iconStoragePath,
        if (iconImageUrl != null) 'iconImageUrl': iconImageUrl,
      };
}
