import 'package:shared_preferences/shared_preferences.dart';

/// Records the welcome independently of account and sign-out state.
class FirstOpenStore {
  static const welcomeSeenKey = 'guest_welcome_seen_v1';

  Future<bool> consumeWelcome() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(welcomeSeenKey) == true) return false;
    await preferences.setBool(welcomeSeenKey, true);
    return true;
  }
}
