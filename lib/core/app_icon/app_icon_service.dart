import 'package:flutter/services.dart';
import 'package:flixie_app/models/user.dart';

/// Native launcher artwork, with entitlement supplied by the signed-in profile.
class AppIconService {
  AppIconService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('flixie/app_icon');
  static final instance = AppIconService();
  final MethodChannel _channel;
  Future<void> _pending = Future<void>.value();
  User? _user;

  static bool eligible(User? user) =>
      user?.profileBadges.any(
        (badge) => badge == 'FOUNDER' || badge == 'EARLY_ADOPTER',
      ) ??
      false;

  Future<Map<dynamic, dynamic>> status() async =>
      await _channel.invokeMapMethod<dynamic, dynamic>('status') ??
      {'supported': false, 'selected': 'default'};

  void updateUser(User? user) {
    _user = user;
    if (!eligible(user)) {
      _enqueue(() async {
        final current = await status();
        if (!eligible(_user) && current['selected'] != 'default') {
          await _channel.invokeMethod<void>('set', 'default');
        }
      }).catchError((Object _) {
        // Retry on the next profile update or app resume.
      });
    }
  }

  Future<void> select(String icon) {
    if (icon != 'default' && icon != 'pipGlasses' && icon != 'pipHoodie') {
      return Future<void>.error(ArgumentError.value(icon));
    }
    final owner = _user?.id;
    return _enqueue(() async {
      if (icon != 'default' && (!eligible(_user) || _user?.id != owner)) {
        throw StateError(
            'This icon is available to First 100 and Founder members.');
      }
      await _channel.invokeMethod<void>('set', icon);
    });
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final operation = _pending.then((_) => action());
    _pending = operation.catchError((Object _) {});
    return operation;
  }
}
