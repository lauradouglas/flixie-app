import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/models/search_result.dart';
import 'package:flixie_app/features/home/data/trending_service.dart';
import '../../data/search_service.dart';
import '../../data/search_history_store.dart';
import '../widgets/search/search_mode.dart';

typedef SearchMedia = Future<SearchResults> Function(String query,
    {String type, int page});
typedef SearchEntities = Future<SearchEntityResults> Function(String query,
    {int page});
typedef LoadSearchTrending = Future<List<MovieShort>> Function({bool refresh});

/// Query, debounce and request ownership for one mounted Search screen.
class SearchScreenController extends ChangeNotifier {
  SearchScreenController({
    List<MovieShort>? cachedTrending,
    SearchMedia? search,
    SearchEntities? collections,
    SearchEntities? companies,
    LoadSearchTrending? trending,
    SearchHistoryStore? history,
  })  : _search = search ?? SearchService.search,
        _collections = collections ?? SearchService.searchCollection,
        _companies = companies ?? SearchService.searchCompany,
        _trending = trending ?? _loadTrending,
        _history = history ?? SearchHistoryStore(),
        _trendingMovies = List.unmodifiable(cachedTrending ?? []) {
    _isLoadingDefault = _trendingMovies.isEmpty;
    _historyReady = _loadHistory();
    unawaited(loadDefault());
  }
  static Future<List<MovieShort>> _loadTrending({bool refresh = false}) =>
      TrendingService.getTrendingMovies(refresh: refresh);
  final SearchMedia _search;
  final SearchEntities _collections, _companies;
  final LoadSearchTrending _trending;
  final SearchHistoryStore _history;
  late final Future<void> _historyReady;
  Timer? _debounce;
  bool _disposed = false;
  int _generation = 0, _defaultGeneration = 0;
  Future<void>? _pending;
  String? _pendingKey;
  bool _failedLoadMore = false, _failedRefresh = false;

  String _query = '';
  SearchMode _mode = SearchMode.all;
  List<MovieShort> _trendingMovies;
  List<String> _recentSearches = const [];
  SearchResults? _results;
  SearchEntityResults? _entityResults;
  bool _isLoadingDefault = true, _defaultFailed = false;
  bool _isSearching = false, _loadingMore = false, _searchFailed = false;
  String get query => _query;
  SearchMode get mode => _mode;
  List<MovieShort> get trendingMovies => _trendingMovies;
  List<String> get recentSearches => _recentSearches;
  SearchResults? get results => _results;
  SearchEntityResults? get entityResults => _entityResults;
  bool get isLoadingDefault => _isLoadingDefault;
  bool get defaultFailed => _defaultFailed;
  bool get isSearching => _isSearching;
  bool get loadingMore => _loadingMore;
  bool get searchFailed => _searchFailed;
  bool get hasMore => _results != null && _results!.page < _results!.totalPages;
  bool get failedRefresh => _failedRefresh;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _loadHistory() async {
    try {
      final recent = await _history.read();
      if (!_disposed) {
        _recentSearches = List.unmodifiable(recent);
        _notify();
      }
    } catch (_) {
      /* History storage failure must not prevent catalogue search. */
    }
  }

  Future<void> saveHistory(String value) async {
    await _historyReady;
    if (_disposed || value.trim().isEmpty) return;
    final next = value.trim();
    _recentSearches = List.unmodifiable(
      [
        next,
        ..._recentSearches.where((q) => q.toLowerCase() != next.toLowerCase()),
      ].take(SearchHistoryStore.limit),
    );
    _notify();
    try {
      await _history.write(_recentSearches);
    } catch (_) {
      /* Keep this session usable. */
    }
  }

  Future<void> removeHistory([String? value]) async {
    await _historyReady;
    if (_disposed) return;
    _recentSearches = List.unmodifiable(
      value == null ? <String>[] : _recentSearches.where((q) => q != value),
    );
    _notify();
    try {
      await _history.write(_recentSearches);
    } catch (_) {
      /* Keep this session usable. */
    }
  }

  Future<void> loadDefault({bool refresh = false}) async {
    if (_disposed) return;
    final generation = ++_defaultGeneration;
    _defaultFailed = false;
    _isLoadingDefault = _trendingMovies.isEmpty;
    _notify();
    try {
      final value = await _trending(refresh: refresh);
      if (_disposed || generation != _defaultGeneration) return;
      _trendingMovies = List.unmodifiable(value);
    } catch (_) {
      if (_disposed || generation != _defaultGeneration) return;
      _defaultFailed = true;
    } finally {
      if (!_disposed && generation == _defaultGeneration) {
        _isLoadingDefault = false;
        _notify();
      }
    }
  }

  void changeQuery(String value) {
    if (_disposed) return;
    _resetRequest();
    _query = value;
    _isSearching = value.trim().isNotEmpty;
    _notify();
    if (_isSearching) {
      _debounce = Timer(
        const Duration(milliseconds: 400),
        () => unawaited(_perform()),
      );
    }
  }

  Future<void> submit(String value) {
    if (_disposed || value.trim().isEmpty) return Future.value();
    _debounce?.cancel();
    if (_query != value) _resetRequest();
    _query = value;
    unawaited(saveHistory(value));
    return _perform();
  }

  Future<void> setMode(SearchMode value) {
    if (_disposed || value == _mode) return Future.value();
    _resetRequest();
    _mode = value;
    _isSearching = _query.trim().isNotEmpty;
    _notify();
    return _isSearching ? _perform() : Future.value();
  }

  void _resetRequest() {
    _debounce?.cancel();
    _generation++;
    _pending = null;
    _pendingKey = null;
    _results = null;
    _entityResults = null;
    _loadingMore = false;
    _isSearching = false;
    _searchFailed = false;
    _failedRefresh = false;
  }

  Future<void> refresh() {
    if (_disposed) return Future.value();
    _debounce?.cancel();
    return _query.trim().isEmpty
        ? loadDefault(refresh: true)
        : _perform(refresh: true);
  }

  Future<void> loadMore() {
    if (_disposed || _isSearching || !hasMore) return Future.value();
    if (_pending != null) return _pending!;
    return _perform(loadMore: true);
  }

  Future<void> retry() =>
      _perform(loadMore: _failedLoadMore, refresh: _failedRefresh);

  Future<void> _perform({bool loadMore = false, bool refresh = false}) {
    if (_disposed || _query.trim().isEmpty) return Future.value();
    final page = loadMore ? (_results?.page ?? 1) + 1 : 1;
    final key = '${_mode.name}/${_query.trim()}/$page/$loadMore/$refresh';
    if (_pendingKey == key && _pending != null) return _pending!;
    final generation = ++_generation;
    final selectedMode = _mode;
    final term = _query.trim();
    _isSearching = !loadMore && !refresh;
    _loadingMore = loadMore;
    _searchFailed = false;
    _failedLoadMore = loadMore;
    _failedRefresh = refresh;
    _pendingKey = key;
    _notify();
    return _pending = _read(term, selectedMode, page, generation, loadMore);
  }

  Future<void> _read(
    String term,
    SearchMode selectedMode,
    int page,
    int generation,
    bool loadMore,
  ) async {
    bool current() => !_disposed && generation == _generation;
    try {
      final SearchResults? media;
      final SearchEntityResults? entities;
      if (selectedMode == SearchMode.collections ||
          selectedMode == SearchMode.companies) {
        media = null;
        entities = await Future.sync(
          () => (selectedMode == SearchMode.collections
              ? _collections
              : _companies)(term, page: page),
        );
      } else {
        entities = null;
        media = await Future.sync(
          () => _search(
            term,
            type: switch (selectedMode) {
              SearchMode.movies => 'movie',
              SearchMode.shows => 'tv',
              SearchMode.people => 'person',
              _ => 'all',
            },
            page: page,
          ),
        );
      }
      if (!current()) return;
      _results = loadMore && media != null
          ? SearchResults(
              page: media.page,
              results: [...?_results?.results, ...media.results],
              totalPages: media.totalPages,
              totalResults: media.totalResults,
            )
          : media;
      _entityResults = entities;
    } catch (_) {
      if (current()) _searchFailed = true;
    } finally {
      if (current()) {
        _pending = null;
        _pendingKey = null;
        _isSearching = false;
        _loadingMore = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _generation++;
    _defaultGeneration++;
    _pending = null;
    _results = null;
    _entityResults = null;
    _trendingMovies = const [];
    _recentSearches = const [];
    super.dispose();
  }
}
