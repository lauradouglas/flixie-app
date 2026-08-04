import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/models/user.dart';

import 'package:flixie_app/models/watch_provider.dart';

class SettingsController {
  const SettingsController();

  static const SettingsController instance = SettingsController();

  Future<bool> usernameExists(String username) =>
      UserService.usernameExists(username);

  Future<User> updateUserField(String userId, String field, dynamic value) =>
      UserService.updateUserField(userId, field, value);

  Future<User> updateIconColor(String userId, int iconColorId) =>
      UserService.updateIconColor(userId, iconColorId);

  Future<void> addFavoriteGenres(String userId, List<int> genreIds) =>
      UserService.addFavoriteGenres(userId, genreIds);

  Future<List<WatchProvider>> getUserWatchProviders(String userId) =>
      UserService.getUserWatchProviders(userId);

  Future<void> updateUserWatchProviders(
    String userId,
    List<int> watchProviderIds,
  ) =>
      UserService.updateUserWatchProviders(userId, watchProviderIds);
}
