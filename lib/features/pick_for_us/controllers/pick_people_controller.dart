import 'package:flutter/foundation.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/group.dart';
import '../data/pick_for_us_service.dart';

/// Viewer reads belong to one picker flow, not a global relationship cache.
class PickPeopleController extends ChangeNotifier {
  PickPeopleController({required this.userId, required this.service});
  final String userId;
  final PickForUsService service;
  List<Friendship> friends = const [];
  List<Group> groups = const [];
  final _loading = <String>{}, _loaded = <String>{};
  final _errors = <String, String>{};
  bool _disposed = false;
  bool loading(String company) => _loading.contains(company);
  String? error(String company) => _errors[company];
  Future<void> load(String company) async {
    if (_disposed ||
        company == 'solo' ||
        _loading.contains(company) ||
        _loaded.contains(company)) {
      return;
    }
    _loading.add(company);
    _errors.remove(company);
    notifyListeners();
    try {
      if (company == 'friend') {
        final result = await service.friends(userId);
        if (_disposed) return;
        friends = List.unmodifiable(result.friendships);
      } else if (company == 'group') {
        final result = await service.groups(userId);
        if (_disposed) return;
        groups = List.unmodifiable(result.where((g) => g.id != null));
      }
      _loaded.add(company);
    } catch (_) {
      if (_disposed) return;
      _errors[company] =
          'Some viewers couldn’t load. Retry, or pick just for you.';
    } finally {
      if (!_disposed) {
        _loading.remove(company);
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
