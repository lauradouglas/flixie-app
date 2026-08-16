import 'package:shared_preferences/shared_preferences.dart';

/// Keeps a person's closed Watch Plans out of their own app without changing
/// the shared plan for everyone else.
class WatchPlanVisibilityStore {
  static String _keyFor(String userId) => 'closed_watch_plan_ids_$userId';

  static Future<Set<String>> closedPlanIds(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(_keyFor(userId))?.toSet() ?? <String>{};
  }

  static Future<void> closePlan(String userId, String planId) async {
    final preferences = await SharedPreferences.getInstance();
    final ids = await closedPlanIds(userId);
    ids.add(planId);
    await preferences.setStringList(_keyFor(userId), ids.toList());
  }
}
