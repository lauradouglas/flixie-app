import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flixie_app/models/country.dart';
import 'package:flixie_app/models/genre.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/features/settings/data/episode_spoiler_preference.dart';
import '../../data/setup_service.dart';

/// Setup state, stale-result guards and request scheduling for one account.
class OnboardingController extends ChangeNotifier {
  OnboardingController(
      {required this.service,
      required this.userId,
      required this.countryId,
      required this.isCurrentUser});
  final SetupService service;
  final String userId;
  final int? countryId;
  final bool Function() isCurrentUser;
  int _step = 0;
  bool _favouritesAdded = false;
  List<SetupCommunitySuggestion> _communityChoices = [];
  final Set<int> _selectedCommunities = {};
  bool _loadingCommunities = false;
  String? _communityError;
  int _communityRevision = 0;
  int _picksRevision = 0;
  final Map<int, Map<String, dynamic>> _conversations = {};

  bool _busy = false, _loading = true, _shows = false, _searching = false;
  String? _error, _searchError, _picksError, _referrer;
  List<Country> _countries = [];
  Country? _country;
  List<WatchProvider> _providers = [];
  final Set<int> _selectedProviders = {}, _genres = {};
  List<Genre> _allGenres = [];
  final Map<String, SetupTitle> _taste = {};
  List<SetupTitle> _browse = [], _picks = [];
  final Map<String, List<WatchProvider>?> _offers = {};
  final Set<String> _added = {}, _adding = {};
  Timer? _debounce;
  int _searchRevision = 0;
  int _tasteRevision = 0;
  bool _disposed = false;
  bool _started = false;
  String _query = '', _providerQuery = '';
  bool _editingTaste = false;
  int get step => _step;
  bool get favouritesAdded => _favouritesAdded;
  bool get loadingCommunities => _loadingCommunities;
  bool get busy => _busy;
  bool get loading => _loading;
  bool get shows => _shows;
  bool get searching => _searching;
  bool get editingTaste => _editingTaste;
  String? get communityError => _communityError;
  String? get error => _error;
  String? get searchError => _searchError;
  String? get picksError => _picksError;
  String? get referrer => _referrer;
  Country? get country => _country;
  List<SetupCommunitySuggestion> get communityChoices =>
      UnmodifiableListView(_communityChoices);
  List<Country> get countries => UnmodifiableListView(_countries);
  List<WatchProvider> get providers => UnmodifiableListView(_providers);
  List<Genre> get allGenres => UnmodifiableListView(_allGenres);
  List<SetupTitle> get browse => UnmodifiableListView(_browse);
  List<SetupTitle> get picks => UnmodifiableListView(_picks);
  Set<int> get selectedCommunities => UnmodifiableSetView(_selectedCommunities);
  Set<int> get selectedProviders => UnmodifiableSetView(_selectedProviders);
  Set<int> get genres => UnmodifiableSetView(_genres);
  Set<String> get added => UnmodifiableSetView(_added);
  Set<String> get adding => UnmodifiableSetView(_adding);
  Map<String, SetupTitle> get taste => UnmodifiableMapView(_taste);
  Map<int, Map<String, dynamic>> get conversations =>
      UnmodifiableMapView(_conversations);

  bool get active => !_disposed && isCurrentUser();
  void _update(VoidCallback change) {
    if (!active) return;
    change();
    notifyListeners();
  }

  void start() {
    if (_started || !active) return;
    _started = true;
    unawaited(load());
    unawaited(findTitles());
    unawaited(loadGenres());
    service.referrer(userId).then((value) {
      _update(() => _referrer = value);
    }).catchError((Object _) {});
  }

  void setBusy(bool value) => _update(() => _busy = value);
  void favouriteSaved() => _favouritesAdded = true;
  void changeQuery(String value) {
    if (!active) return;
    _query = value;
    ++_searchRevision;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), findTitles);
  }

  void changeMode(bool value) {
    if (!active || _busy || _shows == value) return;
    _debounce?.cancel();
    _shows = value;
    unawaited(findTitles());
  }

  void changeProviderQuery(String value) =>
      _update(() => _providerQuery = value);
  List<WatchProvider> get visibleProviders =>
      setupProviders(_providers, query: _providerQuery);
  void chooseCountry(Country value) => _update(() {
        _country = value;
        _providerQuery = '';
        _selectedProviders
            .removeWhere((id) => !visibleProviders.any((p) => p.id == id));
      });
  void selectProvider(int id, bool selected) => _update(() {
        if (_busy) return;
        selected ? _selectedProviders.add(id) : _selectedProviders.remove(id);
      });
  void clearProviders() => _update(_selectedProviders.clear);
  void selectGenre(int id, bool selected) => _update(() {
        if (_busy) return;
        selected ? _genres.add(id) : _genres.remove(id);
      });
  bool toggleTaste(SetupTitle title) {
    if (!active || _busy) return false;
    if (!_taste.containsKey(title.key) && _taste.length >= 3) return false;
    ++_tasteRevision;
    _update(() {
      if (_taste.containsKey(title.key)) {
        _taste.remove(title.key);
      } else {
        _taste[title.key] = title;
      }
    });
    return true;
  }

  void toggleEditingTaste() => _update(() => _editingTaste = !_editingTaste);
  void removeTaste(String key) => _update(() {
        ++_tasteRevision;
        _taste.remove(key);
        if (_taste.isEmpty) _editingTaste = false;
      });
  void selectCommunity(int id, bool selected) => _update(() {
        if (_busy) return;
        selected
            ? _selectedCommunities.add(id)
            : _selectedCommunities.remove(id);
      });
  void clearCommunities() => _update(_selectedCommunities.clear);
  Future<void> saveWatching() => run(() async {
        if (_country == null) return;
        await service.saveWatching(
            userId, _country!, Set.of(_selectedProviders));
        if (active) move(2);
      });
  Future<bool> add(SetupTitle title) async {
    if (!active || _adding.contains(title.key) || _added.contains(title.key)) {
      return false;
    }
    _update(() => _adding.add(title.key));
    try {
      await service.addToWatchlist(userId, title);
      if (!active) return false;
      _update(() => _added.add(title.key));
      return true;
    } catch (_) {
      _update(() => _error =
          'Couldn’t add ${title.name}. Tap Add to watchlist to retry.');
      return false;
    } finally {
      _update(() => _adding.remove(title.key));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    ++_searchRevision;
    ++_picksRevision;
    ++_communityRevision;
    super.dispose();
  }

  Future<void> load() async {
    if (!active) return;
    final tasteRevision = _tasteRevision;
    _update(() {
      _loading = true;
      _error = null;
    });
    try {
      final countries = await service.countries();
      if (!active) return;
      final providers = await service.providers();
      if (!active) return;
      final saved = await service.savedProviders(userId);
      if (!active) return;
      final taste = await service.loadTaste(userId);
      if (!active) return;
      _update(() {
        _countries = countries;
        _providers = providers;
        _country = countries.where((c) => c.id == countryId).firstOrNull;
        _selectedProviders.addAll(saved.map((p) => p.id));
        if (tasteRevision == _tasteRevision) {
          _taste.addEntries(taste.take(3).map((t) => MapEntry(t.key, t)));
        }
      });
    } catch (_) {
      if (active) {
        _update(() => _error =
            'Couldn’t load setup. Retry, or skip this step and choose your services later.');
      }
    } finally {
      if (active) _update(() => _loading = false);
    }
  }

  void move(int step) {
    ++_searchRevision;
    _debounce?.cancel();
    if (!active) return;
    if (step != 2) ++_picksRevision;
    if (step != 5) ++_communityRevision;
    _update(() {
      _searching = false;
      _step = step;
      _error = null;
    });
    if (step == 5) loadCommunities();
    if (step == 2) {
      EpisodeSpoilerPreference.instance.load().catchError((Object _) {});
      loadPicks();
    }
    if (step == 0 && _browse.isEmpty) {
      findTitles();
      loadGenres();
    }
  }

  Future<void> loadGenres() async {
    try {
      final values = await service.genres();
      if (active) _update(() => _allGenres = values);
    } catch (_) {/* Genres are optional; title search remains available. */}
  }

  Future<void> run(Future<void> Function() action) async {
    if (!active || _busy) return;
    _update(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (_) {
      if (active) {
        _update(() => _error =
            'Couldn’t save this step. Your choices are still here. Please try again.');
      }
    } finally {
      if (active) _update(() => _busy = false);
    }
  }

  Future<void> findTitles() async {
    if (!active) return;
    final revision = ++_searchRevision;
    final shows = _shows, query = _query.trim();
    _update(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final values = query.isEmpty
          ? await service.popular(shows)
          : await service.search(query, shows);
      if (active && revision == _searchRevision) {
        _update(() => _browse = values);
      }
    } catch (_) {
      if (active && revision == _searchRevision) {
        _update(() {
          _browse = [];
          _searchError = 'Couldn’t load titles. Try again.';
        });
      }
    } finally {
      if (active && revision == _searchRevision) {
        _update(() => _searching = false);
      }
    }
  }

  Future<void> loadPicks() async {
    if (!active) return;
    final revision = ++_picksRevision;
    _update(() {
      _searching = true;
      _picksError = null;
    });
    try {
      final picks = _favouritesAdded
          ? await service.favouriteRecommendations(userId)
          : await service.recommendations(_taste.values.toList());
      if (!active || revision != _picksRevision) return;
      _update(() {
        _picks = picks;
        _offers.clear();
      });
      if (_country != null) {
        final region = _country!.abbreviation.toUpperCase() == 'UK'
            ? 'GB'
            : _country!.abbreviation.toUpperCase();
        // Six cards at most, in batches of three availability requests.
        for (var i = 0; i < picks.length; i += 3) {
          if (!active || revision != _picksRevision) return;
          await Future.wait(picks.skip(i).take(3).map((title) async {
            try {
              final offers = await service.availability(title, region);
              if (active && revision == _picksRevision) {
                _update(() => _offers[title.key] = offers);
              }
            } catch (_) {
              if (active && revision == _picksRevision) {
                _update(() => _offers[title.key] = null);
              }
            }
          }));
        }
      }
    } catch (_) {
      if (active && revision == _picksRevision) {
        _update(() => _picksError =
            'Couldn’t load your first picks. Retry or explore Flixie.');
      }
    } finally {
      if (active && revision == _picksRevision) {
        _update(() => _searching = false);
      }
    }
  }

  Future<void> saveTaste({bool skip = false}) => run(() async {
        await service.saveTaste(userId, skip ? [] : _taste.values.toList(),
            skip ? {} : Set.of(_genres));
        if (active) {
          if (skip) {
            ++_tasteRevision;
            _taste.clear();
            _genres.clear();
          }
          move(1);
        }
      });
  Future<void> loadCommunities() async {
    if (!active) return;
    final revision = ++_communityRevision;
    _update(() {
      _loadingCommunities = true;
      _communityError = null;
    });
    try {
      final choices = await service.communitySuggestions(
          _taste.values.toList(), Set.of(_genres));
      if (!active || revision != _communityRevision) return;
      _update(() {
        _communityChoices = choices;
        _selectedCommunities.removeWhere((id) =>
            !choices.any((c) => c.community.id == id && !c.community.joined));
      });
      await Future.wait(
          choices.where((c) => c.suggested).take(3).map((c) async {
        try {
          final thread = await service.conversation(c.community.id);
          if (active && revision == _communityRevision && thread != null) {
            _update(() => _conversations[c.community.id] = thread);
          }
        } catch (_) {/* Optional preview failure never blocks browsing. */}
      }));
    } catch (_) {
      if (active && revision == _communityRevision) {
        _update(() => _communityError =
            'Couldn’t load communities. Retry or skip for now.');
      }
    } finally {
      if (active && revision == _communityRevision) {
        _update(() => _loadingCommunities = false);
      }
    }
  }

  Future<bool> joinCommunities() async {
    if (!active ||
        _busy ||
        (_loadingCommunities && _selectedCommunities.isNotEmpty)) {
      return false;
    }
    _update(() {
      _busy = true;
      _communityError = null;
    });
    try {
      for (final id in _selectedCommunities.toList()) {
        await service.joinCommunity(id);
        if (!active) return false;
        _update(() {
          _selectedCommunities.remove(id);
          _communityChoices = _communityChoices
              .map((c) => c.community.id == id ? c.joined() : c)
              .toList();
        });
      }
      return active;
    } catch (_) {
      if (active) {
        _update(() => _communityError =
            'Some communities couldn’t be joined. Your successful joins are saved. Retry the remaining choices or skip.');
      }
    } finally {
      if (active) _update(() => _busy = false);
    }
    return false;
  }

  List<SetupTitle> get rankedPicks {
    bool included(SetupTitle t) => (_offers[t.key] ?? [])
        .any((p) => p.isIncludedOffer && _selectedProviders.contains(p.id));
    return [..._picks.where(included), ..._picks.where((t) => !included(t))]
        .take(3)
        .toList();
  }

  String availabilityLabel(SetupTitle title) {
    if (_country == null) {
      return 'Choose your country in Settings for watch options';
    }
    if (!_offers.containsKey(title.key)) return 'Checking watch options…';
    final offers = _offers[title.key];
    if (offers == null) return 'Watch options unavailable';
    final included = offers.where((p) => p.isIncludedOffer).toList();
    final mine =
        included.where((p) => _selectedProviders.contains(p.id)).toList();
    if (mine.isNotEmpty) {
      return 'On your services: ${mine.map((p) => p.providerName).join(', ')}';
    }
    if (included.isNotEmpty) {
      return 'Streaming: ${included.map((p) => p.providerName).join(', ')}';
    }
    if (offers.isNotEmpty) return 'Rent or buy options available';
    return 'No watch options listed in ${_country!.name}';
  }
}
