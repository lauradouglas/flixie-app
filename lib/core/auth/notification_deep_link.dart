String notificationDeepLinkPath(Map<String, dynamic> data) {
  final route = data['route']?.toString();
  if (route != null && route.startsWith('/')) return route;

  final type = (data['type']?.toString() ?? '').toUpperCase();
  final groupId = data['groupId']?.toString();
  final friendId = data['friendId']?.toString();

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
