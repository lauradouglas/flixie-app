import 'package:flixie_app/models/friendship.dart';

/// Filter without losing selection; stable partition keeps the existing order
/// within starred and ordinary friends, and never mutates the source snapshot.
List<T> selectFriends<T>(
  Iterable<T> source, {
  required FriendshipUser? Function(T) userOf,
  required Set<String> starred,
  String query = '',
}) {
  final q = query.trim().toLowerCase();
  final favourites = <T>[], others = <T>[];
  for (final item in source) {
    final user = userOf(item);
    if (user == null) continue;
    final name =
        '${user.displayName} ${user.username} ${user.firstName ?? ''} ${user.lastName ?? ''}'
            .toLowerCase();
    if (q.isNotEmpty && !name.contains(q)) continue;
    (starred.contains(user.id) ? favourites : others).add(item);
  }
  return [...favourites, ...others];
}
