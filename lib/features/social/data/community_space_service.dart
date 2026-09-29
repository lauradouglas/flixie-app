import 'package:flixie_app/core/api/api_client.dart';

/// Additive community APIs; existing review and membership endpoints stay intact.
class CommunitySpaceService {
  const CommunitySpaceService();
  String _base(int id) => '/community/spaces/$id';
  Future<Map<String, dynamic>> get(int id, String path,
          [Map<String, String> query = const {}]) async =>
      Map<String, dynamic>.from(
          await ApiClient.get('${_base(id)}$path', queryParams: query));
  Future<Map<String, dynamic>> post(
          int id, String path, Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(
          await ApiClient.post('${_base(id)}$path', body: body));
  Future<void> mute(String userId) async {
    await ApiClient.put('/community/feed-preferences',
        body: {'ownerId': userId, 'action': 'mute'});
  }

  Future<void> delete(int id, String path) async =>
      ApiClient.delete('${_base(id)}$path');
}
