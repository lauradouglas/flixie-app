// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/features/movies/presentation/pages/person_detail_screen.dart';
import '../test/support/api_fixture.dart';
import '../test/support/watchlist_auth.dart';
import 'support/runtime_database_fixture.dart';
import 'support/person_detail_memory_before.dart';

class _MemoryAuth extends TestAuth {
  _MemoryAuth(this.user);
  final User user;
  @override
  User get dbUser => user;
}

class _RealHttp extends HttpOverrides {}

/// Only image fields change; populated API reads and credit/library data are real.
class _ImageControlClient extends http.BaseClient {
  _ImageControlClient(this.database);
  final RuntimeDatabaseClient database;
  bool images = true;
  static String poster(Map<String, dynamic> value) =>
      '/flixie-memory-${value['type']}-${value['id']}.png';
  dynamic transform(dynamic value) {
    if (value is List) return value.map(transform).toList();
    if (value is! Map<String, dynamic>) return value;
    return {
      for (final entry in value.entries)
        entry.key: switch (entry.key) {
          'images' => images ? transform(entry.value) : <dynamic>[],
          'posterPath' => !images || entry.value == null ? null : poster(value),
          'profileImgUrl' => !images || entry.value == null
              ? null
              : '/flixie-memory-portrait.png',
          'imageUrl' => images
              ? 'http://127.0.0.1:1/flixie-memory-photo-${value['imageUrl'].hashCode}.png'
              : '',
          _ => transform(entry.value),
        }
    };
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response =
        await http.Response.fromStream(await database.send(request));
    if (!request.url.path.startsWith('/people/') ||
        response.statusCode != 200) {
      return http.StreamedResponse(
          Stream.value(response.bodyBytes), response.statusCode,
          headers: response.headers, request: request);
    }
    final data = !images && request.url.path.endsWith('/images')
        ? <dynamic>[]
        : transform(jsonDecode(response.body));
    return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(data))), 200,
        headers: {'content-type': 'application/json'}, request: request);
  }
}

Future<Uint8List> _png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = const Color(0xff553399));
  canvas.drawRect(Rect.fromLTWH(0, height / 2, width.toDouble(), height / 2),
      Paint()..color = const Color(0xff112233));
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bytes!.buffer.asUint8List();
}

void main() {
  patrolTest('controlled populated person memory comparison', ($) async {
    SharedPreferences.setMockInitialValues({});
    final requests = <String, int>{};
    var active = 0;
    final database = RuntimeDatabaseClient(
        onStart: (key) {
          requests.update(key, (v) => v + 1, ifAbsent: () => 1);
          active++;
        },
        onEnd: () => active--);
    addTearDown(database.close);
    final client = _ImageControlClient(database);
    useApiFixture(client);
    final manifest = await database.load('/benchmark/manifest');
    expect(manifest['database'], 'flixie_runtime_fixture');
    expect(manifest['person']['id'], 990000001);
    final viewer = manifest['largeViewer'] as String;
    ApiClient.setToken(viewer);
    final auth = _MemoryAuth(
        User.fromJson(await database.load('/benchmark/users/$viewer')));
    expect(auth.dbUser.movieWatchlist, hasLength(400));
    addTearDown(auth.dispose);
    // Seed only the URLs this screen can render, with known dimensions/bytes.
    final creditsResponse = await client.get(
        Uri.parse('${ApiClient.baseUrl}/people/990000001/credits'),
        headers: {'authorization': 'Bearer $viewer'});
    expect(creditsResponse.statusCode, 200);
    final credits = jsonDecode(creditsResponse.body) as Map<String, dynamic>;
    final imagesResponse = await client.get(
        Uri.parse('${ApiClient.baseUrl}/people/990000001/images'),
        headers: {'authorization': 'Bearer $viewer'});
    expect(imagesResponse.statusCode, 200);
    final photos = jsonDecode(imagesResponse.body) as List;
    final urls = <String, int>{
      for (final item in [...credits['allCredits'], ...credits['crewCredits']])
        if (item['posterPath'] != null)
          'https://image.tmdb.org/t/p/w185${item['posterPath']}': 185,
      for (final item in credits['knownForCredits'])
        if (item['posterPath'] != null)
          'https://image.tmdb.org/t/p/w342${item['posterPath']}': 342,
      for (final item in photos) item['imageUrl'] as String: 500,
    };
    final cache = CachedNetworkImageProvider.defaultCacheManager;
    await cache.emptyCache();
    for (final width in [185, 342, 500]) {
      final png = await _png(width, (width * 1.5).round());
      for (final entry in urls.entries.where((e) => e.value == width)) {
        await cache.putFile(entry.key, png,
            eTag: 'flixie-memory-v1-$width',
            maxAge: const Duration(days: 30),
            fileExtension: 'png');
      }
    }
    for (final url in urls.keys) {
      expect(await cache.getFileFromCache(url), isNotNull,
          reason: 'Every image URL must have a deterministic disk fixture');
    }
    final router = GoRouter(initialLocation: '/', routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(
              body: Center(
                  child: Padding(
                      padding: EdgeInsets.all(24),
                      child: TextField(
                          key: ValueKey('memory-neutral-field'),
                          decoration: InputDecoration(
                              labelText: 'Memory neutral input')))))),
      GoRoute(
          path: '/before',
          builder: (_, __) =>
              const BeforePersonDetailScreen(personId: '990000001')),
      GoRoute(
          path: '/after',
          builder: (_, __) => const PersonDetailScreen(personId: '990000001')),
    ]);
    addTearDown(router.dispose);
    await $.pumpWidgetAndSettle(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp.router(
            theme: AppTheme.darkTheme, routerConfig: router)));
    final rpc = IOClient(
        HttpOverrides.runWithHttpOverrides(() => HttpClient(), _RealHttp()));
    addTearDown(rpc.close);
    final vm = (await developer.Service.getInfo()).serverUri!;
    final isolate = developer.Service.getIsolateId(Isolate.current)!;
    Future<Map<String, dynamic>> call(
        String method, Map<String, String> arguments) async {
      final response =
          await rpc.get(vm.resolve(method).replace(queryParameters: {
        'isolateId': isolate,
        ...arguments,
      }));
      expect(response.statusCode, 200);
      final envelope = jsonDecode(response.body) as Map<String, dynamic>;
      expect(envelope['error'], isNull);
      return Map<String, dynamic>.from(envelope['result'] ?? envelope);
    }

    final observations = <Map<String, Object?>>[];
    const owners = {
      '_MemoryBeforePersonDetailScreenState',
      '_MemoryBeforePersonPhotoViewerState',
      'PersonDetailController',
      '_PersonDetailScreenState',
      'PersonPhotoViewerState',
      '_PersonFilmographySectionState',
      '_PersonFilmographyControlsState',
      '_PersonBiographyState',
      'PersonFilmCredit',
      '_MemoryBeforePersonFilmCredit',
    };
    Future<void> profile(
        String phase, String version, String condition, int repetition) async {
      final beforeGc = ProcessInfo.currentRss;
      final allocation = await call('getAllocationProfile', {'gc': 'true'});
      expect(allocation['type'], 'AllocationProfile');
      final members = allocation['members'] as List;
      final paths = <Map<String, Object?>>[];
      final liveCounts = <String, int>{};
      // Allocation census and actual instance lookups are separate observations.
      // Query zero census entries too; do not infer reachability from counters.
      for (final member in members) {
        final name = member['class']['name'];
        if (!owners.contains(name)) {
          continue;
        }
        final instances = await call(
            'getInstances', {'objectId': member['class']['id'], 'limit': '2'});
        expect(instances['type'], 'InstanceSet');
        liveCounts[name as String] = instances['totalCount'] as int;
        if (!['unmounted', 'neutral_input', 'cache_cleared'].contains(phase) ||
            name.contains('FilmCredit') ||
            !{
              'PersonDetailController',
              '_PersonDetailScreenState',
              '_MemoryBeforePersonDetailScreenState',
              'PersonPhotoViewerState',
              '_MemoryBeforePersonPhotoViewerState'
            }.contains(name)) {
          continue;
        }
        for (final instance in instances['instances'] as List) {
          final path = await call('getRetainingPath',
              {'targetId': instance['id'], 'limit': '1000'});
          paths.add({
            'owner': name,
            'length': path['length'],
            'gcRootType': path['gcRootType'],
            'elements': [
              for (final element in path['elements'] as List? ?? [])
                {
                  'class': element['value']['class']?['name'],
                  'kind': element['value']['kind'],
                  'name': element['value']['name'],
                  'function': element['value']['closureFunction']?['name'],
                  'parentField': element['parentField'],
                  'parentListIndex': element['parentListIndex'],
                }
            ],
          });
        }
      }
      expect(liveCounts.keys.toSet(), owners,
          reason: 'Every owned class needs a direct instance count');
      final ranked = List<dynamic>.from(members)
        ..sort((a, b) =>
            (b['bytesCurrent'] as int).compareTo(a['bytesCurrent'] as int));
      final imageCache = PaintingBinding.instance.imageCache;
      observations.add({
        'phase': phase,
        'version': version,
        'condition': condition,
        'repetition': repetition,
        'rss_before_gc_bytes': beforeGc,
        'rss_after_gc_bytes': ProcessInfo.currentRss,
        'memory_usage': allocation['memoryUsage'],
        'date_last_gc': allocation['dateLastServiceGC'],
        'actual_live_counts': liveCounts,
        'image_cache_bytes': imageCache.currentSizeBytes,
        'image_cache_count': imageCache.currentSize,
        'image_cache_live': imageCache.liveImageCount,
        'image_cache_pending': imageCache.pendingImageCount,
        'owners': [
          for (final member in members)
            if (owners.contains(member['class']['name']))
              {
                'name': member['class']['name'],
                'instances': member['instancesCurrent'],
                'bytes': member['bytesCurrent'],
              }
        ],
        'largest_classes': [
          for (final member in ranked.take(20))
            {
              'name': member['class']['name'],
              'instances': member['instancesCurrent'],
              'bytes': member['bytesCurrent'],
            }
        ],
        'retaining_paths': paths,
      });
    }

    Future<void> settle() async {
      await $.pumpAndSettle();
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (active > 0 ||
          PaintingBinding.instance.imageCache.pendingImageCount > 0) {
        if (DateTime.now().isAfter(deadline)) {
          fail('Pending requests/images did not settle');
        }
        await $.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      await $.pumpAndSettle();
    }

    Future<void> replaceInput() async {
      final field = find.byKey(const ValueKey('memory-neutral-field'));
      await $.tester.tap(field);
      await $.tester.enterText(field, 'neutral');
      expect(
          $.tester
              .widget<EditableText>(find.byType(EditableText))
              .focusNode
              .hasFocus,
          isTrue,
          reason:
              'Neutral field must establish the replacement input connection');
      FocusManager.instance.primaryFocus?.unfocus();
      await settle();
    }

    Future<void> neutral() async {
      router.go('/');
      await settle();
      await replaceInput();
      await settle();
    }

    void clearImages() {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    }

    Future<void> journey(String version) async {
      router.go('/$version');
      await $('Casey Runtime').waitUntilVisible();
      await settle();
      await $.tester.ensureVisible(find.textContaining('View All').first);
      await settle();
      await $(find.textContaining('View All').first).tap();
      await $('All Credits').waitUntilVisible();
      final sheetScroll = find.byType(Scrollable).hitTestable().last;
      for (var i = 0; i < 3; i++) {
        await $.tester.fling(sheetScroll, const Offset(0, -400), 1200);
        await settle();
      }
      Navigator.of($.tester.element(find.text('All Credits')),
              rootNavigator: true)
          .pop();
      await settle();
      if (client.images) {
        await $.tester.ensureVisible(find.textContaining('See all').first);
        await settle();
        await $(find.textContaining('See all').first).tap();
        await settle();
        await $.tester.tap(find.byWidgetPredicate((w) =>
            w is Semantics && w.properties.label == 'Open photo 2 of 3'));
        await settle();
        expect(find.text('2 / 3'), findsOneWidget);
        await $.tester.drag(find.byType(PageView), const Offset(-350, 0));
        await settle();
        expect(find.text('3 / 3'), findsOneWidget);
        await $.tester
            .tap(find.byIcon(Icons.close_rounded).hitTestable().first);
        await settle();
        await $.tester.pageBack();
        await settle();
      }
      await $.tester.ensureVisible(find.byType(TextField));
      await settle();
      await $(find.byType(TextField)).enterText('Alien');
      FocusManager.instance.primaryFocus?.unfocus();
      await $.tester.ensureVisible(find.text('TV').first);
      await settle();
      await $(find.text('TV').first).tap();
      await settle();
    }

    // Compile/exercise both variants and both image paths before measured visits.
    for (final images in [false, true]) {
      client.images = images;
      for (final version in ['before', 'after']) {
        await neutral();
        clearImages();
        await journey(version);
        await neutral();
      }
    }
    final visits = <Map<String, Object?>>[];
    const reversed =
        String.fromEnvironment('PERSON_MEMORY_ORDER') == 'images_first';
    Future<void> save(bool complete) async {
      final result = await database.post(
          Uri.parse('${ApiClient.baseUrl}/benchmark/results'),
          headers: {
            'authorization': 'Bearer $viewer',
            'content-type': 'application/json'
          },
          body: jsonEncode({
            'complete': complete,
            'method': {
              'suite': 'person_memory',
              'order': reversed ? 'images_first' : 'no_images_first',
              'database': manifest,
              'image_urls_seeded': urls.length,
              'images':
                  'Deterministic cached PNG: 185x278, 342x513, 500x750; no external poster downloads',
              'warmup_visits': 4,
              'neutral_input':
                  'Unrelated TextField tap and text entry replaces pointer and TextInput._lastConnection',
              'variants':
                  'Archived before and current after in one debug process',
            },
            'samples': visits,
            'memory_samples': observations
          }));
      expect(result.statusCode, 200);
    }

    for (var repetition = 1; repetition <= 5; repetition++) {
      final conditions = reversed
          ? ['controlled_images', 'no_images']
          : ['no_images', 'controlled_images'];
      for (var conditionIndex = 0;
          conditionIndex < conditions.length;
          conditionIndex++) {
        final condition = conditions[conditionIndex];
        client.images = condition == 'controlled_images';
        final versions = (repetition + conditionIndex).isOdd
            ? ['before', 'after']
            : ['after', 'before'];
        for (final version in versions) {
          await neutral();
          clearImages();
          await settle();
          await profile('baseline', version, condition, repetition);
          requests.clear();
          database.responses.clear();
          database.transportErrors.clear();
          await journey(version);
          expect(active, 0);
          final budget = {
            for (final suffix in ['', '/credits', '/images'])
              'GET /people/990000001$suffix': 1
          };
          expect(requests, budget);
          expect(database.transportErrors, isEmpty);
          expect(database.responses, {
            for (final key in budget.keys) key: {'200': 1}
          });
          if (!client.images) {
            expect(PaintingBinding.instance.imageCache.currentSizeBytes, 0);
          }
          if (client.images) {
            expect(PaintingBinding.instance.imageCache.currentSizeBytes,
                greaterThan(0));
          }
          await profile('mounted', version, condition, repetition);
          router.go('/');
          await settle();
          await profile('unmounted', version, condition, repetition);
          await replaceInput();
          await settle();
          await profile('neutral_input', version, condition, repetition);
          clearImages();
          await settle();
          await profile('cache_cleared', version, condition, repetition);
          visits.add({
            'scenario': 'person_memory',
            'version': version,
            'condition': condition,
            'repetition': repetition,
            'requests': Map<String, int>.from(requests),
            'responses': {
              for (final entry in database.responses.entries)
                entry.key: Map<String, int>.from(entry.value)
            },
            'transport_errors':
                Map<String, List<String>>.from(database.transportErrors)
          });
          await save(false);
        }
      }
    }
    expect(visits, hasLength(20));
    expect(observations, hasLength(100));
    await save(true);
  });
}
