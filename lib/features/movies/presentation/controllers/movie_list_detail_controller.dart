import 'package:flutter/foundation.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/models/movie_list_membership.dart';
import 'package:flixie_app/models/user.dart';
import '../../data/movie_list_detail_service.dart';

/// Route-scoped access metadata; title snapshots remain in MovieListsProvider.
class MovieListDetailController extends ChangeNotifier {
  MovieListDetailController(
      {required this.listId,
      required this.ownerId,
      required User? viewer,
      required this.currentViewer,
      this.service = const MovieListDetailService()})
      : viewerId = viewer?.id,
        _owner = viewer?.id == ownerId ? viewer : null;
  final String listId, ownerId;
  final String? viewerId;
  final String? Function() currentViewer;
  final MovieListDetailService service;
  User? _owner;
  MovieListMembership? _membership;
  User? get owner => _owner;
  MovieListMembership? get membership => _membership;
  bool accessDenied = false;
  int _generation = 0;
  bool _disposed = false;
  bool _current(int generation) =>
      !_disposed && generation == _generation && currentViewer() == viewerId;

  Future<void> refresh() async {
    if (_disposed || currentViewer() != viewerId) return;
    final generation = ++_generation;
    try {
      final result = await service.members(ownerId, listId);
      if (!_current(generation)) return;
      accessDenied = false;
      _membership = result;
      notifyListeners();
      await _loadOwner(result.ownerId, generation);
    } catch (error) {
      if (_current(generation) &&
          error is ApiException &&
          [401, 403, 404].contains(error.statusCode)) {
        accessDenied = true;
        _membership = null;
        _owner = null;
        notifyListeners();
        return;
      }
      // Retain useful metadata on ordinary refresh failures.
      // API authorization remains authoritative for all reads and writes.
      if (_current(generation) && _owner == null) {
        await _loadOwner(ownerId, generation);
      }
    }
  }

  Future<void> _loadOwner(String id, int generation) async {
    if (!_current(generation) || _owner?.id == id) return;
    try {
      final result = await service.owner(id);
      if (!_current(generation)) return;
      _owner = result;
      notifyListeners();
    } catch (_) {
      // Profile metadata is optional; the list remains usable.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
