import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flixie_app/models/conversation.dart';
import 'chat_service.dart';

/// One unread-only query per account; legacy listeners handle staged rule rollout.
class ChatUnreadController extends ChangeNotifier {
  ChatUnreadController({
    Stream<Map<String, int>> Function(String)? unreadCounts,
    Stream<List<Conversation>> Function(String)? conversations,
    Stream<int> Function(String, String)? counts,
    Future<void> Function(String, String)? markRead,
  })  : _unreadCounts = unreadCounts ??
            (conversations != null || counts != null
                ? null
                : ChatService.unreadConversationsStream),
        _conversations = conversations ?? ChatService.conversationsStream,
        _counts = counts ?? ChatService.unreadCountStream,
        _markRead = markRead ?? ChatService.markRead;

  final Future<void> Function(String, String) _markRead;
  bool markingAllRead = false;
  int _generation = 0;
  final Stream<Map<String, int>> Function(String)? _unreadCounts;
  bool _usingLegacy = false;
  final Stream<List<Conversation>> Function(String) _conversations;
  final Stream<int> Function(String, String) _counts;
  StreamSubscription<dynamic>? _subscription;
  final _members = <String, StreamSubscription<int>>{};
  final _unread = <String, int>{};
  String? _userId;
  bool _disposed = false;
  int get total => _unread.values.fold(0, (sum, count) => sum + count);
  int countFor(String id) => _unread[id] ?? 0;

  /// Snapshot all unread chats, independently of the UI search filter.
  /// Live server counts remain authoritative, including messages arriving later.
  Future<int> markAllRead() async {
    final userId = _userId;
    if (userId == null || markingAllRead) return 0;
    final generation = _generation;
    final ids =
        _unread.entries.where((e) => e.value > 0).map((e) => e.key).toList();
    if (ids.isEmpty) return 0;
    markingAllRead = true;
    notifyListeners();
    var failures = 0;
    try {
      for (final id in ids) {
        if (_disposed || generation != _generation) break;
        try {
          await _markRead(id, userId);
        } catch (_) {
          failures++;
        }
      }
    } finally {
      if (!_disposed && generation == _generation) {
        markingAllRead = false;
        notifyListeners();
      }
    }
    return failures;
  }

  void syncUser(String? userId) {
    if (_userId == userId) return;
    _generation++;
    markingAllRead = false;
    _userId = userId;
    _subscription?.cancel();
    for (final sub in _members.values) {
      sub.cancel();
    }
    _members.clear();
    _unread.clear();
    scheduleMicrotask(() {
      if (!_disposed) notifyListeners();
    });
    if (userId == null) return;
    _usingLegacy = false;
    final source = _unreadCounts;
    if (source == null) {
      _startLegacy(userId, _generation);
      return;
    }
    final generation = _generation;
    _subscription = source(userId).listen((counts) {
      if (_disposed || _usingLegacy || generation != _generation) return;
      _unread
        ..clear()
        ..addEntries(counts.entries.where((e) => e.value > 0));
      notifyListeners();
    }, onError: (Object error) {
      if (_disposed || _usingLegacy || generation != _generation) return;
      if (error is FirebaseException &&
          const ['permission-denied', 'failed-precondition']
              .contains(error.code)) {
        // A new app can precede rules/index rollout. Reuse the established path,
        // which checks identity again; never treat a denied query as a zero badge.
        logger
            .w('Unread-only query unavailable; using legacy unread listeners.');
        _subscription?.cancel();
        _unread.clear();
        notifyListeners();
        _startLegacy(userId, generation);
      }
      // Transient failures retain the last server count; Firestore reconnects.
    });
  }

  void _startLegacy(String userId, int generation) {
    _usingLegacy = true;
    _subscription = _conversations(userId).listen((conversations) {
      if (_disposed || generation != _generation) return;
      final ids = conversations.map((c) => c.id).toSet();
      for (final id in _members.keys.toList()) {
        if (!ids.contains(id)) {
          _members.remove(id)?.cancel();
          _unread.remove(id);
        }
      }
      for (final id in ids) {
        _members.putIfAbsent(
            id,
            () => _counts(id, userId).listen((count) {
                  if (_disposed ||
                      generation != _generation ||
                      !_members.containsKey(id)) {
                    return;
                  }
                  _unread[id] = count < 0 ? 0 : count;
                  notifyListeners();
                }, onError: (Object error) {
                  /* Retain last known count offline. */
                }));
      }
      notifyListeners();
    }, onError: (Object error) {/* Firestore reconnects automatically. */});
  }

  @override
  void dispose() {
    _disposed = true;
    _userId = null;
    _subscription?.cancel();
    for (final sub in _members.values) {
      sub.cancel();
    }
    super.dispose();
  }
}
