import 'package:flutter/foundation.dart';
import 'package:flixie_app/core/api/api_client.dart';
import '../../data/curated_lists_service.dart';
import '../../models/curated_list.dart';

class CuratedListController extends ChangeNotifier {
  CuratedListController(
      {required this.id,
      required this.currentUserId,
      this.service = const CuratedListsService()});
  final String id;
  final String? Function() currentUserId;
  final CuratedListsService service;
  CuratedList? list;
  CuratedProgress? progress;
  bool loading = true, busy = false, newCompletion = false;
  String? error;
  int _generation = 0;
  bool _disposed = false;
  bool _current(int generation, String? owner) =>
      !_disposed && generation == _generation && owner == currentUserId();
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void resetOwner() {
    _generation++;
    progress = null;
    busy = false;
    newCompletion = false;
    error = null;
    _notify();
  }

  Future<void> load() async {
    if (busy) return;
    final generation = ++_generation, owner = currentUserId();
    loading = true;
    error = null;
    _notify();
    try {
      final value = await service.detail(id);
      if (!_current(generation, owner)) return;
      list = value;
      var personal = owner == null ? null : await service.progress(id);
      if (!_current(generation, owner)) return;
      if (personal?.joined == true &&
          personal!.completedAt == null &&
          personal.required > 0 &&
          personal.watched >= personal.required) {
        personal = await service.reconcile(id);
        if (!_current(generation, owner)) return;
        newCompletion = personal.completedAt != null;
      }
      list = value;
      progress = personal;
    } catch (e) {
      if (_current(generation, owner)) {
        error = e is ApiException
            ? e.message
            : 'Couldn’t load this list. Please retry.';
      }
    } finally {
      if (_current(generation, owner)) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> join() => _update(join: true);
  Future<void> refreshProgress() => _update();
  Future<void> _update({bool join = false}) async {
    final owner = currentUserId();
    if (owner == null || busy || list == null) return;
    final generation = _generation;
    busy = true;
    error = null;
    _notify();
    try {
      if (join) await service.join(id);
      if (!_current(generation, owner)) return;
      final value = join || progress?.joined == true
          ? await service.reconcile(id)
          : await service.progress(id);
      if (!_current(generation, owner)) return;
      newCompletion =
          progress?.completedAt == null && value.completedAt != null;
      progress = value;
    } catch (e) {
      if (_current(generation, owner)) {
        error = e is ApiException
            ? e.message
            : join
                ? 'Couldn’t join this challenge; please retry.'
                : 'Your watch is safe. Couldn’t refresh progress; please retry.';
      }
    } finally {
      if (_current(generation, owner)) {
        busy = false;
        _notify();
      }
    }
  }

  bool takeCompletion() {
    final result = newCompletion;
    newCompletion = false;
    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
