import 'package:shared_preferences/shared_preferences.dart';

/// Local, account-scoped frequency cap. No prompt is required to earn rewards.
class ReferralPromptStore {
  static final _pending = <String>{};
  static Future<bool> reserve(String userId, {DateTime? now}) async {
    if (!_pending.add(userId)) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'saved_film_invite_v1:$userId';
      final time = now ?? DateTime.now();
      final last = prefs.getInt('$key:last');
      final count = prefs.getInt('$key:count') ?? 0;
      if (count >= 3 ||
          (last != null &&
              time.difference(DateTime.fromMillisecondsSinceEpoch(last)) <
                  const Duration(days: 7))) {
        return false;
      }
      if (!await prefs.setInt('$key:last', time.millisecondsSinceEpoch)) {
        return false;
      }
      await prefs.setInt('$key:count', count + 1);
      return true;
    } catch (_) {
      return false; // A promotion must never interfere with a saved watch.
    } finally {
      _pending.remove(userId);
    }
  }
}
