import 'package:flixie_app/core/api/api_client.dart';

class BlockedUser {
  const BlockedUser({
    required this.id,
    required this.username,
    this.firstName,
  });

  final String id;
  final String username;
  final String? firstName;

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    final user = json['blocked'] as Map<String, dynamic>? ?? json;
    return BlockedUser(
      id: user['id'] as String,
      username: user['username'] as String? ?? 'User',
      firstName: user['firstName'] as String?,
    );
  }
}

class SafetyService {
  const SafetyService._();

  static final Set<String> _blockedIds = {};
  static Future<List<BlockedUser>>? _load;

  static bool isBlocked(String userId) => _blockedIds.contains(userId);

  static Future<void> report({
    required String targetType,
    required String reason,
    String? targetId,
    String? reportedUserId,
    String? details,
    String? contentPreview,
  }) async {
    await ApiClient.post('/safety/reports', body: {
      'targetType': targetType,
      'reason': reason,
      if (targetId != null) 'targetId': targetId,
      if (reportedUserId != null) 'reportedUserId': reportedUserId,
      if (details?.trim().isNotEmpty == true) 'details': details!.trim(),
      if (contentPreview?.trim().isNotEmpty == true)
        'contentPreview': contentPreview!.trim(),
    });
  }

  static Future<void> block(String userId) async {
    await ApiClient.post('/safety/blocks', body: {'blockedUserId': userId});
    _blockedIds.add(userId);
  }

  static Future<void> unblock(String userId) async {
    await ApiClient.delete('/safety/blocks/$userId');
    _blockedIds.remove(userId);
  }

  static Future<List<BlockedUser>> blockedUsers({bool refresh = false}) {
    if (refresh) _load = null;
    return _load ??= _fetchBlockedUsers();
  }

  static Future<List<BlockedUser>> _fetchBlockedUsers() async {
    try {
      final response = await ApiClient.get('/safety/blocks') as List<dynamic>;
      final users = response
          .map((item) => BlockedUser.fromJson(item as Map<String, dynamic>))
          .toList();
      _blockedIds
        ..clear()
        ..addAll(users.map((user) => user.id));
      return users;
    } catch (_) {
      _load = null;
      rethrow;
    }
  }
}
