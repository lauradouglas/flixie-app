import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flixie_app/features/library_import/data/library_import_session.dart';
import 'package:flixie_app/features/library_import/data/library_import_models.dart';
import 'package:flixie_app/features/library_import/presentation/library_import_screen.dart';

LibraryImportData fixture() => LibraryImportData([
      for (final id in [1, 2])
        LibraryImportRow(title: 'Alien $id', source: 'fixture', watchlist: true)
          ..status = 'ready'
          ..match = {'id': id, 'mediaType': 'movie'}
    ], []);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'leave during import, browse, then receive one completion toast and reopen progress',
      (tester) async {
    final release = Completer<void>();
    final messenger = GlobalKey<ScaffoldMessengerState>();
    var calls = 0, notices = 0;
    final session = LibraryImportSession(request: (action, body) async {
      calls++;
      if (calls == 1) await release.future;
      return {'watchlist': 'added'};
    }, onNotice: (message, failed, changed) {
      notices++;
      expect(failed, LibraryImportNoticeKind.success);
      expect(changed, true);
      messenger.currentState!.showFlixieToast(
          FlixieToast(content: Text(message), type: FlixieToastType.success));
    });
    addTearDown(session.dispose);
    final controller = session.forUser('a', isCurrentUser: () => true);
    await controller.setData(fixture());
    await tester.pumpWidget(MaterialApp(
        scaffoldMessengerKey: messenger,
        theme: AppTheme.darkTheme,
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => LibraryImportScreen(
                                controller: session.forUser('a',
                                    isCurrentUser: () => true)))),
                    child: const Text('Browse library'))))));
    await tester.tap(find.text('Browse library'));
    await tester.pumpAndSettle();
    final importing = controller.commit();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(controller.busy, true);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Browse library'), findsOneWidget);
    expect(controller.busy, true);
    expect(controller.paused, false);
    release.complete();
    await tester.runAsync(() => importing);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls, 2);
    expect(notices, 1);
    expect(find.text('Import complete. 2 titles saved.'), findsOneWidget);
    expect(
        identical(session.forUser('a', isCurrentUser: () => true), controller),
        true);
    expect(controller.doneCount, 2);
    await controller.commit();
    expect(notices, 1);
    await tester.pump(const Duration(seconds: 6));
  });

  test(
      'sign-out stops subsequent rows and suppresses completion for the next account',
      () async {
    final entered = Completer<void>(), release = Completer<void>();
    var calls = 0, notices = 0;
    final session = LibraryImportSession(
        request: (action, body) async {
          calls++;
          entered.complete();
          await release.future;
          return {'watchlist': 'added'};
        },
        onNotice: (_, __, ___) => notices++);
    addTearDown(session.dispose);
    final controller = session.forUser('a', isCurrentUser: () => true);
    await controller.setData(fixture());
    final importing = controller.commit();
    await entered.future;
    session.syncUser(null);
    final next = session.forUser('b', isCurrentUser: () => true);
    release.complete();
    await importing;
    expect(calls, 1);
    expect(notices, 0);
    expect(next.data, null);
    session.syncUser(null);
    final restored = session.forUser('a', isCurrentUser: () => true);
    await restored.restore();
    expect(restored.doneCount, 1);
    expect(restored.readyCount, 1);
  });

  test(
      'failure preserves remaining work and retry produces a completion notice',
      () async {
    var fail = true;
    final notices = <LibraryImportNoticeKind>[];
    final session = LibraryImportSession(
        request: (_, __) async {
          if (fail) throw StateError('offline');
          return {'watchlist': 'added'};
        },
        onNotice: (_, failed, __) => notices.add(failed));
    addTearDown(session.dispose);
    final controller = session.forUser('a', isCurrentUser: () => true);
    await controller.setData(fixture());
    await controller.commit();
    expect(notices, [LibraryImportNoticeKind.error]);
    expect(controller.readyCount, 2);
    fail = false;
    await controller.commit();
    expect(notices,
        [LibraryImportNoticeKind.error, LibraryImportNoticeKind.success]);
    expect(controller.doneCount, 2);
  });
}
