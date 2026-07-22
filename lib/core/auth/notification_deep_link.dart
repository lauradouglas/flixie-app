String notificationDeepLinkPath(Map<String, dynamic> data) {
  final route = data['route']?.toString();
  final type = (data['type']?.toString() ?? '').toUpperCase();
  final groupId = data['groupId']?.toString();
  final friendId = data['friendId']?.toString();
  final requestId = _watchRequestId(data, route, type);

  // Older lifecycle pushes used an API-style `/conversations/...` route that
  // has never been an app route. Prefer the request's dedicated full-page
  // route whenever the payload identifies a watch request.
  if (requestId != null && requestId.isNotEmpty) {
    if (groupId != null && groupId.isNotEmpty) {
      return '/groups/$groupId?tab=requests&requestId=$requestId';
    }
    return '/watch-requests/$requestId';
  }

  if (route != null && route.startsWith('/')) return route;

  if ((type == 'GROUP_MESSAGE' ||
          type == 'MESSAGE' ||
          type == 'TEXT' ||
          type == 'IMAGE') &&
      groupId != null &&
      groupId.isNotEmpty) {
    return '/groups/$groupId?tab=chat';
  }

  if ((type == 'MOVIE_WATCH_REQUEST' ||
          type == 'SHOW_WATCH_REQUEST' ||
          type == 'GROUP_REQUEST') &&
      groupId != null &&
      groupId.isNotEmpty) {
    return '/groups/$groupId?tab=requests';
  }

  if (type == 'GROUP_INVITE' && groupId != null && groupId.isNotEmpty) {
    return '/groups/$groupId';
  }

  if (type == 'FRIEND_REQUEST' && friendId != null && friendId.isNotEmpty) {
    return '/friends/$friendId';
  }

  return '/notifications';
}

String? _watchRequestId(
  Map<String, dynamic> data,
  String? route,
  String type,
) {
  final explicit = data['watchRequestId']?.toString();
  if (explicit != null && explicit.isNotEmpty) return explicit;

  const watchTypes = {
    'MOVIE_WATCH_REQUEST',
    'SHOW_WATCH_REQUEST',
    'GROUP_REQUEST',
    'WATCH_REQUEST',
    'NEW_WATCH_REQUEST',
    'REQUEST_ACCEPTED',
    'REQUEST_DECLINED',
    'DATETIME_PROPOSED',
    'DATETIME_ACCEPTED',
    'DATETIME_DECLINED',
    'REQUEST_SCHEDULED',
    'REQUEST_RESCHEDULED',
    'LOCATION_CHANGED',
    'REQUEST_CANCELLED',
  };
  final requestId = data['requestId']?.toString();
  if (watchTypes.contains(type) && requestId != null && requestId.isNotEmpty) {
    return requestId;
  }

  if (route == null || !route.startsWith('/conversations/')) return null;
  return Uri.tryParse(route)?.queryParameters['watchRequestId'];
}
