import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/social/data/genre_community_service.dart';
import 'package:flixie_app/features/social/presentation/widgets/community_identity.dart';
import '../../support/api_fixture.dart';

void main() {
  test(
      'directory requests topics and each community joins and filters its own feed',
      () async {
    const topics = {
      -2: 'superheroes',
      -3: 'true-crime',
      -4: 'k-drama',
      -5: 'star-wars',
      -6: 'studio-ghibli',
      -7: 'cult-classics',
    };
    useApiFixture(MockClient((request) async {
      Map<String, dynamic> response;
      if (request.url.path == '/community/genres') {
        expect(request.url.queryParameters, {'includeTopics': 'true'});
        response = {
          'items': [
            for (final id in topics.keys)
              {'id': id, 'name': topics[id], 'joined': false}
          ]
        };
      } else if (request.method == 'PUT') {
        expect(jsonDecode(request.body), {'joined': true});
        expect(request.url.path, startsWith('/community/topics/'));
        response = {'joined': true};
      } else {
        expect(
            request.url.queryParameters, {'sort': 'latest', 'filter': 'show'});
        final slug = request.url.path.split('/')[3];
        final id =
            topics.entries.singleWhere((entry) => entry.value == slug).key;
        response = {
          'community': {'id': id, 'name': slug, 'joined': true},
          'items': [],
          'ratings': [
            {'movieId': 1, 'average': 8.0, 'count': 2},
            {'showId': 1, 'average': 10.0, 'count': 1},
          ]
        };
      }
      return http.Response(jsonEncode(response), 200,
          headers: {'content-type': 'application/json'});
    }));
    const service = GenreCommunityService();
    final directory = await service.list();
    expect(directory.map((item) => item.id), topics.keys);
    for (final id in topics.keys) {
      await service.setJoined(id, true);
      final page = await service.feed(id, filter: 'show');
      expect(page.community.id, id);
      expect(page.community.joined, true);
      expect(page.showRatings[1]!.average, 10);
      expect(page.ratings[1]!.average, 8);
    }
  });
  for (final scenario in [
    (const Size(320, 700), 2.0),
    (const Size(900, 500), 1.0),
    (const Size(768, 1024), 1.5)
  ]) {
    testWidgets('long superhero community header reflows at $scenario',
        (tester) async {
      tester.view.physicalSize = scenario.$1;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: MediaQueryData(
                size: scenario.$1, textScaler: TextScaler.linear(scenario.$2)),
            child: const Scaffold(
                body: SingleChildScrollView(
                    child: CommunityIdentityHeader(
                        id: -2, name: 'Superheroes / Marvel & DC'))),
          )));
      await tester.pumpAndSettle();
      expect(find.text('Superheroes / Marvel & DC'), findsOneWidget);
      expect(find.text('Films & series · Opinions from people who joined'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
