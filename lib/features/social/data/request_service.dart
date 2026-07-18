import 'package:flixie_app/models/watch_request.dart';
import 'package:flixie_app/core/api/api_client.dart';

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

  static Future<WatchRequestState> getWatchRequestState({
    required String watchRequestId,
    required String userId,
  }) async {
    final data = await ApiClient.get(
      '/watch-requests/$watchRequestId/state',
      queryParams: {'userId': userId},
    );
    return WatchRequestState.fromJson(data as Map<String, dynamic>);
  }

  static Future<WatchRequestState> proposeWatchSchedule({
    required String watchRequestId,
    required String userId,
    required DateTime proposedFor,
    String? message,
    String? location,
  }) async {
    await ApiClient.post(
      '/watch-requests/$watchRequestId/schedule-proposals',
      body: {
        'userId': userId,
        'proposedFor': proposedFor.toUtc().toIso8601String(),
        if (message != null && message.trim().isNotEmpty)
          'message': message.trim(),
        if (location != null && location.trim().isNotEmpty)
          'location': location.trim(),
      },
    );
    return getWatchRequestState(watchRequestId: watchRequestId, userId: userId);
  }

  static Future<WatchRequestState> respondToWatchScheduleProposal({
    required String watchRequestId,
    required String proposalId,
    required String userId,
    required String decision,
  }) async {
    await ApiClient.patch(
      '/watch-requests/$watchRequestId/schedule-proposals/$proposalId/respond',
      body: {
        'userId': userId,
        'decision': decision,
      },
    );
    return getWatchRequestState(watchRequestId: watchRequestId, userId: userId);
  }

  static Future<WatchRequestState> confirmWatchRequest({
    required String watchRequestId,
    required String userId,
    required bool watched,
    int? rating,
    String? reviewText,
  }) async {
    await ApiClient.post(
      '/watch-requests/$watchRequestId/watch-confirmations',
      body: {
        'userId': userId,
        'watched': watched,
        if (watched && rating != null) 'rating': rating,
        if (watched && reviewText != null && reviewText.trim().isNotEmpty)
          'reviewText': reviewText.trim(),
      },
    );
    return getWatchRequestState(watchRequestId: watchRequestId, userId: userId);
  }

  static Future<WatchRequest> scheduleWatchRequest({
    required String watchRequestId,
    required String userId,
    required DateTime? scheduledFor,
    String? location,
  }) async {
    final data = await ApiClient.patch(
      '/watch-requests/$watchRequestId/schedule',
      body: {
        'userId': userId,
        'scheduledFor': scheduledFor?.toUtc().toIso8601String(),
        if (location != null && location.trim().isNotEmpty)
          'location': location.trim(),
      },
    );
    return WatchRequest.fromJson(data as Map<String, dynamic>);
  }

  static Future<WatchRequest> completeWatchRequest({
    required String watchRequestId,
    required String userId,
    int? rating,
    String? reviewText,
  }) async {
    final data = await ApiClient.patch(
      '/watch-requests/$watchRequestId/complete',
      body: {
        'userId': userId,
        if (rating != null) 'rating': rating,
        if (reviewText != null && reviewText.trim().isNotEmpty)
          'reviewText': reviewText.trim(),
      },
    );
    return WatchRequest.fromJson(data as Map<String, dynamic>);
  }

  static Future<WatchRequest> cancelWatchRequest({
    required String watchRequestId,
    required String userId,
  }) async {
    final data = await ApiClient.patch(
      '/watch-requests/$watchRequestId/cancel',
      body: {'userId': userId},
    );
    return WatchRequest.fromJson(data as Map<String, dynamic>);
  }

  static Future<List<WatchRequest>> getWatchRequests(String userId) async {
    final results = await Future.wait([
      _getWatchRequestsOfType(userId, 'MOVIE_WATCH_REQUEST'),
      _getWatchRequestsOfType(userId, 'SHOW_WATCH_REQUEST'),
    ]);
    return [...results[0], ...results[1]];
  }

  static Future<List<WatchRequest>> _getWatchRequestsOfType(
    String userId,
    String type,
  ) async {
    dynamic data;
    try {
      data = await ApiClient.get('/requests/$userId/type/$type');
    } on ApiException catch (e) {
      if (e.statusCode == 404) return [];
      rethrow;
    }
    return (data as List<dynamic>)
        .map((e) => WatchRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
