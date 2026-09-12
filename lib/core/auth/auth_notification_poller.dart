import 'dart:async';

class AuthNotificationPoller {
  Timer? _timer;
  bool _running = false;

  void start(
      {required Duration interval, required Future<void> Function() onTick}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) async {
      if (_running) return;
      _running = true;
      try {
        await onTick().timeout(const Duration(seconds: 20));
      } catch (_) {/* A subsequent tick may retry. */} finally {
        _running = false;
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
