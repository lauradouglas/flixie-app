import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/guest/presentation/guest_access.dart';
import 'package:flixie_app/features/guest/presentation/guest_diary_page.dart';
import '../movies/movie_detail_action_flow_test.dart' show ActionAuth;
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/features/guest/data/guest_diary_store.dart';
import 'package:flixie_app/features/guest/models/guest_diary_draft.dart';
import 'package:flixie_app/features/guest/presentation/widgets/guest_diary_editor.dart';
import '../authentication/signup_journey_test.dart'
    show JourneyAuth, JourneyData, pumpJourney;

const entry = GuestDiaryDraft(
    id: '58894e1b-9d40-4f71-a258-e58c760b07fa',
    movieId: 348,
    title: 'Alien',
    rating: 9,
    date: '2026-10-20',
    note: 'That final scene!',
    recommended: true);

class SwitchingDiaryAuth extends JourneyAuth {
  void simulateSignOut() {
    account = null;
    notifyListeners();
  }
}

class RetryDiaryData extends JourneyData {
  bool fail = true;
  final attempts = <LogMovieWatchRequest>[];
  @override
  Future<MovieWatchEntry> log(String user, LogMovieWatchRequest request) async {
    attempts.add(request);
    if (fail) throw StateError('Offline');
    return super.log(user, request);
  }
}

Future<void> guestDiaryContinuation(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  GuestDiaryStore.instance = GuestDiaryStore();
  await GuestDiaryStore.instance.save(entry);
  await GuestDiaryStore.instance.beginSignup(entry.id);
  await GuestDiaryStore.instance.claim('fixture');
  final data = RetryDiaryData(), auth = JourneyAuth();
  final router =
      await pumpJourney(tester, 'log', data, auth, diaryDraftId: entry.id);
  addTearDown(router.dispose);
  await tester.pumpAndSettle();
  expect(data.attempts, isEmpty);
  expect(find.text(entry.note), findsOneWidget);
  await tester.ensureVisible(find.text('Save to my account'));
  await tester.tap(find.text('Save to my account'));
  await tester.pumpAndSettle();
  expect(
      find.text('Couldn’t finish saving. Your entry is still here. Try again.'),
      findsOneWidget);
  final retained = await GuestDiaryStore.instance.read(entry.id, 'fixture');
  expect(retained!.note, entry.note);
  expect(retained.submitted, isTrue);
  data.fail = false;
  await tester.ensureVisible(find.text('Save to my account'));
  await tester.tap(find.text('Save to my account'));
  await tester.pumpAndSettle();
  expect(data.attempts, hasLength(2));
  expect(data.attempts[0].draftId, data.attempts[1].draftId);
  expect(data.attempts[1].notes, entry.note);
  expect(await GuestDiaryStore.instance.read(entry.id, 'fixture'), isNull);
}

Future<void> guestDiaryDraftJourney(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  GuestDiaryStore.instance = GuestDiaryStore();
  GuestAccess.clear();
  final auth = ActionAuth();
  final router = GoRouter(routes: [
    GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
            body: TextButton(
                onPressed: () => GuestAccess.require(context,
                    path: '/movies/348', intent: 'log', mediaTitle: 'Alien'),
                child: const Text('Log Alien')))),
    GoRoute(
        path: '/guest-diary',
        builder: (_, s) =>
            GuestDiaryPage(draftId: s.uri.queryParameters['draft'])),
    GoRoute(
        path: '/auth/signup',
        builder: (_, __) => const Scaffold(body: Text('Account details'))),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child:
          MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router)));
  await tester.tap(find.text('Log Alien'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('9'));
  await tester.enterText(find.byType(TextField).first, '2026-10-20');
  await tester.enterText(find.byType(TextField).last, 'That final scene!');
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
      find.text('Preview my entry').hitTestable(), 250,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Preview my entry'));
  await tester.pumpAndSettle();
  expect(find.text('Dear film diary,'), findsOneWidget);
  expect(find.text('That final scene!'), findsOneWidget);
  await tester.scrollUntilVisible(
      find.text('Create account & keep my entry').hitTestable(), 250,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Create account & keep my entry'));
  await tester.pumpAndSettle();
  expect(find.text('Account details'), findsOneWidget);
  final bound = await GuestDiaryStore().claim('fixture');
  expect(bound!.movieId, 348);
  expect(bound.rating, 9);
  expect(bound.date, '2026-10-20');
  expect(bound.note, 'That final scene!');
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GuestDiaryStore.instance = GuestDiaryStore();
  });
  testWidgets('guest logs and previews before signup without losing fields',
      guestDiaryDraftJourney);
  testWidgets('account draft disappears immediately on sign out',
      (tester) async {
    await GuestDiaryStore.instance.save(entry);
    await GuestDiaryStore.instance.beginSignup(entry.id);
    await GuestDiaryStore.instance.claim('fixture');
    final auth = SwitchingDiaryAuth();
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(home: GuestDiaryPage(draftId: entry.id))));
    await tester.pumpAndSettle();
    expect(find.text(entry.note), findsOneWidget);
    auth.simulateSignOut();
    await tester.pumpAndSettle();
    expect(find.text(entry.note), findsNothing);
    expect(await GuestDiaryStore.instance.read(entry.id, 'fixture'), isNotNull);
  });
  test('draft survives store recreation and binds only to chosen account',
      () async {
    final store = GuestDiaryStore();
    await store.save(entry);
    await store.beginSignup(entry.id);
    final restored = await GuestDiaryStore().claim('fixture');
    expect(restored!.rating, 9);
    expect(restored.date, entry.date);
    expect(restored.note, entry.note);
    expect(restored.recommended, true);
    expect(restored.movieId, 348);
    expect(await GuestDiaryStore().claim('someone-else'), isNull);
    expect(await GuestDiaryStore().list(null), isEmpty);
    expect(() => store.save(entry), throwsStateError);
    await store.pause(entry.id);
    expect(await store.claim('fixture'), isNull);
    expect((await store.list('fixture')).single.note, entry.note);
  });
  test('queued edits retain latest value and unknown dates stay unknown',
      () async {
    final store = GuestDiaryStore();
    final writes = [
      for (var n = 1; n <= 10; n++)
        store.save(GuestDiaryDraft(
            id: entry.id, movieId: 348, title: 'Alien', rating: n))
    ];
    await Future.wait(writes);
    final draft = (await store.list(null)).single;
    expect(draft.rating, 10);
    expect(draft.date, '');
    expect(draft.validate(), isNull);
    expect(
        const GuestDiaryDraft(
                id: 'x', movieId: 348, title: 'Alien', date: '2026-02-30')
            .validate(),
        isNotNull);
    expect(
        const GuestDiaryDraft(
                id: 'x', movieId: 348, title: 'Alien', logWatch: false)
            .validate(),
        isNotNull);
  });
  testWidgets('typing survives leaving editor without preview', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: GuestDiaryEditor(
                    draft: entry, onContinue: (_) async {})))));
    await tester.enterText(find.byType(TextField).last, 'My new memory');
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    final restored = await GuestDiaryStore().read(entry.id, null);
    expect(restored!.note, 'My new memory');
    expect(restored.rating, 9);
    expect(restored.date, entry.date);
  });
  testWidgets(
      'signup continuation restores every field and saves only on explicit action',
      (tester) async {
    await GuestDiaryStore.instance.save(entry);
    await GuestDiaryStore.instance.beginSignup(entry.id);
    await GuestDiaryStore.instance.claim('fixture');
    final data = JourneyData();
    final auth = JourneyAuth();
    final router =
        await pumpJourney(tester, 'log', data, auth, diaryDraftId: entry.id);
    addTearDown(router.dispose);
    expect(data.logs, isEmpty);
    expect(find.text(entry.note), findsOneWidget);
    expect(find.text(entry.date), findsOneWidget);
    await tester.ensureVisible(find.text('Save to my account'));
    await tester.tap(find.text('Save to my account'));
    await tester.pumpAndSettle();
    expect(data.logs, hasLength(1));
    final sent = data.logs.single;
    expect(sent.draftId, entry.id);
    expect(sent.rating, 9);
    expect(sent.notes, entry.note);
    expect(sent.recommended, true);
    expect(DateTime.parse(sent.watchedAt!).toLocal().day, 20);
    expect(await GuestDiaryStore.instance.read(entry.id, 'fixture'), isNull);
  });
  testWidgets('failed account save retains draft and retries the same entry',
      guestDiaryContinuation);
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(834, 1112)
  ]) {
    testWidgets('editor wraps at $size and large text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      if (Platform.environment['FLIXIE_CAPTURE_DIARY'] == '1') {
        await tester.runAsync(() async {
          final loader = FontLoader('Manrope')
            ..addFont(
                rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'));
          await loader.load();
        });
      }
      final boundary = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: boundary,
          child: MaterialApp(
              theme: AppTheme.darkTheme,
              debugShowCheckedModeBanner: false,
              home: MediaQuery(
                  data: MediaQueryData(
                      size: size,
                      textScaler:
                          TextScaler.linear(size.width == 320 ? 2 : 1.5)),
                  child: Scaffold(
                      body: SingleChildScrollView(
                          child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: GuestDiaryEditor(
                                  draft: entry,
                                  onContinue: (_) async {}))))))));
      await tester.pumpAndSettle();
      if (Platform.environment['FLIXIE_CAPTURE_DIARY'] == '1') {
        await tester.runAsync(() async {
          final image = await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final directory = Directory('output/guest-diary-implementation')
            ..createSync(recursive: true);
          File('${directory.path}/editor-${size.width.toInt()}.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.ensureVisible(find.text('Preview my entry'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
