import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:flixie_app/features/movies/presentation/controllers/movie_lists_controller.dart';
import '../../../../patrol_test/support/movie_list_detail_fixture.dart';
import '../../../support/api_fixture.dart';

void main() {
  test('a read started before confirmed removal cannot resurrect its item',
      () async {
    final api = MovieListDetailFixture();
    final gate = Completer<http.Response>();
    useApiFixture(MockClient(
        (r) async => r.method == 'GET' ? gate.future : api.handle(r)));
    final provider = MovieListsProvider(userId: 'list-owner');
    addTearDown(provider.dispose);
    final load = provider.loadListMovies('fixture-list');
    expect(await provider.removeMovieFromList('fixture-list', 1), isTrue);
    gate.complete(api.json([listEntry(1, 'Alien')]));
    await load;
    expect(provider.listMovies['fixture-list'], isEmpty);
    expect(provider.isLoading, isFalse);
  });
  test('dispose rejects an outstanding list read without notifying', () async {
    final api = MovieListDetailFixture();
    final gate = Completer<http.Response>();
    useApiFixture(MockClient((_) => gate.future));
    final provider = MovieListsProvider(userId: 'list-owner');
    var publications = 0;
    provider.addListener(() => publications++);
    final load = provider.loadListMovies('fixture-list');
    final before = publications;
    provider.dispose();
    gate.complete(api.json(api.entries));
    await load;
    expect(publications, before);
    expect(provider.listMovies, isEmpty);
  });
  test('failed removal preserves the existing list and allows retry', () async {
    final api = MovieListDetailFixture();
    useApiFixture(api.client);
    final provider = MovieListsProvider(userId: 'list-owner');
    addTearDown(provider.dispose);
    await provider.loadListMovies('fixture-list');
    api.failWrite = true;
    expect(await provider.removeMovieFromList('fixture-list', 1), isFalse);
    expect(provider.listMovies['fixture-list'], hasLength(3));
    api.failWrite = false;
    expect(await provider.removeMovieFromList('fixture-list', 1), isTrue);
    expect(provider.listMovies['fixture-list']!.where((e) => e.showId == 1),
        hasLength(1));
  });
}
