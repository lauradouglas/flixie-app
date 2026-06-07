import '../../models/user.dart';
import '../../models/watch_provider.dart';

abstract class SettingsRepository {
  Future<bool> usernameExists(String username);
  Future<User> updateUserField(String userId, String field, dynamic value);
  Future<User> updateIconColor(String userId, int iconColorId);
  Future<void> addFavoriteGenres(String userId, List<int> genreIds);
  Future<List<WatchProvider>> getUserWatchProviders(String userId);
  Future<void> updateUserWatchProviders(
    String userId,
    List<int> watchProviderIds,
  );
}
