class ProfileAvatar {
  const ProfileAvatar({
    required this.id,
    required this.key,
    required this.displayName,
    required this.storagePath,
    this.imageUrl,
  });

  final int id;
  final String key;
  final String displayName;
  final String storagePath;
  final String? imageUrl;

  factory ProfileAvatar.fromJson(Map<String, dynamic> json) => ProfileAvatar(
        id: (json['id'] as num).toInt(),
        key: json['key'] as String,
        displayName: json['displayName'] as String,
        storagePath: json['storagePath'] as String,
        imageUrl: json['imageUrl'] as String?,
      );

  ProfileAvatar copyWith({String? imageUrl}) => ProfileAvatar(
        id: id,
        key: key,
        displayName: displayName,
        storagePath: storagePath,
        imageUrl: imageUrl ?? this.imageUrl,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'key': key,
        'displayName': displayName,
        'storagePath': storagePath,
        if (imageUrl != null) 'imageUrl': imageUrl,
      };
}
