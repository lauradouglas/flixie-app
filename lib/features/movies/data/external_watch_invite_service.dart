import 'package:flixie_app/core/api/api_client.dart';

class ExternalWatchInviteService {
  static Future<Map<String, dynamic>> publicPreview(String token) async =>
      Map<String, dynamic>.from(
          await ApiClient.get('/guest/watch-invites/$token') as Map);
  static Future<Map<String, dynamic>> preview(String token) async =>
      Map<String, dynamic>.from(
          await ApiClient.get('/watch-requests/external-invites/$token')
              as Map);
  static Future<String> claim(String token) async {
    final response = await ApiClient.post(
        '/watch-requests/external-invites/$token/claim',
        body: {});
    return (response as Map)['requestId'] as String;
  }

  static Future<String> shareUrl(String id) async {
    final response =
        await ApiClient.get('/watch-requests/external-invites/$id/share');
    return (response as Map)['url'] as String;
  }
}
