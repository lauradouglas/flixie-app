import 'dart:developer';

/// Timeline spans with an optional bounded benchmark observer. Never include
/// tokens, account identifiers, titles or raw URLs in event names/arguments.
class StartupTrace {
  static void Function(Map<String, Object?> event)? observer;
  static final _clock = Stopwatch()..start();
  static int _nextId = 0;

  static void _record(String phase, String kind, int id,
      [Map<String, Object?> fields = const {}]) {
    observer?.call({
      'phase': phase,
      'kind': kind,
      'id': id,
      'atUs': _clock.elapsedMicroseconds,
      ...fields
    });
  }

  static Future<T> run<T>(String phase, Future<T> Function() action) async {
    final id = ++_nextId;
    final task = TimelineTask()..start('Flixie.$phase');
    _record(phase, 'start', id);
    try {
      return await action();
    } finally {
      task.finish();
      _record(phase, 'end', id);
    }
  }

  static T sync<T>(String phase, T Function() action) {
    final id = ++_nextId;
    _record(phase, 'start', id);
    try {
      return action();
    } finally {
      _record(phase, 'end', id);
    }
  }

  static void mark(String phase, [Map<String, Object?> fields = const {}]) {
    Timeline.instantSync('Flixie.$phase', arguments: fields);
    _record(phase, 'mark', ++_nextId, fields);
  }
}
