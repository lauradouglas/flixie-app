import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flixie_app/models/person.dart';
import 'package:flixie_app/models/user.dart';
import '../../data/person_detail_service.dart';
import '../person_filmography_selection.dart';

/// Route-scoped public detail and account-scoped favourite command state.
class PersonDetailController extends ChangeNotifier {
  PersonDetailController(
      {required this.personId,
      User? viewer,
      this.service = const PersonDetailService()}) {
    selectViewer(viewer);
  }
  final String personId;
  final PersonDetailService service;
  User? _viewer;
  Person? _person;
  PersonCredits? _credits;
  List<PersonFilmCredit> _allCredits = const [];
  List<PersonImage> _images = const [];
  PersonLibraryStatus _library = PersonLibraryStatus();
  bool _loading = true,
      _imagesLoading = false,
      _favorite = false,
      _saving = false;
  String? _error;
  int _loadGeneration = 0, _viewerGeneration = 0;
  bool _disposed = false;
  Person? get person => _person;
  PersonCredits? get credits => _credits;
  List<PersonFilmCredit> get allCredits => _allCredits;
  List<PersonImage> get images => _images;
  PersonLibraryStatus get library => _library;
  String? get viewerId => _viewer?.id;
  bool get loading => _loading;
  bool get imagesLoading => _imagesLoading;
  bool get favorite => _favorite;
  bool get saving => _saving;
  bool get active => !_disposed;
  String? get error => _error;

  void selectViewer(User? user) {
    if (_disposed || identical(user, _viewer)) return;
    if (_viewer?.id != user?.id) {
      _viewerGeneration++;
      _saving = false;
    }
    _viewer = user;
    _library = PersonLibraryStatus.fromUser(user);
    if (!_saving) {
      _favorite = user?.isPersonFavorite(int.tryParse(personId) ?? -1) ?? false;
    }
    notifyListeners();
  }

  bool _currentLoad(int generation) =>
      !_disposed && generation == _loadGeneration;
  Future<void> load() async {
    if (_disposed) return;
    final generation = ++_loadGeneration;
    final id = int.tryParse(personId);
    _error = null;
    _loading = true;
    _imagesLoading = false;
    if (id == null || id <= 0) {
      _error = 'Invalid person ID.';
      _loading = false;
      notifyListeners();
      return;
    }
    notifyListeners();
    try {
      final (person, credits) = await service.details(id);
      if (!_currentLoad(generation)) return;
      _person = person;
      _credits = credits;
      _allCredits = List.unmodifiable(mergePersonCredits(credits));
      _images = List.unmodifiable(person.images);
      _loading = false;
      _imagesLoading = true;
      notifyListeners();
      unawaited(_loadImages(id, generation));
    } catch (error) {
      if (!_currentLoad(generation)) return;
      _error = error.toString();
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadImages(int id, int generation) async {
    try {
      final images = await service.images(id);
      if (!_currentLoad(generation)) return;
      _images = List.unmodifiable(images);
    } catch (_) {
      // Preserve bundled images if the independent endpoint is unavailable.
    }
    if (!_currentLoad(generation)) return;
    _imagesLoading = false;
    notifyListeners();
  }

  Future<PersonFavoriteChange?> toggleFavorite() async {
    final user = _viewer;
    final id = int.tryParse(personId);
    if (_disposed || _saving || user == null || id == null || id <= 0) {
      return null;
    }
    final generation = _viewerGeneration;
    bool current() =>
        !_disposed && generation == _viewerGeneration && _viewer?.id == user.id;
    final favorite = !_favorite;
    _saving = true;
    notifyListeners();
    try {
      await service.setFavorite(id, user.id, favorite: favorite);
      if (!current()) return null;
      _favorite = favorite;
      return PersonFavoriteChange(
          personId: id, viewerId: user.id, favorite: favorite);
    } catch (_) {
      if (!current()) return null;
      rethrow;
    } finally {
      if (current()) {
        _saving = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _loadGeneration++;
    _viewerGeneration++;
    super.dispose();
  }
}

/// Apply to the latest list, preserving unrelated edits made during the write.
class PersonFavoriteChange {
  const PersonFavoriteChange(
      {required this.personId, required this.viewerId, required this.favorite});
  final int personId;
  final String viewerId;
  final bool favorite;
  List<dynamic> applyTo(List<dynamic>? existing) {
    final list = List<dynamic>.from(existing ?? []);
    list.removeWhere((item) => item is int
        ? item == personId
        : item is Map &&
            (item['personId'] == personId || item['id'] == personId));
    if (favorite) list.add(personId);
    return list;
  }
}
