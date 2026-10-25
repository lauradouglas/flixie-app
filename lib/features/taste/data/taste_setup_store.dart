import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Optional setup state belongs to an account, never to the shared device guest.
class TasteSetupStore {
  const TasteSetupStore();
  static final changes = ValueNotifier<int>(0);
  String key(String id, String field) => 'build_taste_v1:$id:$field';
  Future<bool> eligible(String id) async =>
      (await SharedPreferences.getInstance()).getBool(key(id, 'eligible')) ??
      false;
  Future<bool> hidden(String id) async =>
      (await SharedPreferences.getInstance()).getBool(key(id, 'hidden')) ??
      false;
  Future<String> step(String id) async =>
      (await SharedPreferences.getInstance()).getString(key(id, 'step')) ??
      'favourites';
  Future<void> enable(String id) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(key(id, 'eligible')) == true) return;
    if (!await prefs.setBool(key(id, 'eligible'), true)) {
      throw StateError('Could not remember taste setup');
    }
    changes.value++;
  }

  Future<void> hide(String id) async {
    if (!await (await SharedPreferences.getInstance())
        .setBool(key(id, 'hidden'), true)) {
      throw StateError('Could not remember dismissal');
    }
    changes.value++;
  }

  Future<void> saveStep(String id, String step) async {
    if (!await (await SharedPreferences.getInstance())
        .setString(key(id, 'step'), step)) {
      throw StateError('Could not remember your place');
    }
    changes.value++;
  }
}
