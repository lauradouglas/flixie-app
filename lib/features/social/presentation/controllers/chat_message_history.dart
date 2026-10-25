import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flixie_app/models/conversation.dart';

/// A small live window plus history fetched only on an explicit scroll/retry.
class ChatMessageHistory extends ChangeNotifier {
  ChatMessageHistory(
      {required Stream<List<ChatMessage>> live,
      required this.loadPage,
      this.pageSize = 20}) {
    _subscription = live.listen(_receive, onError: (Object error) {
      liveError = error;
      loading = false;
      notifyListeners();
    });
  }
  final Future<List<ChatMessage>> Function(ChatMessage before) loadPage;
  final int pageSize;
  StreamSubscription<List<ChatMessage>>? _subscription;
  final _items = <String, ChatMessage>{};
  Set<String> _liveIds = {};
  bool _disposed = false;
  bool _received = false;
  bool loading = true, loadingOlder = false, hasOlder = false;
  Object? liveError, olderError;
  List<ChatMessage> get messages {
    final result = _items.values.toList();
    result.sort(_compare);
    return result;
  }

  static int _compare(ChatMessage a, ChatMessage b) {
    final time = a.firestoreCreatedAt != null && b.firestoreCreatedAt != null
        ? b.firestoreCreatedAt!.compareTo(a.firestoreCreatedAt!)
        : b.createdAt.compareTo(a.createdAt);
    return time != 0 ? time : b.id.compareTo(a.id);
  }

  bool _holdLive = false;
  bool get isAtLatest => !_holdLive;
  List<ChatMessage>? _pending;
  set holdLive(bool value) {
    _holdLive = value;
    if (!value && _pending != null) {
      final pending = _pending!;
      _pending = null;
      // Scroll notifications occur during layout; deliver after this frame.
      scheduleMicrotask(() {
        if (!_disposed) _receive(pending);
      });
    }
  }

  void _receive(List<ChatMessage> window) {
    if (_disposed) return;
    if (_holdLive && !loading) {
      _pending = window;
      return;
    }
    final ids = window.map((m) => m.id).toSet();
    if (!_received) hasOlder = window.length >= pageSize;
    _received = true;
    if (window.isEmpty) {
      _items.clear();
      hasOlder = false;
      _pageGeneration++;
      loadingOlder = false;
    }
    if (window.isNotEmpty) {
      final ordered = [...window]..sort(_compare);
      final oldest = ordered.last;
      for (final id in _liveIds.difference(ids)) {
        final item = _items[id];
        // A missing item inside the current live range was deleted. An item
        // older than the range merely fell out of the limit and stays cached.
        if (item != null &&
            (window.length < pageSize || _compare(item, oldest) < 0)) {
          _items.remove(id);
        }
      }
    }
    // A reconnect can skip an entire live window. Restart history at its new
    // boundary rather than showing a silent gap between new and cached messages.
    if (_liveIds.isNotEmpty &&
        ids.isNotEmpty &&
        _liveIds.intersection(ids).isEmpty) {
      _items.clear();
      hasOlder = window.length >= pageSize;
      _pageGeneration++;
      loadingOlder = false;
    }
    // Entries leaving the bounded window normally became history, not deletions.
    for (final message in window) {
      _items[message.id] = message;
    }
    _liveIds = ids;
    loading = false;
    liveError = null;
    notifyListeners();
  }

  int _pageGeneration = 0;
  Future<void> loadOlder() async {
    if (_disposed || loading || loadingOlder || !hasOlder || _items.isEmpty) {
      return;
    }
    final generation = _pageGeneration;
    final before = messages.last;
    loadingOlder = true;
    olderError = null;
    notifyListeners();
    try {
      final page = await loadPage(before);
      if (_disposed || generation != _pageGeneration) return;
      for (final message in page) {
        _items.putIfAbsent(message.id, () => message);
      }
      hasOlder = page.length >= pageSize;
    } catch (error) {
      if (_disposed || generation != _pageGeneration) return;
      olderError = error;
    } finally {
      if (!_disposed && generation == _pageGeneration) {
        loadingOlder = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _pageGeneration++;
    _subscription?.cancel();
    super.dispose();
  }
}
