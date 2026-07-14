import 'package:flixie_app/features/settings/data/settings_repository_impl.dart';

import 'package:flixie_app/features/settings/data/settings_usecase.dart';

import 'package:flixie_app/models/user.dart';

import 'package:flixie_app/models/watch_provider.dart';

class SettingsController {
  SettingsController({SettingsUseCase? useCase})
      : _useCase = useCase ?? SettingsUseCase(SettingsRepositoryImpl());

  static final SettingsController instance = SettingsController();

  final SettingsUseCase _useCase;

  Future<bool> usernameExists(String username) =>
      _useCase.usernameExists(username);

  Future<User> updateUserField(String userId, String field, dynamic value) =>
      _useCase.updateUserField(userId, field, value);

  Future<User> updateIconColor(String userId, int iconColorId) =>
      _useCase.updateIconColor(userId, iconColorId);

  Future<void> addFavoriteGenres(String userId, List<int> genreIds) =>
      _useCase.addFavoriteGenres(userId, genreIds);

  Future<List<WatchProvider>> getUserWatchProviders(String userId) =>
      _useCase.getUserWatchProviders(userId);

  Future<void> updateUserWatchProviders(
    String userId,
    List<int> watchProviderIds,
  ) =>
      _useCase.updateUserWatchProviders(userId, watchProviderIds);
}
