import '../../domain/repositories/settings_repository.dart';
import '../../models/user.dart';
import '../../services/user_service.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  @override
  Future<bool> usernameExists(String username) => UserService.usernameExists(username);

  @override
  Future<User> updateUserField(String userId, String field, dynamic value) =>
      UserService.updateUserField(userId, field, value);

  @override
  Future<User> updateIconColor(String userId, int iconColorId) => UserService.updateIconColor(userId, iconColorId);

  @override
  Future<void> addFavoriteGenres(String userId, List<int> genreIds) =>
      UserService.addFavoriteGenres(userId, genreIds);
}
