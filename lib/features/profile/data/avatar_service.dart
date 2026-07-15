import 'package:firebase_storage/firebase_storage.dart';

import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/models/profile_avatar.dart';

class AvatarUrlResolver {
  AvatarUrlResolver(
      {FirebaseStorage? storage, Future<String> Function(String)? loader})
      : _storage = storage,
        _loader = loader;

  final FirebaseStorage? _storage;
  final Future<String> Function(String)? _loader;
  final Map<String, Future<String>> _cache = {};

  Future<String> resolve(String storagePath, {bool retry = false}) {
    if (retry) _cache.remove(storagePath);
    return _cache.putIfAbsent(
      storagePath,
      () =>
          _loader?.call(storagePath) ??
          (_storage ?? FirebaseStorage.instance)
              .ref(storagePath)
              .getDownloadURL(),
    );
  }

  void clear([String? storagePath]) {
    storagePath == null ? _cache.clear() : _cache.remove(storagePath);
  }
}

class AvatarService {
  static Future<List<ProfileAvatar>> getAvatars() async {
    final data = await ApiClient.get('/avatars');
    final avatars = (data as Map<String, dynamic>)['avatars'] as List? ?? [];
    return avatars
        .map((item) => ProfileAvatar.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  static Future<ProfileAvatar> selectAvatar(int avatarId) async {
    final data = await ApiClient.patch(
      '/users/me/avatar',
      body: {'avatarId': avatarId},
    );
    return ProfileAvatar.fromJson(
      (data as Map<String, dynamic>)['avatar'] as Map<String, dynamic>,
    );
  }

  static Future<void> removeAvatar() => ApiClient.delete('/users/me/avatar');
}
