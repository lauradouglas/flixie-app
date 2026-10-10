import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/movies/presentation/controllers/search_controller.dart';
import 'package:flixie_app/features/movies/presentation/widgets/search/search_mode.dart';
import 'package:flixie_app/features/movies/data/search_history_store.dart';
import 'package:flixie_app/models/search_result.dart';
import 'package:flixie_app/models/movie_short.dart';

class History extends SearchHistoryStore {
  Future<List<String>> initial = Future.value([]);
  final writes = <List<String>>[];
  @override
  Future<List<String>> read() => initial;
  @override
  Future<void> write(List<String> values) async => writes.add(List.of(values));
}

SearchResults results(String title, {int page = 1}) => SearchResults.fromJson({
      'page': page,
      'totalPages': 2,
      'totalResults': 2,
      'results': [
        {'id': page, 'title': title, 'media_type': 'movie'}
      ],
    });
SearchScreenController create(
        {SearchMedia? search,
        History? history,
        LoadSearchTrending? trending}) =>
    SearchScreenController(
        search: search ??
            (query, {type = 'all', page = 1}) async =>
                results(query, page: page),
        history: history ?? History(),
        trending: trending ?? ({refresh = false}) async => []);
void main() {
  testWidgets('typing debounces, submission cancels timer and keeps one read',
      (tester) async {
    final calls = <String>[];
    final c = create(search: (q, {type = 'all', page = 1}) async {
      calls.add(q);
      return results(q);
    });
    addTearDown(c.dispose);
    c.changeQuery('al');
    await tester.pump(const Duration(milliseconds: 399));
    expect(calls, isEmpty);
    c.changeQuery('Alien');
    await tester.pump(const Duration(milliseconds: 399));
    expect(calls, isEmpty);
    await c.submit('Alien');
    await tester.pump(const Duration(milliseconds: 500));
    expect(calls, ['Alien']);
    expect(c.results!.results.single.movie!.name, 'Alien');
  });
  testWidgets('mode change and clearing reject stale responses',
      (tester) async {
    final old = Completer<SearchResults>();
    final c = create(
        search: (q, {type = 'all', page = 1}) =>
            type == 'all' ? old.future : Future.value(results('Show')));
    addTearDown(c.dispose);
    final first = c.submit('Alien');
    await c.setMode(SearchMode.shows);
    old.complete(results('Old'));
    await first;
    expect(c.results!.results.single.movie!.name, 'Show');
    c.changeQuery('');
    expect(c.results, isNull);
    expect(c.isSearching, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(c.results, isNull);
  });
  testWidgets('one pending page append, refresh rejects old paging completion',
      (tester) async {
    final next = Completer<SearchResults>();
    final pages = <int>[];
    final c = create(search: (q, {type = 'all', page = 1}) {
      pages.add(page);
      return page == 2 ? next.future : Future.value(results('First'));
    });
    addTearDown(c.dispose);
    await c.submit('Alien');
    final a = c.loadMore(), b = c.loadMore();
    expect(identical(a, b), isTrue);
    expect(pages, [1, 2]);
    await c.refresh();
    next.complete(results('Late', page: 2));
    await a;
    expect(c.results!.results.map((r) => r.movie!.name), ['First']);
    expect(pages, [1, 2, 1]);
  });
  testWidgets('paging waits for an active refresh instead of invalidating it',
      (tester) async {
    var calls = 0;
    final gate = Completer<SearchResults>();
    final c = create(
        search: (q, {type = 'all', page = 1}) =>
            calls++ == 0 ? Future.value(results('First')) : gate.future);
    addTearDown(c.dispose);
    await c.submit('Alien');
    final refresh = c.refresh();
    final more = c.loadMore();
    expect(identical(refresh, more), isTrue);
    expect(calls, 2);
    gate.complete(results('Refreshed'));
    await refresh;
    expect(c.results!.results.single.movie!.name, 'Refreshed');
  });
  testWidgets('paging retry appends exactly once and stops at last page',
      (tester) async {
    var fail = true;
    final pages = <int>[];
    final c = create(search: (q, {type = 'all', page = 1}) async {
      pages.add(page);
      if (page == 2 && fail) throw StateError('offline');
      return results('Page $page', page: page);
    });
    addTearDown(c.dispose);
    await c.submit('Alien');
    await c.loadMore();
    expect(c.searchFailed, isTrue);
    fail = false;
    await c.retry();
    await c.loadMore();
    expect(pages, [1, 2, 2]);
    expect(c.results!.results.map((r) => r.movie!.name), ['Page 1', 'Page 2']);
  });
  testWidgets(
      'failed refresh keeps results and retries page one instead of next page',
      (tester) async {
    var fail = false;
    final pages = <int>[];
    final c = create(search: (q, {type = 'all', page = 1}) async {
      pages.add(page);
      if (fail) throw StateError('offline');
      return results('Page $page', page: page);
    });
    addTearDown(c.dispose);
    await c.submit('Alien');
    await c.loadMore();
    fail = true;
    await c.refresh();
    expect(c.results!.results, hasLength(2));
    expect(c.failedRefresh, isTrue);
    fail = false;
    await c.retry();
    expect(pages, [1, 2, 1, 1]);
    expect(c.results!.results, hasLength(1));
  });
  testWidgets('same mode is idle and overlapping identical searches share work',
      (tester) async {
    final pending = Completer<SearchResults>();
    var calls = 0;
    final c = create(search: (q, {type = 'all', page = 1}) {
      calls++;
      return pending.future;
    });
    addTearDown(c.dispose);
    final first = c.submit('Alien');
    final second = c.submit('Alien');
    expect(identical(first, second), isTrue);
    await c.setMode(SearchMode.all);
    expect(calls, 1);
    pending.complete(results('Alien'));
    await first;
  });
  testWidgets('new trending refresh rejects older load failure',
      (tester) async {
    final old = Completer<List<MovieShort>>();
    var calls = 0;
    final c = create(
        trending: ({refresh = false}) => calls++ == 0
            ? old.future
            : Future.value([const MovieShort(id: 1, name: 'Alien')]));
    addTearDown(c.dispose);
    await c.loadDefault(refresh: true);
    old.completeError(StateError('old'));
    await tester.pump();
    expect(c.trendingMovies.single.name, 'Alien');
    expect(c.defaultFailed, isFalse);
  });
  testWidgets('dispose cancels debounce and rejects late search and history',
      (tester) async {
    final pending = Completer<SearchResults>(),
        historyReady = Completer<List<String>>();
    var calls = 0, notifications = 0;
    final history = History()..initial = historyReady.future;
    final c = create(
        history: history,
        search: (q, {type = 'all', page = 1}) {
          calls++;
          return pending.future;
        });
    c.addListener(() => notifications++);
    final read = c.submit('Alien');
    c.changeQuery('Other');
    c.dispose();
    final prior = notifications;
    pending.complete(results('Late'));
    historyReady.complete(['Old']);
    await read;
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 1);
    expect(notifications, prior);
    expect(history.writes, isEmpty);
    expect(c.results, isNull);
  });
  testWidgets(
      'history waits for loading, trims, deduplicates and supports removal',
      (tester) async {
    final ready = Completer<List<String>>();
    final history = History()..initial = ready.future;
    final c = create(history: history);
    addTearDown(c.dispose);
    final save = c.saveHistory(' alien ');
    ready.complete(['Alien', 'Dune', 'Up', 'Jaws', 'The Odyssey']);
    await save;
    expect(c.recentSearches, ['alien', 'Dune', 'Up', 'Jaws', 'The Odyssey']);
    await c.saveHistory('Obsession');
    expect(c.recentSearches, ['Obsession', 'alien', 'Dune', 'Up', 'Jaws']);
    await c.removeHistory('Dune');
    expect(c.recentSearches, isNot(contains('Dune')));
    await c.removeHistory();
    expect(history.writes.last, isEmpty);
  });
  testWidgets('history storage failure does not block searching',
      (tester) async {
    final ready = Completer<List<String>>();
    final c = create(history: History()..initial = ready.future);
    addTearDown(c.dispose);
    ready.completeError(StateError('storage'));
    await c.submit('Alien');
    expect(c.results!.results.single.movie!.name, 'Alien');
  });
  testWidgets('synchronous loader failure remains retryable', (tester) async {
    var calls = 0;
    final c = create(search: (q, {type = 'all', page = 1}) {
      if (calls++ == 0) throw StateError('sync');
      return Future.value(results('Recovered'));
    });
    addTearDown(c.dispose);
    await c.submit('Alien');
    expect(c.searchFailed, isTrue);
    await c.retry();
    expect(c.results!.results.single.movie!.name, 'Recovered');
  });
}
