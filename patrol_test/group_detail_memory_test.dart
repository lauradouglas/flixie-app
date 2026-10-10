// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';
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
import 'package:flixie_app/features/social/data/watch_request_cache.dart';
import 'package:flixie_app/features/social/presentation/pages/group_detail_screen.dart';
import 'package:flixie_app/features/social/presentation/widgets/chat_tab.dart';
import '../test/support/api_fixture.dart';
import '../test/support/watchlist_auth.dart';
import '../test/features/social/group_chat/fixture.dart';
import 'support/runtime_database_fixture.dart';
import 'support/group_detail_before.dart';

class _GroupMemoryAuth extends TestAuth {
  _GroupMemoryAuth(this.user);
  final User user;
  @override
  User get dbUser => user;
}

class _RealHttp extends HttpOverrides {}

/// Real local reads, image-free control, and one explicitly substituted write.
class _ControlClient extends http.BaseClient {
  _ControlClient(this.database);
  final RuntimeDatabaseClient database;
  int conversationAttempts = 0;
  dynamic strip(dynamic value) {
    if (value is List) return value.map(strip).toList();
    if (value is! Map<String, dynamic>) return value;
    return {
      for (final e in value.entries)
        e.key: (e.key.toLowerCase().contains('poster') ||
                e.key == 'avatar' ||
                e.key == 'avatarUrl' ||
                e.key == 'backdropPath')
            ? null
            : strip(e.value)
    };
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method == 'POST' &&
        request.url.path == '/conversations/group') {
      conversationAttempts++;
      return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({
            'id': 'memory-conversation',
            'type': 'group',
            'memberIds': ['runtime-fixture-0'],
          }))),
          200,
          headers: {'content-type': 'application/json'});
    }
    final response =
        await http.Response.fromStream(await database.send(request));
    return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(strip(jsonDecode(response.body))))),
        response.statusCode,
        headers: {'content-type': 'application/json'},
        request: request);
  }
}

void main() {
  patrolTest('populated group detail paired memory and chat disposal',
      ($) async {
    SharedPreferences.setMockInitialValues({});
    final requests = <String, int>{};
    var active = 0;
    final database = RuntimeDatabaseClient(
        onStart: (key) {
          requests.update(key, (n) => n + 1, ifAbsent: () => 1);
          active++;
        },
        onEnd: () => active--);
    addTearDown(database.close);
    final client = _ControlClient(database);
    useApiFixture(client);
    final manifest = await database.load('/benchmark/manifest');
    expect(manifest['database'], 'flixie_runtime_fixture');
    expect(manifest['watchPlans']['groups'], 4);
    final viewer = manifest['smallViewer'] as String;
    ApiClient.setToken(viewer);
    final auth = _GroupMemoryAuth(
        User.fromJson(await database.load('/benchmark/users/$viewer')));
    final cache = WatchRequestCache();
    addTearDown(auth.dispose);
    addTearDown(cache.dispose);
    ChatFixture? chat;
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(
              body: Center(child: TextField(key: ValueKey('neutral-input'))))),
      GoRoute(
          path: '/before',
          builder: (_, __) =>
              const BeforeGroupDetailScreen(groupId: 'runtime-plan-group-0')),
      GoRoute(
          path: '/after',
          builder: (_, __) =>
              const GroupDetailScreen(groupId: 'runtime-plan-group-0')),
      GoRoute(
          path: '/chat',
          builder: (_, __) =>
              Scaffold(body: GroupChatTab(groupId: 'club', service: chat!))),
    ]);
    addTearDown(router.dispose);
    await $.pumpWidgetAndSettle(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<WatchRequestCache>.value(value: cache),
        ],
        child: MaterialApp.router(
            theme: AppTheme.darkTheme, routerConfig: router)));
    final rpc = IOClient(
        HttpOverrides.runWithHttpOverrides(() => HttpClient(), _RealHttp()));
    addTearDown(rpc.close);
    final vm = (await developer.Service.getInfo()).serverUri!;
    final isolate = developer.Service.getIsolateId(Isolate.current)!;
    Future<Map<String, dynamic>> call(
        String method, Map<String, String> args) async {
      final r = await rpc.get(vm
          .resolve(method)
          .replace(queryParameters: {'isolateId': isolate, ...args}));
      expect(r.statusCode, 200);
      final d = jsonDecode(r.body) as Map<String, dynamic>;
      expect(d['error'], isNull);
      return Map<String, dynamic>.from(d['result']);
    }

    const owners = {
      '_BeforeGroupDetailScreenState',
      '_GroupDetailScreenState',
      'GroupDetailController',
      'GroupActivityTabState',
      'GroupChatSession',
      'GroupChatTabState'
    };
    final observations = <Map<String, Object?>>[];
    final visits = <Map<String, Object?>>[];
    Future<void> profile(String phase, String version, int repetition) async {
      final allocation = await call('getAllocationProfile', {'gc': 'true'});
      final counts = <String, int>{};
      final paths = <Map<String, Object?>>[];
      for (final member in allocation['members'] as List) {
        final name = member['class']['name'] as String;
        if (!owners.contains(name)) continue;
        final instances = await call(
            'getInstances', {'objectId': member['class']['id'], 'limit': '2'});
        counts[name] = instances['totalCount'] as int;
        if (phase == 'mounted' || phase == 'baseline') continue;
        for (final instance in instances['instances'] as List) {
          final path = await call(
              'getRetainingPath', {'targetId': instance['id'], 'limit': '100'});
          paths.add({'owner': name, 'path': path});
        }
      }
      expect(counts.keys.toSet(), owners);
      observations.add({
        'phase': phase,
        'version': version,
        'repetition': repetition,
        'rss_bytes': ProcessInfo.currentRss,
        'memory_usage': allocation['memoryUsage'],
        'date_last_gc': allocation['dateLastServiceGC'],
        'live_counts': counts,
        'retaining_paths': paths,
        'image_cache_bytes':
            PaintingBinding.instance.imageCache.currentSizeBytes
      });
    }

    Future<void> settle() async {
      await $.pumpAndSettle();
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (active > 0) {
        if (DateTime.now().isAfter(deadline)) fail('HTTP did not settle');
        await $.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await $.pumpAndSettle();
      expect($.tester.takeException(), isNull);
    }

    Future<void> neutralInput() async {
      await $.tester.tap(find.byKey(const ValueKey('neutral-input')));
      await $.tester
          .enterText(find.byKey(const ValueKey('neutral-input')), 'neutral');
      FocusManager.instance.primaryFocus?.unfocus();
      await settle();
    }

    Future<void> leave() async {
      router.go('/');
      await settle();
      if (chat != null) {
        expect(chat!.subscriptions, chat!.cancellations);
        chat!.close();
        chat = null;
      }
    }

    Future<int> enter(String version) async {
      if (version == 'chat') chat = ChatFixture();
      final watch = Stopwatch()..start();
      router.go('/$version');
      if (version == 'chat') {
        await $(find.byType(TextField)).waitUntilVisible();
      } else {
        await $(find.text('Runtime film club 1')).waitUntilVisible();
      }
      await settle();
      final settled = watch.elapsedMicroseconds;
      if (version != 'chat') {
        await $.tester.tap(find.text('Insights'));
        await settle();
        await $.tester.tap(find.text('Activity'));
        await settle();
      }
      return settled;
    }

    for (final version in ['before', 'after', 'chat']) {
      await enter(version);
      await leave();
      await neutralInput();
    }
    Future<void> save(bool complete) async {
      final r = await database.post(
          Uri.parse('${ApiClient.baseUrl}/benchmark/results'),
          headers: {
            'authorization': 'Bearer $viewer',
            'content-type': 'application/json'
          },
          body: jsonEncode({
            'complete': complete,
            'method': {
              'suite': 'group_detail_memory',
              'database': manifest,
              'capture_id':
                  const String.fromEnvironment('GROUP_MEMORY_CAPTURE'),
              'mode': 'debug simulator',
              'images': 'image-free API control',
              'substitutions':
                  'Only parent conversation creation replaced; chat uses 50-message stream fixture; group reads use real local database',
              'warmup_visits': 3
            },
            'samples': visits,
            'memory_samples': observations
          }));
      expect(r.statusCode, 200);
    }

    for (var repetition = 1; repetition <= 5; repetition++) {
      final versions = repetition.isOdd
          ? ['before', 'after', 'chat']
          : ['after', 'before', 'chat'];
      for (final version in versions) {
        await neutralInput();
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        await settle();
        await profile('baseline', version, repetition);
        requests.clear();
        database.responses.clear();
        database.transportErrors.clear();
        client.conversationAttempts = 0;
        final elapsed = await enter(version);
        final reads = Map<String, int>.from(requests);
        final responses = {
          for (final e in database.responses.entries)
            e.key: Map<String, int>.from(e.value)
        };
        expect(database.transportErrors, isEmpty);
        for (final statuses in responses.values) {
          expect(statuses.keys.every((s) => s == '200'), true);
        }
        expect(client.conversationAttempts, version == 'before' ? 1 : 0);
        final subscriptions = chat?.subscriptions ?? 0;
        if (version == 'chat') expect(subscriptions, 1);
        await profile('mounted', version, repetition);
        await leave();
        await profile('unmounted', version, repetition);
        await neutralInput();
        await profile('neutral_input', version, repetition);
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        await settle();
        await profile('cache_cleared', version, repetition);
        visits.add({
          'version': version,
          'repetition': repetition,
          'settled_load_us': elapsed,
          'requests': reads,
          'responses': responses,
          'conversation_attempts': client.conversationAttempts,
          'chat_subscriptions': subscriptions,
          'chat_cancelled_on_exit': true
        });
        await save(false);
      }
    }
    expect(visits, hasLength(15));
    expect(observations, hasLength(75));
    await save(true);
  });
}
