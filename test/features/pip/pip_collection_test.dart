import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/core/app_icon/app_icon_service.dart';
import 'package:flixie_app/features/pip/data/pip_collection_service.dart';
import 'package:flixie_app/features/pip/models/pip_collection.dart';
import 'package:flixie_app/features/pip/presentation/controllers/pip_collection_controller.dart';
import 'package:flixie_app/features/pip/presentation/widgets/my_pip_sheet.dart';

class FakePips extends PipCollectionService {
  PipCollection value =
      const PipCollection(cinemaUnlocked: true, celebrationPending: true);
  bool fail = false;
  Completer<PipCollection>? pending;
  final writes = <Map<String, dynamic>>[];
  @override
  Future<PipCollection> load() => pending?.future ?? Future.value(value);
  @override
  Future<PipCollection> update(Map<String, dynamic> body) async {
    writes.add(body);
    if (fail) throw Exception('offline');
    return value = PipCollection(
        activePip: body['activePip'] as String? ?? value.activePip,
        cinemaUnlocked: value.cinemaUnlocked,
        ogUnlocked: value.ogUnlocked,
        celebrationPending:
            body['seen'] == true ? false : value.celebrationPending);
  }
}

Future<void> pipChoiceJourney(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  const channel = MethodChannel('pip_test');
  var native = 'default', attempts = 0;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    if (call.method == 'status') return {'supported': true, 'selected': native};
    attempts++;
    if (attempts == 1) throw PlatformException(code: 'ICON_FAILED');
    native = call.arguments as String;
    return null;
  });
  // The service entitlement/account is exercised independently below; native
  // failure is surfaced here via an injected icon service with a fixture user.
  final icons = TestIcons(channel: channel);
  final service = FakePips();
  final c = PipCollectionController(service: service, icons: icons);
  c.syncUser('fixture', 0);
  await tester.pumpAndSettle();
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: MyPipSheet(controller: c, icons: icons))));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Pip outfit'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Cinema Club'));
  await tester.tap(find.text('Cinema Club'));
  await tester.pumpAndSettle();
  service.fail = true;
  await tester.ensureVisible(find.text('Use this Pip'));
  await tester.tap(find.text('Use this Pip'));
  await tester.pumpAndSettle();
  expect(c.collection.activePip, 'classic');
  expect(find.text('Pip saved'), findsNothing);
  expect(find.textContaining('Couldn’t save your Pip'), findsOneWidget);
  service.fail = false;
  await tester.ensureVisible(find.text('Try again'));
  await tester.tap(find.text('Try again'));
  await tester.pumpAndSettle();
  expect(c.collection.activePip, 'cinemaClub');
  expect(find.text('Pip saved'), findsOneWidget);
  expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  expect(service.writes.last, {'activePip': 'cinemaClub'});
  await tester.ensureVisible(find.text('App icon'));
  await tester.tap(find.text('App icon'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Pip peeks in'));
  await tester.tap(find.text('Pip peeks in'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Use this icon'));
  await tester.tap(find.text('Use this icon'));
  await tester.pumpAndSettle();
  expect(native, 'default');
  expect(find.textContaining('Your icon hasn’t changed'), findsOneWidget);
  await tester.ensureVisible(find.text('Try again'));
  await tester.tap(find.text('Try again'));
  await tester.pumpAndSettle();
  expect(native, 'pipPeeksIn');
  expect(find.text('App icon saved'), findsOneWidget);
  expect(c.collection.activePip, 'cinemaClub');
  await tester.pumpWidget(const SizedBox());
  c.dispose();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null);
}

class TestIcons extends AppIconService {
  TestIcons({required MethodChannel channel})
      : _testChannel = channel,
        super(channel: channel);
  final MethodChannel _testChannel;
  @override
  Future<void> select(String icon) =>
      _testChannel.invokeMethod<void>('set', icon);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'celebration hugs content and keeps the current look with a full-width button',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final service = FakePips();
    final c = PipCollectionController(service: service);
    c.syncUser('fixture', 0);
    await tester.pumpAndSettle();
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        useRootNavigator: true,
                        useSafeArea: true,
                        isScrollControlled: true,
                        builder: (_) =>
                            MyPipSheet(controller: c, celebrate: true)),
                    child: const Text('Open reward'))))));
    await tester.tap(find.text('Open reward'));
    await tester.pumpAndSettle();
    final sheet = find.byKey(const ValueKey('my-pip-content-sheet'));
    final keep = find.widgetWithText(OutlinedButton, 'Keep my current look');
    expect(keep, findsOneWidget);
    expect(tester.getSize(sheet).height, lessThan(1200 * .85 - 100));
    expect(tester.getBottomLeft(sheet).dy - tester.getBottomLeft(keep).dy,
        closeTo(24, 2));
    expect(
        tester.getSize(keep).width,
        tester
            .getSize(find.widgetWithText(FilledButton, 'Choose my look'))
            .width);
    await tester.tap(keep);
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
    expect(c.collection.activePip, 'classic');
    expect(service.writes, isEmpty);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
      'outfit save and native icon failure retain selection and retry independently',
      pipChoiceJourney);
  for (final size in [
    const Size(320, 640),
    const Size(834, 1112),
    const Size(740, 390)
  ]) {
    testWidgets('Pip sheet reflows at $size with large text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = PipCollectionController(service: FakePips());
      c.syncUser('fixture', 0);
      await tester.pumpAndSettle();
      await tester.pumpWidget(MaterialApp(
          builder: (_, child) => MediaQuery(
              data: MediaQueryData(
                  size: size, textScaler: const TextScaler.linear(2)),
              child: child!),
          home: Scaffold(body: MyPipSheet(controller: c))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Pip outfit'));
      await tester.tap(find.text('Pip outfit'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Use this Pip'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });
  }
  testWidgets(
      'an account change rejects stale collection response and clears selection',
      (tester) async {
    final fake = FakePips()..pending = Completer<PipCollection>();
    final c = PipCollectionController(service: fake);
    c.syncUser('alice', 0);
    await tester.pump();
    await tester.pump();
    final old = fake.pending!;
    fake.pending = null;
    fake.value = const PipCollection();
    c.syncUser('bob', 0);
    await tester.pumpAndSettle();
    old.complete(
        const PipCollection(activePip: 'cinemaClub', cinemaUnlocked: true));
    await tester.pumpAndSettle();
    expect(c.userId, 'bob');
    expect(c.collection.cinemaUnlocked, isFalse);
    expect(c.collection.activePip, 'classic');
    c.dispose();
  });
  testWidgets('locked collection cannot select Cinema Club', (tester) async {
    final fake = FakePips()..value = const PipCollection();
    final c = PipCollectionController(service: fake);
    c.syncUser('fixture', 0);
    await tester.pumpAndSettle();
    await expectLater(c.select('cinemaClub'), throwsStateError);
    expect(fake.writes, isEmpty);
    c.dispose();
  });
  test(
      'OG parsing requires server entitlement and preserves old payload defaults',
      () {
    expect(PipCollection.fromJson({'activePip': 'og'}).activePip, 'classic');
    final og = PipCollection.fromJson({'activePip': 'og', 'ogUnlocked': true});
    expect(og.activePip, 'og');
    expect(PipCollection.fromJson(og.toJson()).ogUnlocked, isTrue);
    expect(PipCollection.asset('og'), endsWith('/og.png'));
  });
  for (final owned in [false, true]) {
    testWidgets('First 100 OG option eligibility $owned and explicit save',
        (tester) async {
      final fake = FakePips()..value = PipCollection(ogUnlocked: owned);
      final c = PipCollectionController(service: fake);
      c.syncUser('fictional-first-100', 0);
      await tester.pumpAndSettle();
      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: MyPipSheet(controller: c))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pip outfit'));
      await tester.pumpAndSettle();
      if (owned) {
        await tester.ensureVisible(find.text('OG Pip'));
        await tester.tap(find.text('OG Pip'));
        await tester.pumpAndSettle();
        expect(fake.writes, isEmpty);
        await tester.ensureVisible(find.text('Use this Pip'));
        await tester.tap(find.text('Use this Pip'));
        await tester.pumpAndSettle();
        expect(c.collection.activePip, 'og');
        expect(fake.writes.single, {'activePip': 'og'});
        c.syncUser('fictional-ordinary', 0);
        expect(c.collection.activePip, 'classic');
      } else {
        expect(find.text('OG Pip'), findsNothing);
        await expectLater(c.select('og'), throwsStateError);
        expect(fake.writes, isEmpty);
      }
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });
  }
}
