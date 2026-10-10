import 'package:flutter/foundation.dart';
import 'library_import_controller.dart';

enum LibraryImportNoticeKind { success, info, error }

/// Owns an import across routes, but never across signed-in accounts.
class LibraryImportSession extends ChangeNotifier {
  LibraryImportSession({this.onNotice, this.request});
  final void Function(
      String message, LibraryImportNoticeKind kind, bool changed)? onNotice;
  final ImportRequest? request;
  LibraryImportController? _controller;
  String? _userId;
  int _generation = 0;
  bool _wasBusy = false;
  int _startingDone = 0;

  void syncUser(String? userId) {
    if (_userId == userId) return;
    _generation++;
    _controller?.dispose();
    _controller = null;
    _userId = userId;
    _wasBusy = false;
  }

  LibraryImportController forUser(String userId,
      {required bool Function() isCurrentUser}) {
    syncUser(userId);
    final generation = _generation;
    if (_controller != null) return _controller!;
    final controller = LibraryImportController(
        userId: userId,
        isCurrentUser: () => generation == _generation && isCurrentUser(),
        request: request)
      ..addListener(_changed);
    _controller = controller;
    return controller;
  }

  void _changed() {
    final controller = _controller;
    if (controller == null || !controller.isCurrentUser()) return;
    if (controller.busy && !_wasBusy) {
      _startingDone = controller.doneCount;
    }
    final finished = _wasBusy && !controller.busy;
    _wasBusy = controller.busy;
    if (!finished) return;
    final changed = controller.doneCount > _startingDone;
    final failed = controller.error != null;
    final message = controller.error ??
        (controller.paused
            ? 'Import paused. Your progress is saved.'
            : controller.phase == 'Finding your titles'
                ? 'Your titles are ready to review in Import ratings & watchlist.'
                : 'Import complete. ${controller.doneCount} titles saved.');
    final kind = failed
        ? LibraryImportNoticeKind.error
        : controller.paused || controller.phase == 'Finding your titles'
            ? LibraryImportNoticeKind.info
            : LibraryImportNoticeKind.success;
    onNotice?.call(message, kind, changed);
  }

  @override
  void dispose() {
    _generation++;
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }
}
