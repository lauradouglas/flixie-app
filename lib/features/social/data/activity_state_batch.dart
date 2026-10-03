import 'package:flixie_app/core/safety/safety_service.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flixie_app/core/api/api_client.dart';

/// Coalesces visible cards and bookmark buttons into bounded, viewer-scoped reads.
class ActivityStateBatch {
  static final _cache =
      <String, ({DateTime time, Future<Map<String, dynamic>> value})>{};
  static final _pending = <String,
      ({
    Map<String, dynamic> target,
    Completer<Map<String, dynamic>> result
  })>{};
  static Timer? _timer;
  static String? _viewer;
  static bool _listening = false;
  static int _revision = -1, _generation = 0;

  static void clear() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _cache.clear();
    for (final entry in _pending.values) {
      entry.result.completeError(StateError('Activity viewer changed'));
    }
    _pending.clear();
  }

  static Future<Map<String, dynamic>> load(
      {required String viewer,
      required String owner,
      required String type,
      required String id,
      required bool community,
      bool force = false}) {
    if (!_listening) {
      SafetyService.changes.addListener(clear);
      _listening = true;
    }
    if (_viewer != viewer || _revision != ApiClient.tokenRevision) {
      clear();
      _viewer = viewer;
      _revision = ApiClient.tokenRevision;
    }
    if (type.startsWith('watch-request') || type == 'unknown') {
      return Future.value({'reactions': <String, dynamic>{}});
    }
    final key = jsonEncode([community, owner, type, id]);
    final cached = _cache[key];
    if (!force &&
        cached != null &&
        DateTime.now().difference(cached.time).inSeconds < 20) {
      return cached.value;
    }
    final queued = _pending[key];
    if (queued != null) return queued.result.future;
    final completer = Completer<Map<String, dynamic>>();
    _pending[key] = (
      target: {
        'community': community,
        'ownerId': owner,
        'activityType': type,
        'activityId': id
      },
      result: completer
    );
    if (_cache.length >= 200) _cache.clear();
    _cache[key] = (time: DateTime.now(), value: completer.future);
    _timer ??= Timer(Duration.zero, _flush);
    return completer.future;
  }

  static Future<void> _flush() async {
    _timer = null;
    final generation = _generation;
    final entries = _pending.entries.toList();
    _pending.clear();
    for (var start = 0; start < entries.length; start += 50) {
      final batch = entries.skip(start).take(50).toList();
      try {
        if (generation != _generation) {
          throw StateError('Activity viewer changed');
        }
        Map data;
        try {
          data = await ApiClient.post('/community/activity-state', body: {
            'targets': batch.map((entry) => entry.value.target).toList(),
          }) as Map;
        } on ApiException catch (error) {
          // Deployment order is flexible: only an absent endpoint uses legacy reads.
          if (error.statusCode != 404 && error.statusCode != 405) rethrow;
          if (generation != _generation) {
            throw StateError('Activity viewer changed');
          }
          data = {
            'items': await Future.wait(
                batch.map((entry) => _legacy(entry.value.target)))
          };
        }
        if (generation != _generation) {
          throw StateError('Activity viewer changed');
        }
        final results = <String, Map<String, dynamic>>{};
        for (final row in data['items'] as List) {
          final value = Map<String, dynamic>.from(row as Map);
          results[jsonEncode([
            value['community'],
            value['ownerId'],
            value['activityType'],
            value['activityId']
          ])] = value;
        }
        for (final entry in batch) {
          final value = results[entry.key];
          if (value == null) {
            _cache.remove(entry.key);
            entry.value.result
                .completeError(StateError('Activity is unavailable'));
          } else {
            entry.value.result.complete(value);
          }
        }
      } catch (error, stack) {
        for (final entry in batch) {
          if (generation == _generation) _cache.remove(entry.key);
          if (!entry.value.result.isCompleted) {
            entry.value.result.completeError(error, stack);
          }
        }
      }
    }
  }

  static Future<Map<String, dynamic>> _legacy(
      Map<String, dynamic> target) async {
    final owner = Uri.encodeComponent(target['ownerId'] as String);
    final type = Uri.encodeComponent(target['activityType'] as String);
    final id = Uri.encodeComponent(target['activityId'] as String);
    if (target['community'] == true) {
      final values = await Future.wait([
        ApiClient.get('/community/reactions/$owner/$type/$id'),
        ApiClient.get('/community/posts/$owner/$type/$id/bookmark'),
      ]);
      return {
        ...target,
        'reactions': values[0],
        'saved': values[1]['saved'] == true
      };
    }
    final values =
        await ApiClient.get('/friends/activity-reactions/$owner') as Map;
    return {
      ...target,
      'reactions':
          values['${target['activityType']}:${target['activityId']}'] ??
              <String, dynamic>{}
    };
  }
}
