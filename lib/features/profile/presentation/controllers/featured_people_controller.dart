import 'package:flutter/foundation.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import '../../data/user_service.dart';
import 'package:flixie_app/models/user.dart';

typedef SaveFeaturedPeople = Future<User> Function(
    String id, String field, dynamic value);

class FeaturedPeopleController extends ChangeNotifier {
  FeaturedPeopleController(
      {required this.auth, this.save = UserService.updateUserField}) {
    _viewer = auth.dbUser?.id;
    auth.addListener(_accountChanged);
  }
  final AuthProvider auth;
  final SaveFeaturedPeople save;
  bool saving = false;
  bool _disposed = false;
  String? _viewer;
  int _generation = 0;
  void _accountChanged() {
    if (_viewer != auth.dbUser?.id) {
      _viewer = auth.dbUser?.id;
      _generation++;
    }
  }

  Future<void> choose(String role, int? personId) async {
    if (saving) return;
    final user = auth.dbUser;
    if (user == null) return;
    final generation = _generation;
    final updated = {...user.featuredPeople};
    if (personId == null) {
      updated.remove(role);
    } else {
      updated[role] = personId;
    }
    saving = true;
    notifyListeners();
    try {
      final result = await save(user.id, 'featuredPeople', updated);
      // Keep the latest library and badge data; never apply a previous account's response.
      final current = auth.dbUser;
      if (!_disposed && generation == _generation && current?.id == user.id) {
        auth.updateDbUser(
            current!.copyWith(featuredPeople: result.featuredPeople));
      }
    } finally {
      saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    auth.removeListener(_accountChanged);
    super.dispose();
  }
}
