import 'referral_attribution_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Retains a single watch link through authentication, setup and app restarts.
class PendingWatchInviteStore {
  static const _referralKey = 'watch_invite_applied_referral_v1';
  static Future<void> referralConsent(String? code, bool connect) async {
    final prefs = await SharedPreferences.getInstance();
    final store = SharedPreferencesReferralAttributionStore();
    final existing = await store.read();
    if (connect && code != null && existing == null) {
      await store.save(code);
      await prefs.setString(_referralKey, code);
    } else if (!connect &&
        prefs.getString(_referralKey) == existing &&
        existing != null) {
      await store.clear();
      await prefs.remove(_referralKey);
    }
  }

  static const _key = 'pending_watch_invite_v1';
  static const _intentKey = 'pending_watch_invite_ready_v1';
  static const _logKey = 'pending_watch_invite_log_v1';
  static const _ownerKey = 'pending_watch_invite_owner_v1';
  static bool valid(String? token) =>
      token != null && RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(token);
  static Future<void> save(String token) async {
    if (valid(token)) {
      await (await SharedPreferences.getInstance()).setString(_key, token);
    }
  }

  static Future<String?> read() async {
    final token = (await SharedPreferences.getInstance()).getString(_key);
    return valid(token) ? token : null;
  }

  static Future<void> readyToLog(String token) async {
    if (!valid(token)) return;
    await save(token);
    await (await SharedPreferences.getInstance()).setString(_intentKey, token);
  }

  static Future<bool> shouldResume(String token) async =>
      (await SharedPreferences.getInstance()).getString(_intentKey) == token;
  static Future<void> beginLog(String requestId, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ownerKey, userId);
    await prefs.setString(_logKey, requestId);
    await prefs.remove(_key);
    await prefs.remove(_intentKey);
  }

  static Future<String?> readLog(String? userId) async {
    if (userId == null) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ownerKey) == userId
        ? prefs.getString(_logKey)
        : null;
  }

  static Future<void> clear() async {
    await referralConsent(null, false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_intentKey);
    await prefs.remove(_logKey);
    await prefs.remove(_ownerKey);
  }
}
