import '../../models/user.dart';

import '../../models/watch_provider.dart';

import '../repositories/settings_repository.dart';

class SettingsUseCase {
  SettingsUseCase(this._settingsRepository);

  final SettingsRepository _settingsRepository;

  Future<bool> usernameExists(String username) =>
      _settingsRepository.usernameExists(username);

  Future<User> updateUserField(String userId, String field, dynamic value) =>
      _settingsRepository.updateUserField(userId, field, value);

  Future<User> updateIconColor(String userId, int iconColorId) =>
      _settingsRepository.updateIconColor(userId, iconColorId);

  Future<void> addFavoriteGenres(String userId, List<int> genreIds) =>
      _settingsRepository.addFavoriteGenres(userId, genreIds);

  Future<List<WatchProvider>> getUserWatchProviders(String userId) =>
      _settingsRepository.getUserWatchProviders(userId);

  Future<void> updateUserWatchProviders(
    String userId,
    List<int> watchProviderIds,
  ) =>
      _settingsRepository.updateUserWatchProviders(
        userId,
        watchProviderIds,
      );
}
