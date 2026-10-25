import 'package:flutter/foundation.dart';
import '../../../../core/utils/favourite_limits.dart';
import '../../../authentication/data/setup_service.dart';
import '../../data/taste_service.dart';
import '../../data/taste_setup_store.dart';

/// Owns search, persisted actions and account-safe progress; no signup gates.
class TasteController extends ChangeNotifier {
  TasteController(
      {required this.userId,
      required this.isCurrent,
      this.service = const TasteService(),
      this.store = const TasteSetupStore(),
      required this.onSaved});
  final String userId;
  final bool Function() isCurrent;
  final VoidCallback onSaved;
  final TasteService service;
  final TasteSetupStore store;
  bool _disposed = false;
  bool get active => !_disposed && isCurrent();
  String step = 'favourites';
  String? pendingFavourite;
  bool loading = true, searching = false, busy = false, ratingLoading = false;
  String? error, searchError, ratingError;
  List<SetupTitle> titles = [];
  Set<int> favourites = {};
  final Map<int, ({SetupTitle title, int score})> ratings = {};
  SetupTitle? selected;
  int? initialRating;
  String? initialRecommendation;
  int _searchVersion = 0, _ratingVersion = 0;
  void changed() {
    if (active) notifyListeners();
  }

  Future<void> load() async {
    loading = true;
    error = null;
    changed();
    try {
      final progress = await store.step(userId);
      final saved = await service.favourites(userId);
      if (!active) return;
      step = const {'favourites', 'rating', 'summary'}.contains(progress)
          ? progress
          : 'favourites';
      favourites = saved;
      await search('');
    } catch (_) {
      if (active) error = 'Couldn’t load your taste. Try again.';
    } finally {
      if (active) {
        loading = false;
        changed();
      }
    }
  }

  Future<void> search(String query) async {
    final version = ++_searchVersion;
    searching = true;
    searchError = null;
    changed();
    try {
      final rows = await service.titles(query);
      if (!active || version != _searchVersion) return;
      titles = rows.where((t) => !t.isShow).toList();
    } catch (_) {
      if (active && version == _searchVersion) {
        searchError = 'Couldn’t find films right now. Try again.';
      }
    } finally {
      if (active && version == _searchVersion) {
        searching = false;
        changed();
      }
    }
  }

  Future<void> toggle(SetupTitle title) async {
    if (!active || busy || title.isShow) return;
    final add = !favourites.contains(title.id);
    if (add && favourites.length >= maxFavouriteMovies) {
      error =
          'Your ten favourite film spots are full. Remove a heart to make room, or carry on to ratings.';
      changed();
      return;
    }
    busy = true;
    pendingFavourite = title.key;
    error = null;
    changed();
    try {
      await service.favourite(userId, title, add);
      if (!active) return;
      if (add) {
        favourites.add(title.id);
      } else {
        favourites.remove(title.id);
      }
      service.invalidate(userId);
      onSaved();
    } catch (_) {
      if (active) {
        error =
            'Couldn’t save that favourite. Your other picks are safe. Try again.';
      }
    } finally {
      if (active) {
        busy = false;
        pendingFavourite = null;
        changed();
      }
    }
  }

  Future<void> choose(SetupTitle title) async {
    if (!active || busy || title.isShow) return;
    final version = ++_ratingVersion;
    selected = title;
    ratingLoading = true;
    ratingError = null;
    initialRating = null;
    initialRecommendation = null;
    changed();
    try {
      final old = await service.rating(userId, title.id);
      if (!active || version != _ratingVersion) return;
      initialRating = old.rating;
      initialRecommendation = old.recommended == null
          ? null
          : old.recommended!
              ? 'recommend'
              : 'avoid';
    } catch (_) {
      if (active && version == _ratingVersion) {
        ratingError =
            'Couldn’t load your existing rating. Retry before editing it.';
      }
    } finally {
      if (active && version == _ratingVersion) {
        ratingLoading = false;
        changed();
      }
    }
  }

  void chooseAnother() {
    if (busy) return;
    _ratingVersion++;
    selected = null;
    ratingError = null;
    changed();
  }

  Future<void> rate(int score, String? recommendation) async {
    final title = selected;
    if (!active ||
        busy ||
        ratingLoading ||
        ratingError != null ||
        title == null) {
      return;
    }
    busy = true;
    error = null;
    changed();
    try {
      await service.rate(userId, title.id, score, recommendation);
      if (!active) return;
      ratings[title.id] = (title: title, score: score);
      service.invalidate(userId);
      onSaved();
      step = 'summary';
      try {
        await store.saveStep(userId, step);
      } catch (_) {/* Backend save is already acknowledged. */}
    } catch (_) {
      rethrow;
    } finally {
      if (active) {
        busy = false;
        changed();
      }
    }
  }

  Future<void> move(String next) async {
    if (!active || busy) return;
    _searchVersion++;
    _ratingVersion++;
    selected = null;
    step = next;
    error = null;
    changed();
    // Begin the step's default query before persistence yields. A newer user
    // query must never be replaced by a default query started afterwards.
    final results = next == 'summary' ? Future<void>.value() : search('');
    try {
      await store.saveStep(userId, next);
    } catch (_) {/* Setup remains optional if device storage is unavailable. */}
    await results;
  }

  Future<void> dismiss() => store.hide(userId);
  @override
  void dispose() {
    _disposed = true;
    _searchVersion++;
    _ratingVersion++;
    super.dispose();
  }
}
