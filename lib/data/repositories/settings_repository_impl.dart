import 'package:flixie_app/models/watch_provider.dart';

import '../../domain/repositories/settings_repository.dart';
import '../../models/user.dart';
import '../../services/user_service.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  @override
  Future<bool> usernameExists(String username) =>
      UserService.usernameExists(username);

  @override
  Future<User> updateUserField(String userId, String field, dynamic value) =>
      UserService.updateUserField(userId, field, value);

  @override
  Future<User> updateIconColor(String userId, int iconColorId) =>
      UserService.updateIconColor(userId, iconColorId);

  @override
  Future<void> addFavoriteGenres(String userId, List<int> genreIds) =>
      UserService.addFavoriteGenres(userId, genreIds);

  @override
  Future<List<WatchProvider>> getUserWatchProviders(String userId) =>
      UserService.getUserWatchProviders(userId);

  @override
  Future<void> updateUserWatchProviders(
    String userId,
    List<int> watchProviderIds,
  ) =>
      UserService.updateUserWatchProviders(userId, watchProviderIds);
}
