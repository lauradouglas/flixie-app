import '../../data/repositories/settings_repository_impl.dart';
import '../../domain/usecases/settings_usecase.dart';
import '../../models/user.dart';

class SettingsController {
  SettingsController({SettingsUseCase? useCase}) : _useCase = useCase ?? SettingsUseCase(SettingsRepositoryImpl());

  static final SettingsController instance = SettingsController();

  final SettingsUseCase _useCase;

  Future<bool> usernameExists(String username) => _useCase.usernameExists(username);
  Future<User> updateUserField(String userId, String field, dynamic value) => _useCase.updateUserField(userId, field, value);
  Future<User> updateIconColor(String userId, int iconColorId) => _useCase.updateIconColor(userId, iconColorId);
  Future<void> addFavoriteGenres(String userId, List<int> genreIds) => _useCase.addFavoriteGenres(userId, genreIds);
}
