import '../models/user.dart';
import 'api_client.dart';

class UserService {
  static Future<User> createUser(Map<String, dynamic> body) async {
    final data = await ApiClient.post('/users/create-users', body: body);
    return User.fromJson(data as Map<String, dynamic>);
  }

  static Future<User> getUserById(String id) async {
    final data = await ApiClient.get('/users/$id');
    return User.fromJson(data as Map<String, dynamic>);
  }

  static Future<User> getUserByUsername(String username) async {
    final data = await ApiClient.get('/users/username/$username');
    return User.fromJson(data as Map<String, dynamic>);
  }

  static Future<User> getUserByExternalId(String externalId) async {
    final data = await ApiClient.get('/users/external-id/$externalId');
    return User.fromJson(data as Map<String, dynamic>);
  }

  static Future<bool> usernameExists(String username) async {
    final data = await ApiClient.get('/users/$username/exists');
    return data as bool;
  }

  static Future<User> updateUser(Map<String, dynamic> body) async {
    final data = await ApiClient.put('/users/update', body: body);
    return User.fromJson(data as Map<String, dynamic>);
  }

  static Future<User> updateEmail(Map<String, dynamic> body) async {
    final data = await ApiClient.put('/users/update/email', body: body);
    return User.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> deleteUser(String externalId) async {
    await ApiClient.delete('/users/external-id/$externalId');
  }

  static Future<List<dynamic>> getUserActivity(String userId) async {
    final data = await ApiClient.get('/users/$userId/activity');
    return data as List<dynamic>;
  }

  static Future<User> toggleDarkMode(String userId, bool darkMode) async {
    final data = await ApiClient.patch(
      '/users/$userId/dark-mode',
      body: {'darkMode': darkMode},
    );
    return User.fromJson(data as Map<String, dynamic>);
  }

  static Future<User> updateIconColor(String userId, int iconColorId) async {
    final data = await ApiClient.patch(
      '/users/$userId/icon-color',
      body: {'iconColorId': iconColorId},
    );
    return User.fromJson(data as Map<String, dynamic>);
  }
}
