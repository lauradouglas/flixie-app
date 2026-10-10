import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/settings/presentation/controllers/settings_username_check.dart';

void main() {
  testWidgets('typing burst makes only the final availability request',
      (tester) async {
    final requests = <String>[];
    final check = SettingsUsernameCheck(
        original: 'Viewer',
        exists: (name) async {
          requests.add(name);
          return false;
        });
    addTearDown(check.dispose);
    for (final name in ['Alien', 'Aliens', 'Alienfan']) {
      check.update(name);
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(requests, isEmpty);
    await tester.pump(const Duration(milliseconds: 400));
    expect(requests, ['Alienfan']);
    expect(check.checking, isFalse);
  });

  for (final reset in ['Al', 'Viewer']) {
    testWidgets('reset to $reset cancels pending HTTP work', (tester) async {
      var requests = 0;
      final check = SettingsUsernameCheck(
          original: 'Viewer',
          exists: (_) async {
            requests++;
            return true;
          });
      addTearDown(check.dispose);
      check.update('Alien');
      await tester.pump(const Duration(milliseconds: 200));
      check.update(reset);
      await tester.pump(const Duration(seconds: 1));
      expect(requests, 0);
      expect(check.checking, isFalse);
      expect(check.error,
          reset == 'Viewer' ? null : 'At least 3 characters required');
    });
  }

  testWidgets('older response cannot replace latest validation',
      (tester) async {
    final pending = <String, Completer<bool>>{};
    final check = SettingsUsernameCheck(
        original: 'Viewer',
        exists: (name) {
          return (pending[name] = Completer<bool>()).future;
        });
    addTearDown(check.dispose);
    check.update('Alien');
    await tester.pump(const Duration(milliseconds: 600));
    check.update('Odyssey');
    await tester.pump(const Duration(milliseconds: 600));
    pending['Odyssey']!.complete(false);
    await tester.pump();
    pending['Alien']!.complete(true);
    await tester.pump();
    expect(check.error, isNull);
    expect(check.checking, isFalse);
  });

  testWidgets('dispose cancels debounce and ignores in-flight completion',
      (tester) async {
    var requests = 0;
    final pending = Completer<bool>();
    final check = SettingsUsernameCheck(
        original: 'Viewer',
        exists: (_) {
          requests++;
          return pending.future;
        });
    var notifications = 0;
    check.addListener(() => notifications++);
    check.update('Alien');
    await tester.pump(const Duration(milliseconds: 600));
    check.update('Odyssey');
    check.dispose();
    final before = notifications;
    pending.complete(true);
    await tester.pump(const Duration(seconds: 1));
    expect(requests, 1);
    expect(notifications, before);
  });
}
