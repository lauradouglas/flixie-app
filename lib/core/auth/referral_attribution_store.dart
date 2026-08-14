import 'package:shared_preferences/shared_preferences.dart';

abstract interface class ReferralAttributionStore {
  Future<String?> read();
  Future<void> save(String code);
  Future<void> clear();
}

class SharedPreferencesReferralAttributionStore
    implements ReferralAttributionStore {
  static const _key = 'pending_referral_code_v1';

  @override
  Future<String?> read() async {
    final preferences = await SharedPreferences.getInstance();
    return _normalize(preferences.getString(_key));
  }

  @override
  Future<void> save(String code) async {
    final normalized = _normalize(code);
    if (normalized == null) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, normalized);
  }

  @override
  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key);
  }

  static String? _normalize(String? value) {
    final normalized = value?.trim().toUpperCase();
    if (normalized == null || normalized.length < 4 || normalized.length > 32) {
      return null;
    }
    return normalized;
  }
}
