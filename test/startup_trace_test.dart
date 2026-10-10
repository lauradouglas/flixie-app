import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/auth/startup_trace.dart';

void main() {
  test(
      'trace pairs overlapping work and closes failures without swallowing them',
      () async {
    final events = <Map<String, Object?>>[];
    StartupTrace.observer = events.add;
    addTearDown(() => StartupTrace.observer = null);
    expect(await StartupTrace.run('fixture', () async => 7), 7);
    await expectLater(
        StartupTrace.run('failure', () async => throw StateError('failed')),
        throwsStateError);
    expect(StartupTrace.sync('decode', () => 8), 8);
    StartupTrace.mark('frame', {'count': 2});
    expect(events.map((e) => e['kind']),
        ['start', 'end', 'start', 'end', 'start', 'end', 'mark']);
    for (var index = 0; index < 6; index += 2) {
      expect(events[index]['id'], events[index + 1]['id']);
      expect(events[index + 1]['atUs'] as int,
          greaterThanOrEqualTo(events[index]['atUs'] as int));
    }
    expect(events.last['count'], 2);
  });
}
