import 'dart:async';

class AuthNotificationPoller {
  Timer? _timer;

  void start({required Duration interval, required Future<void> Function() onTick}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => onTick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
