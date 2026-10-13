import 'package:flixie_app/core/api/api_client.dart';

class PrivateCommunityService {
  const PrivateCommunityService();
  Future<Map<String, dynamic>> get(String path,
          [Map<String, String> query = const {}]) async =>
      Map<String, dynamic>.from(
          await ApiClient.get('/community$path', queryParams: query));
  Future<Map<String, dynamic>> post(
          String path, Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(
          await ApiClient.post('/community$path', body: body));
  Future<void> revoke(int id, String invitation) async =>
      ApiClient.delete('/community/private/$id/invitations/$invitation');
  Future<void> changeRole(int id, String user, String role) async =>
      ApiClient.patch('/community/private/$id/members/$user',
          body: {'role': role});
}

String? privateInviteKey(String input) {
  final value = input.trim();
  final uri = Uri.tryParse(value);
  if (uri != null && uri.hasScheme) {
    if (uri.scheme != 'https' ||
        uri.host != 'www.flixie.co.uk' ||
        uri.pathSegments.length != 2 ||
        uri.pathSegments.first != 'community-invites') {
      return null;
    }
    return RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(uri.pathSegments.last)
        ? uri.pathSegments.last
        : null;
  }
  return RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(value) ? value : null;
}
