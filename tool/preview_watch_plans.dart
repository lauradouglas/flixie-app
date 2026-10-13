// Fictional, in-memory preview. Never build this target for distribution.
// flutter run -t tool/preview_watch_plans.dart -d <dedicated-simulator>
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/features/social/presentation/pages/watch_requests_screen.dart';
import '../patrol_test/support/store_screenshot_fixture.dart';
import '../patrol_test/support/watch_plan_fixture.dart';
import '../patrol_test/support/group_watch_plan_fixture.dart';

class WatchPlansPreview {
  final friends = [
    WatchPlanFixture(status: 'ACCEPTED', scheduled: true),
    WatchPlanFixture(status: 'ACCEPTED', scheduled: true),
    WatchPlanFixture(),
    WatchPlanFixture(status: 'ACCEPTED'),
  ];
  final groups = [
    GroupWatchPlanFixture()..schedule(),
    GroupWatchPlanFixture()..schedule(dateOnly: true),
    GroupWatchPlanFixture(multiple: true),
  ];
  WatchPlansPreview() {
    final movies = [
      screenshotMovies[1],
      screenshotMovies[2],
      screenshotMovies[0],
      screenshotMovies[3]
    ];
    for (var i = 0; i < friends.length; i++) {
      final plan = friends[i].plan;
      plan['id'] = 'demo-friend-$i';
      plan['movie'] = movies[i];
      plan['movieId'] = movies[i]['id'];
      (plan['candidates'] as List).first['movieId'] = movies[i]['id'];
      (plan['candidates'] as List).first['movie'] = movies[i];
      if (i < 2) {
        plan['scheduledFor'] =
            DateTime.now().add(Duration(days: i + 2)).toUtc().toIso8601String();
        plan['scheduledDateOnly'] = i == 0;
        plan['location'] = i == 0 ? 'Cinema night' : 'At home';
      }
    }
    for (var i = 0; i < groups.length; i++) {
      groups[i].plan['id'] = 'demo-group-$i';
      if (i < 2) {
        groups[i].plan['scheduledFor'] =
            DateTime.now().add(Duration(days: i + 3)).toUtc().toIso8601String();
      }
    }
  }
  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    if (request.method == 'GET' && path == '/requests/store-viewer/all') {
      return friends.first.json(friends.map((f) => f.plan).toList());
    }
    if (request.method == 'GET' && path == '/groups/fixture-group/requests') {
      return groups.first.json(groups.map((g) => g.plan).toList());
    }
    final body = request.body.isEmpty ? null : jsonDecode(request.body);
    final fixture = [...friends, ...groups]
        .where((f) =>
            path.contains(f.plan['id'] as String) ||
            (body is Map && body['id'] == f.plan['id']))
        .firstOrNull;
    if (fixture != null) {
      final id = fixture.plan['id'] as String;
      final forwarded = http.Request(request.method,
          request.url.replace(path: path.replaceAll(id, 'patrol-plan')))
        ..headers.addAll(request.headers)
        ..body = request.body;
      return fixture.handle(forwarded);
    }
    return path.startsWith('/groups/')
        ? groups.first.handle(request)
        : friends.first.handle(request);
  }
}

void main() {
  if (!kDebugMode) throw StateError('The Watch Plans preview is debug-only.');
  WidgetsFlutterBinding.ensureInitialized();
  // Keep native simulator accessibility available for preview navigation.
  WidgetsBinding.instance.ensureSemantics();
  final fixture = WatchPlansPreview();
  // Dedicated debug sandbox deliberately uses the isolated test transport.
  // ignore: invalid_use_of_visible_for_testing_member
  ApiClient.useClientForTesting(MockClient(fixture.handle));
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const WatchRequestsScreen()),
    GoRoute(
        path: '/watch-requests/:id',
        builder: (_, state) =>
            WatchRequestsScreen(initialRequestId: state.pathParameters['id'])),
  ]);
  runApp(storeScreenshotApp(StoreScreenshotAuth(), router));
}
