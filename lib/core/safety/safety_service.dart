import 'package:flixie_app/core/api/api_client.dart';
import 'package:flutter/foundation.dart';

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

  static final ValueNotifier<int> changes = ValueNotifier(0);
  static final Set<String> _blockedIds = {};
  static Future<List<BlockedUser>>? _load;
  static int _generation = 0;
  static int _loadRevision = 0;

  static void reset() {
    _generation++;
    _loadRevision++;
    _blockedIds.clear();
    _load = null;
    changes.value++;
  }

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
        'contentPreview': contentPreview!
            .trim()
            .substring(0, contentPreview.trim().length.clamp(0, 500)),
    });
  }

  static Future<void> block(String userId) async {
    final generation = _generation;
    await ApiClient.post('/safety/blocks', body: {'blockedUserId': userId});
    if (generation != _generation) return;
    _loadRevision++;
    _blockedIds.add(userId);
    _load = null;
    changes.value++;
  }

  static Future<void> unblock(String userId) async {
    final generation = _generation;
    await ApiClient.delete('/safety/blocks/$userId');
    if (generation != _generation) return;
    _loadRevision++;
    _blockedIds.remove(userId);
    _load = null;
    changes.value++;
  }

  static Future<List<BlockedUser>> blockedUsers({bool refresh = false}) {
    if (refresh) {
      _loadRevision++;
      _load = null;
    }
    return _load ??= _fetchBlockedUsers();
  }

  static Future<List<BlockedUser>> _fetchBlockedUsers() async {
    final generation = _generation;
    final revision = _loadRevision;
    try {
      final response = await ApiClient.get('/safety/blocks') as List<dynamic>;
      final users = response
          .map((item) => BlockedUser.fromJson(item as Map<String, dynamic>))
          .toList();
      if (generation != _generation || revision != _loadRevision) {
        return const [];
      }
      _blockedIds
        ..clear()
        ..addAll(users.map((user) => user.id));
      return users;
    } catch (_) {
      if (generation == _generation && revision == _loadRevision) _load = null;
      rethrow;
    }
  }
}
