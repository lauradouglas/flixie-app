import 'dart:developer';

/// Profile-mode DevTools timeline spans; no tokens or user identifiers recorded.
class StartupTrace {
  static Future<T> run<T>(String phase, Future<T> Function() action) async {
    final task = TimelineTask()..start('Flixie.$phase');
    try {
      return await action();
    } finally {
      task.finish();
    }
  }

  static void mark(String phase) => Timeline.instantSync('Flixie.$phase');
}
