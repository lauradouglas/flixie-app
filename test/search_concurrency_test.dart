import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/features/movies/data/search_service.dart';
import 'package:flixie_app/models/search_result.dart';

http.Response response(Object data, [int status = 200]) =>
    http.Response(jsonEncode(data), status,
        headers: {'content-type': 'application/json'});
void main() {
  testWidgets('All makes one multi-search and keeps mixed results and totals',
      (tester) async {
    final calls = <Uri>[];
    SearchResults? result;
    await http.runWithClient(() async {
      final future = SearchService.search('mixed', page: 3);
      future.then((value) => result = value);
      await tester.pump();
      expect(calls.length, 1);
      expect(calls.single.queryParameters,
          {'value': 'mixed', 'type': 'all', 'page': '3'});
      await tester.pump(const Duration(milliseconds: 299));
      expect(result, isNull);
      await tester.pump(const Duration(milliseconds: 1));
      await future;
      expect(calls.length, 1);
      expect(
          result!.results.map(
              (item) => item.movie?.id ?? item.show?.id ?? item.person?.id),
          [1, 2, 3]);
      expect(result!.page, 3);
      expect(result!.totalPages, 15);
      expect(result!.totalResults, 400);
    },
        () => MockClient((request) async {
              calls.add(request.url);
              await Future<void>.delayed(const Duration(milliseconds: 300));
              return response({
                'page': 3,
                'totalPages': 15,
                'totalResults': 400,
                'results': [
                  {'id': 1, 'media_type': 'movie', 'title': 'Film'},
                  {'id': 2, 'media_type': 'tv', 'name': 'Show'},
                  {'id': 3, 'media_type': 'person', 'name': 'Person'},
                ]
              });
            }));
  });
  testWidgets('empty All results do not trigger a supplemental search',
      (tester) async {
    var calls = 0;
    await http.runWithClient(() async {
      final result = await SearchService.search('empty');
      expect(result.results, isEmpty);
      expect(calls, 1);
    },
        () => MockClient((request) async {
              calls++;
              return response({'results': [], 'totalResults': 0});
            }));
  });
  testWidgets('multi failure propagates without a second request',
      (tester) async {
    var calls = 0;
    await http.runWithClient(() async {
      await expectLater(SearchService.search('failed'), throwsException);
      expect(calls, 1);
    },
        () => MockClient((request) async {
              calls++;
              return response({'error': 'fixture'}, 500);
            }));
  });
  testWidgets(
      'TV filter and standalone show search retain dedicated TV requests',
      (tester) async {
    final calls = <Uri>[];
    await http.runWithClient(() async {
      await SearchService.search('filter', type: 'tv', page: 2);
      final shows = await SearchService.searchShows('standalone');
      expect(shows.single.id, 42);
      expect(calls.map((url) => url.queryParameters['type']), ['tv', 'tv']);
      expect(calls.map((url) => url.queryParameters['page']), ['2', '1']);
    },
        () => MockClient((request) async {
              calls.add(request.url);
              return response({
                'results': [
                  {'id': 42, 'media_type': 'tv', 'name': 'Show'}
                ]
              });
            }));
  });
}
