import 'dart:io';

import 'package:flutter/services.dart';

class AppIconBadgeService {
  AppIconBadgeService._();

  static const MethodChannel _channel = MethodChannel('flixie/app_badge');

  static Future<void> setCount(int count) async {
    if (!Platform.isIOS) return;
    final safeCount = count < 0 ? 0 : count;
    try {
      await _channel.invokeMethod<void>('setCount', {'count': safeCount});
    } on MissingPluginException {
      // The native channel may be unavailable briefly during engine startup,
      // or permanently in test/headless builds. Badge updates are best-effort.
    } on PlatformException {
      // Badge updates are best-effort and should never break app flow.
    }
  }

  static Future<void> clear() => setCount(0);
}
