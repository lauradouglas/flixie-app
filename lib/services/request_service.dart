import '../models/watch_request.dart';
import 'api_client.dart';

class RequestService {
  static Future<Map<String, dynamic>?> sendRequest(
      Map<String, dynamic> body) async {
    final data = await ApiClient.post('/requests', body: body);
    if (data is Map<String, dynamic>) {
      return data;
    }
    return null;
  }

  static Future<void> updateRequest(String requestId, String status,
      {String? message}) async {
    await ApiClient.post('/requests/update', body: {
      'id': requestId,
      'status': status,
      if (message != null && message.isNotEmpty) 'message': message,
    });
  }

  static Future<List<WatchRequest>> getWatchRequests(String userId) async {
    final data =
        await ApiClient.get('/requests/$userId/type/MOVIE_WATCH_REQUEST');
    return (data as List<dynamic>)
        .map((e) => WatchRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
