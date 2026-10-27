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
  bool? _cinemaUnlocked;

  void updateCinemaEntitlement(String owner, bool unlocked) {
    if (_user?.id != owner) return;
    _cinemaUnlocked = unlocked;
    _resetUnavailable();
  }

  bool _allowed(String? icon) =>
      icon == 'default' ||
      (icon == 'pipPeeksIn'
          ? _user != null && _cinemaUnlocked != false
          : eligible(_user));

  void _resetUnavailable() {
    _enqueue(() async {
      final current = await status();
      if (!_allowed(current['selected'] as String?)) {
        await _channel.invokeMethod<void>('set', 'default');
      }
    }).catchError((Object _) {});
  }

  static bool eligible(User? user) =>
      user?.profileBadges.any(
        (badge) => badge == 'FOUNDER' || badge == 'EARLY_ADOPTER',
      ) ??
      false;

  Future<Map<dynamic, dynamic>> status() async =>
      await _channel.invokeMapMethod<dynamic, dynamic>('status') ??
      {'supported': false, 'selected': 'default'};

  void updateUser(User? user) {
    if (user?.id != _user?.id) _cinemaUnlocked = null;
    _user = user;
    _resetUnavailable();
  }

  Future<void> select(String icon) {
    if (icon != 'default' &&
        icon != 'pipGlasses' &&
        icon != 'pipHoodie' &&
        icon != 'pipPeeksIn') {
      return Future<void>.error(ArgumentError.value(icon));
    }
    final owner = _user?.id;
    return _enqueue(() async {
      if (icon != 'default' &&
          ((icon == 'pipPeeksIn'
                  ? _cinemaUnlocked != true
                  : !eligible(_user)) ||
              _user?.id != owner)) {
        throw StateError('Unlock this icon before choosing it.');
      }
      await _channel.invokeMethod<void>('set', icon);
      if (_user?.id != owner) {
        await _channel.invokeMethod<void>('set', 'default');
        throw StateError('Account changed.');
      }
    });
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final operation = _pending.then((_) => action());
    _pending = operation.catchError((Object _) {});
    return operation;
  }
}
