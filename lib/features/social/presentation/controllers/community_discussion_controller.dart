import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../../data/community_space_service.dart';

/// Owns discussion/reply reads, paging and stale-response protection.
class CommunityDiscussionController extends ChangeNotifier {
  CommunityDiscussionController(
      {required this.communityId,
      required this.discussionId,
      required this.service,
      this.joined}) {
    member = joined ?? false;
  }
  final int communityId;
  final String discussionId;
  final CommunitySpaceService service;
  final bool? joined;
  Map<String, dynamic>? thread;
  final _replies = <Map<String, dynamic>>[];
  late final List<Map<String, dynamic>> replies =
      UnmodifiableListView(_replies);
  bool member = false,
      reveal = false,
      loading = true,
      loadingReplies = false,
      failedMore = false;
  String? error, replyError, next;
  int generation = 0, _replyRevision = 0;
  bool _disposed = false;
  Future<void>? _replyFuture;
  bool _pendingMore = false;
  String get path => '/discussions/$discussionId';
  bool get hidden => thread?['spoiler'] != 'none' && !reveal;
  bool _current(int stamp) => !_disposed && stamp == generation;

  Future<void> load({bool clear = false}) async {
    final stamp = ++generation;
    _replyRevision++;
    _replyFuture = null;
    loadingReplies = false;
    loading = true;
    error = null;
    if (clear) {
      thread = null;
      _replies.clear();
      next = null;
    }
    notifyListeners();
    try {
      if (joined == null) {
        final result = await service.get(communityId, '');
        if (!_current(stamp)) return;
        member = result['joined'] == true;
      }
      final result =
          await service.get(communityId, path, {if (reveal) 'reveal': 'true'});
      if (!_current(stamp)) return;
      thread = result;
      // Useful thread content and replies have independent loading states.
      loading = false;
      notifyListeners();
      if (!hidden) await loadReplies();
    } catch (_) {
      if (_current(stamp)) {
        error =
            'This discussion couldn’t be loaded. It may no longer be available.';
      }
    } finally {
      if (_current(stamp)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadReplies({bool more = false, bool force = false}) {
    if (_disposed || hidden) return Future.value();
    if (_replyFuture != null && !force) {
      if (more || !_pendingMore) return _replyFuture!;
    }
    if (more && next == null) return Future.value();
    _pendingMore = more;
    final future = _readReplies(more);
    _replyFuture = future;
    future.whenComplete(() {
      if (identical(_replyFuture, future)) _replyFuture = null;
    });
    return future;
  }

  Future<void> _readReplies(bool more) async {
    final stamp = generation, revision = ++_replyRevision;
    bool current() => _current(stamp) && revision == _replyRevision;
    loadingReplies = true;
    replyError = null;
    notifyListeners();
    try {
      final page = await service.get(communityId, '$path/replies',
          {'reveal': 'true', if (more) 'cursor': next!});
      if (!current()) return;
      final rows = (page['items'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!more) _replies.clear();
      final ids = _replies.map((r) => r['id']).toSet();
      _replies.addAll(rows.where((r) => ids.add(r['id'])));
      next = page['nextCursor'];
    } catch (_) {
      if (current()) {
        failedMore = more;
        replyError = 'Couldn’t load replies. Try again.';
      }
    } finally {
      if (current()) {
        loadingReplies = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    generation++;
    super.dispose();
  }
}
