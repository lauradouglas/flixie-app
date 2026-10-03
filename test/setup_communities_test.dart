import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/features/authentication/data/setup_service.dart';
import 'package:flixie_app/features/social/data/genre_community_service.dart';
import 'setup_flow_test.dart' show SetupFixture, setupApp;
import 'support/api_fixture.dart';

class CommunitySetupFixture extends SetupFixture {
  CommunitySetupFixture() {
    browseTitles = [const SetupTitle(348, 'Alien', null)];
  }
  final joins = <int>[];
  final joined = <int>{};
  int? failJoin;
  bool failLoad = false, failMetadata = false;
  Completer<List<GenreCommunity>>? pending;
  @override
  Future<List<GenreCommunity>> communities() async {
    if (pending != null) return pending!.future;
    if (failLoad) throw Exception('offline');
    return [
      for (final e in {
        27: 'Horror',
        878: 'Science Fiction',
        35: 'Comedy',
        -1: 'Anime'
      }.entries)
        GenreCommunity(id: e.key, name: e.value, joined: joined.contains(e.key))
    ];
  }

  @override
  Future<Set<int>> titleCommunityGenres(
      SetupTitle title, List<GenreCommunity> available) async {
    if (failMetadata) throw Exception('metadata unavailable');
    return title.isShow ? {35} : {27, 878};
  }

  @override
  Future<void> joinCommunity(int id) async {
    joins.add(id);
    if (failJoin == id) throw Exception('offline');
    joined.add(id);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    await (FontLoader('Manrope')
          ..addFont(
              rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  Future<void> tap(WidgetTester tester, String label) async {
    final finder = find.text(label).last;
    await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, CommunitySetupFixture fixture,
      {double scale = 1}) async {
    await tester.pumpWidget(setupApp(fixture, scale: scale));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('taste-movie:348')));
    await tester.tap(find.byKey(const ValueKey('taste-movie:348')));
    await tester.pumpAndSettle();
    await tap(tester, 'Continue');
    await tap(tester, 'Skip services for now');
    await tap(tester, 'Continue to favourites');
    await tap(tester, 'Continue to sharing');
    await tap(tester, 'Find my kind of people');
  }

  test(
      'suggestions use actual title genres and explicit genre choices, not Anime assumptions',
      () async {
    final fixture = CommunitySetupFixture();
    final results = await fixture
        .communitySuggestions([const SetupTitle(348, 'Alien', null)], {35});
    expect(results.where((r) => r.suggested).map((r) => r.community.id),
        [35, 27, 878]);
    expect(results.first.reason, 'Matches a genre you chose');
    expect(results.firstWhere((r) => r.community.id == 27).reason,
        'Because you chose Alien');
    expect(results.firstWhere((r) => r.community.id == -1).suggested, false);
    expect(fixture.joins, isEmpty);
  });
  test('missing metadata permits browsing without invented suggestions',
      () async {
    final fixture = CommunitySetupFixture()..failMetadata = true;
    final results = await fixture
        .communitySuggestions([const SetupTitle(348, 'Alien', null)], {});
    expect(results.length, 4);
    expect(results.where((r) => r.suggested), isEmpty);
  });
  test(
      'membership request only joins the chosen community and does not enable sharing',
      () async {
    final calls = <String>[];
    useApiFixture(MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      expect(jsonDecode(request.body), {'joined': true});
      return http.Response('{}', 200,
          headers: {'content-type': 'application/json'});
    }));
    await const SetupService().joinCommunity(27);
    await const SetupService().joinCommunity(-1);
    expect(calls, [
      'PUT /community/genres/27/membership',
      'PUT /community/topics/anime/membership'
    ]);
  });
  testWidgets(
      'suggestions start unchecked and skip discards unsaved selections',
      (tester) async {
    final fixture = CommunitySetupFixture();
    await open(tester, fixture);
    expect(find.text('Because you chose Alien'), findsNWidgets(2));
    expect(
        tester
            .widget<CheckboxListTile>(
                find.widgetWithText(CheckboxListTile, 'Horror'))
            .value,
        false);
    await tap(tester, 'Horror');
    expect(fixture.joins, isEmpty);
    await tap(tester, 'I’ll explore on my own');
    expect(find.text('Home destination'), findsOneWidget);
    expect(fixture.joins, isEmpty);
  });
  testWidgets('explicit join persists and exposes community destination',
      (tester) async {
    final fixture = CommunitySetupFixture();
    await open(tester, fixture);
    await tap(tester, 'Horror');
    await tap(tester, 'Science Fiction');
    await tap(tester, 'Join 2 & explore');
    expect(fixture.joins, [27, 878]);
    expect(find.text('Communities destination'), findsOneWidget);
    // Re-entering setup must preserve membership and disable accidental leaving.
    await tester.pumpWidget(const SizedBox());
    await open(tester, fixture);
    await tap(tester, 'Browse communities');
    expect(find.text('Already joined'), findsNWidgets(2));
    expect(
        tester
            .widget<CheckboxListTile>(
                find.widgetWithText(CheckboxListTile, 'Horror'))
            .onChanged,
        isNull);
  });
  testWidgets('partial failure retries only remaining selected communities',
      (tester) async {
    final fixture = CommunitySetupFixture()..failJoin = 878;
    await open(tester, fixture);
    await tap(tester, 'Horror');
    await tap(tester, 'Science Fiction');
    await tap(tester, 'Join 2 & explore');
    expect(fixture.joined, {27});
    expect(
        find.textContaining('Your successful joins are saved'), findsOneWidget);
    fixture.failJoin = null;
    await tap(tester, 'Join 1 & explore');
    expect(fixture.joins, [27, 878, 878]);
    expect(fixture.joined, {27, 878});
  });
  testWidgets('community failure retries and never blocks skip',
      (tester) async {
    final fixture = CommunitySetupFixture()..failLoad = true;
    await open(tester, fixture);
    expect(find.textContaining('Couldn’t load communities'), findsOneWidget);
    fixture.failLoad = false;
    await tap(tester, 'Retry communities');
    expect(find.text('Horror'), findsOneWidget);
    await tap(tester, 'I’ll explore on my own');
    expect(find.text('Home destination'), findsOneWidget);
  });
  testWidgets('skipping while community loading is pending tolerates disposal',
      (tester) async {
    final fixture = CommunitySetupFixture()
      ..pending = Completer<List<GenreCommunity>>();
    await tester.pumpWidget(setupApp(fixture));
    await tester.pumpAndSettle();
    await tap(tester, 'Skip taste picks');
    await tap(tester, 'Skip services for now');
    await tap(tester, 'Continue to favourites');
    await tap(tester, 'Continue to sharing');
    await tester.tap(find.text('Find my kind of people'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('I’ll explore on my own'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    fixture.pending!.complete([]);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(fixture.joins, isEmpty);
  });
  for (final size in [
    const Size(320, 640),
    const Size(430, 932),
    const Size(844, 390),
    const Size(1024, 768)
  ]) {
    testWidgets('community setup fits $size with doubled text', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = CommunitySetupFixture();
      await open(tester, fixture, scale: 2);
      if (const bool.fromEnvironment('SETUP_CAPTURE')) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byType(RepaintBoundary).first);
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('/tmp/flixie-setup-community-${size.width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tap(tester, 'Horror');
      await tap(tester, 'Join 1 & explore');
      expect(fixture.joined, {27});
      expect(tester.takeException(), isNull);
    });
  }
}
