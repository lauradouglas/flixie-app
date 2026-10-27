import 'package:shared_preferences/shared_preferences.dart';

/// Engagement, not sentiment: a low film rating counts exactly like a high one.
class AppReviewPolicy {
  static const cooldown = Duration(days: 120);
  static const globalAttemptKey = 'app_review.last_attempt_device';
  static String _key(String user, String field) =>
      'app_review.engagement.$user.$field';

  static Future<void> record(
      SharedPreferences prefs, String user, String event, DateTime now) async {
    final first = _key(user, 'first');
    if (!prefs.containsKey(first)) {
      await prefs.setInt(first, now.millisecondsSinceEpoch);
    }
    final days = {
      ...?prefs.getStringList(_key(user, 'days')),
      '${now.year}-${now.month}-${now.day}'
    };
    final events = {...?prefs.getStringList(_key(user, 'events')), event};
    // Only eligibility is needed; do not keep an unbounded activity history.
    await prefs.setStringList(_key(user, 'days'), days.take(2).toList());
    await prefs.setStringList(_key(user, 'events'), events.take(3).toList());
  }

  static bool eligible(SharedPreferences prefs, String user, DateTime now) {
    final first = prefs.getInt(_key(user, 'first'));
    if (first == null ||
        now.difference(DateTime.fromMillisecondsSinceEpoch(first)) <
            const Duration(hours: 48)) {
      return false;
    }
    if ((prefs.getStringList(_key(user, 'days'))?.length ?? 0) < 2 ||
        (prefs.getStringList(_key(user, 'events'))?.length ?? 0) < 3) {
      return false;
    }
    // Honour previous releases' account cooldown as well as the device cooldown.
    for (final key in [globalAttemptKey, 'app_review.last_prompt.$user']) {
      final previous = prefs.getInt(key);
      if (previous != null &&
          now.difference(DateTime.fromMillisecondsSinceEpoch(previous)) <
              cooldown) {
        return false;
      }
    }
    return true;
  }
}
