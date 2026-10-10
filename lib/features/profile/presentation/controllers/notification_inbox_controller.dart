import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flixie_app/models/notification.dart';
import 'package:flixie_app/core/utils/notification_visibility.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import '../../data/notification_service.dart';

/// Account-owned inbox state. The page supplies route/app visibility.
class NotificationInboxController extends ChangeNotifier {
  NotificationInboxController({
    Future<List<FlixieNotification>> Function(String)? fetch,
    Future<NotificationPage> Function(String, {String? cursor})? fetchPage,
    Future<void> Function()? writeAllRead,
    this.remove = NotificationService.deleteNotification,
    Future<void> Function(String, bool)? writeRead,
    required this.onCache,
    this.pollInterval = const Duration(seconds: 60),
  })  : fetchPage = fetchPage ??
            (fetch == null
                ? NotificationService.getPage
                : ((user, {cursor}) async {
                    final items = await fetch(user);
                    return NotificationPage(items,
                        unreadCount: items.where((n) => !n.isRead).length);
                  })),
        writeAllRead = writeAllRead ??
            (fetch == null && writeRead == null
                ? NotificationService.markAllRead
                : null),
        writeRead = writeRead ?? _writeRead;

  final Future<NotificationPage> Function(String, {String? cursor}) fetchPage;
  final Future<void> Function()? writeAllRead;
  String? _nextCursor;
  bool get hasMore => _nextCursor != null;
  bool loadingMore = false;
  String? pageError;
  int unreadCount = 0;
  bool _supportsBulkRead = true;
  final Future<void> Function(String) remove;
  final Future<void> Function(String, bool) writeRead;
  final void Function(String, List<FlixieNotification>) onCache;
  final Duration pollInterval;
  static Future<void> _writeRead(String id, bool read) async {
    await NotificationService.updateNotification(id, read: read);
  }

  String? _userId;
  int _generation = 0, _revision = 0;
  bool _disposed = false, _active = false;
  Timer? _timer;
  Future<void>? _inFlight;
  List<FlixieNotification> _items = [];
  final Set<String> _hiddenIds = {}, _processingIds = {}, _deletingIds = {};
  bool loading = false;
  String? error;
  int get generation => _generation;
  String? get userId => _userId;
  bool owns(int token) => !_disposed && token == _generation;
  List<FlixieNotification> get notifications =>
      List.unmodifiable(_items.where((n) => !_hiddenIds.contains(n.id)));
  Set<String> get processingIds => Set.unmodifiable(_processingIds);

  void bind(String? user, List<FlixieNotification>? cached,
      {int? totalUnread}) {
    if (_userId == user) return;
    ++_generation;
    ++_revision;
    _inFlight = null;
    _nextCursor = null;
    loadingMore = false;
    pageError = null;
    unreadCount = totalUnread ?? cached?.where((n) => !n.isRead).length ?? 0;
    _timer?.cancel();
    _userId = user;
    _hiddenIds.clear();
    _processingIds.clear();
    _deletingIds.clear();
    _items =
        user == null ? [] : visibleNotificationsForUser(cached ?? [], user);
    loading = user != null && cached == null;
    error = null;
    notifyListeners();
    if (_active && user != null) {
      _startTimer();
      unawaited(refresh());
    }
  }

  void setActive(bool active) {
    if (_active == active || _disposed) return;
    _active = active;
    _timer?.cancel();
    if (active && _userId != null) {
      _startTimer();
      unawaited(refresh(silent: true));
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(pollInterval, (_) => refresh(silent: true));
  }

  /// Joins a current read. Writes can request one fresh read after it finishes.
  Future<void> refresh(
      {bool showSpinner = false,
      bool silent = false,
      bool afterMutation = false}) {
    final user = _userId;
    if (_disposed || user == null) return Future.value();
    final token = _generation;
    final running = _inFlight;
    if (running != null) {
      if (!afterMutation) return running;
      return running.then((_) => owns(token) ? refresh(silent: silent) : null);
    }
    final done = Completer<void>();
    _inFlight = done.future;
    if (showSpinner) {
      loading = true;
      error = null;
      notifyListeners();
    }
    unawaited(
        _fetch(user, token, _revision, silent).whenComplete(done.complete));
    return done.future;
  }

  Future<void> _fetch(String user, int token, int revision, bool silent) async {
    try {
      var page = await fetchPage(user);
      if (!owns(token) || revision != _revision) return;
      final fresh = [...page.items];
      // A periodic/resume refresh must not collapse pages the user is browsing.
      // Revalidate only the already displayed depth, publishing once at the end.
      final visibleDepth = silent ? _items.length : 0;
      final seenCursors = <String>{};
      while (fresh.length < visibleDepth &&
          page.nextCursor != null &&
          seenCursors.add(page.nextCursor!)) {
        page = await fetchPage(user, cursor: page.nextCursor);
        if (!owns(token) || revision != _revision) return;
        fresh.addAll(page.items);
      }
      _items = visibleNotificationsForUser(fresh, user);
      _nextCursor = page.nextCursor;
      _supportsBulkRead = page.supportsBulkRead;
      unreadCount = (page.unreadCount -
              _items
                  .where((n) => _hiddenIds.contains(n.id) && !n.isRead)
                  .length)
          .clamp(0, 1 << 30);
      pageError = null;
      error = null;
      _cache();
    } catch (e) {
      if (!owns(token)) return;
      // The first load must offer retry, even when activated via a resume.
      if (!silent || loading) {
        error = 'Failed to load notifications. Please try again.';
      }
      logger.w('[NotificationInbox] refresh failed: $e');
    } finally {
      if (owns(token)) {
        _inFlight = null;
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    final user = _userId, cursor = _nextCursor;
    if (_disposed ||
        user == null ||
        cursor == null ||
        loadingMore ||
        _inFlight != null) {
      return;
    }
    final token = _generation, revision = _revision;
    final done = Completer<void>();
    _inFlight = done.future;
    loadingMore = true;
    pageError = null;
    notifyListeners();
    try {
      final page = await fetchPage(user, cursor: cursor);
      if (!owns(token) || revision != _revision) return;
      final byId = {
        for (final n in _items) n.id: n,
        for (final n in page.items) n.id: n
      };
      _items = visibleNotificationsForUser(byId.values, user);
      _nextCursor = page.nextCursor;
      _supportsBulkRead = page.supportsBulkRead;
      unreadCount = (page.unreadCount -
              _items
                  .where((n) => _hiddenIds.contains(n.id) && !n.isRead)
                  .length)
          .clamp(0, 1 << 30);
      _cache();
    } catch (_) {
      if (owns(token)) {
        pageError = 'Could not load older notifications. Try again.';
      }
    } finally {
      if (owns(token)) {
        loadingMore = false;
        _inFlight = null;
        notifyListeners();
      }
      done.complete();
    }
  }

  void _cache() {
    final user = _userId;
    if (!_disposed && user != null) onCache(user, notifications);
  }

  bool beginResponse(String id) {
    if (_disposed || _userId == null || !_processingIds.add(id)) return false;
    notifyListeners();
    return true;
  }

  void endResponse(String id, int token) {
    if (!owns(token)) return;
    _processingIds.remove(id);
    notifyListeners();
  }

  void responseSaved(String id, int token) {
    if (!owns(token)) return;
    ++_revision;
    if (_hiddenIds.add(id) && _items.any((n) => n.id == id && !n.isRead)) {
      unreadCount = (unreadCount - 1).clamp(0, 1 << 30);
    }
    _cache();
    notifyListeners();
  }

  Future<bool?> dismiss(FlixieNotification notification) async {
    final id = notification.id;
    if (id == null || _disposed || _userId == null || !_deletingIds.add(id)) {
      return null;
    }
    final token = _generation;
    final plan = notification.linkedRequestId;
    bool samePlan(FlixieNotification n) =>
        plan != null &&
        (notification.type == FlixieNotification.movieWatchRequest ||
            notification.type == FlixieNotification.showWatchRequest) &&
        (n.type == FlixieNotification.movieWatchRequest ||
            n.type == FlixieNotification.showWatchRequest) &&
        n.linkedRequestId == plan;
    final removed = _items.where((n) => n.id == id || samePlan(n)).toList();
    final ids = {id, ...removed.map((n) => n.id).whereType<String>()};
    final newlyHidden = ids.difference(_hiddenIds);
    final removedUnread =
        removed.where((n) => newlyHidden.contains(n.id) && !n.isRead).length;
    ++_revision;
    unreadCount = (unreadCount - removedUnread).clamp(0, 1 << 30);
    _hiddenIds.addAll(ids);
    _cache();
    notifyListeners();
    try {
      await remove(id);
      if (!owns(token)) return null;
      ++_revision;
      await refresh(afterMutation: true, silent: true);
      return owns(token) ? true : null;
    } catch (e) {
      if (!owns(token)) return null;
      ++_revision;
      _hiddenIds.removeAll(newlyHidden);
      unreadCount += removedUnread;
      // Restore every duplicate card even if a concurrent refresh omitted it.
      final existing = _items.map((n) => n.id).toSet();
      _items = [..._items, ...removed.where((n) => !existing.contains(n.id))];
      _cache();
      notifyListeners();
      await refresh(afterMutation: true, silent: true);
      return owns(token) ? false : null;
    } finally {
      if (owns(token)) _deletingIds.remove(id);
    }
  }

  Future<bool?> setRead(FlixieNotification notification, bool read) async {
    final id = notification.id;
    if (id == null || _disposed || _userId == null) return null;
    final token = _generation;
    try {
      await writeRead(id, read);
      if (!owns(token)) return null;
      ++_revision;
      if (notification.isRead != read) {
        unreadCount = (unreadCount + (read ? -1 : 1)).clamp(0, 1 << 30);
      }
      _items =
          _items.map((n) => n.id == id ? n.copyWith(read: read) : n).toList();
      _cache();
      notifyListeners();
      return true;
    } catch (_) {
      return owns(token) ? false : null;
    }
  }

  Future<bool> markAllRead() async {
    final token = _generation;
    if (writeAllRead != null && _supportsBulkRead) {
      try {
        await writeAllRead!();
        if (!owns(token)) return false;
        ++_revision;
        unreadCount = 0;
        _items = _items.map((n) => n.copyWith(read: true)).toList();
        _cache();
        notifyListeners();
        return true;
      } catch (_) {
        return false;
      }
    }
    var success = true;
    for (final n in notifications) {
      if (!owns(token)) break;
      if (!n.isRead && await setRead(n, true) == false) success = false;
    }
    return success;
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _timer?.cancel();
    super.dispose();
  }
}
