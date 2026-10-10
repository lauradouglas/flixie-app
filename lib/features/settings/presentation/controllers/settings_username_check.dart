import 'dart:async';
import 'package:flutter/foundation.dart';

/// Owns the editor's debounce and ignores results for superseded input.
class SettingsUsernameCheck extends ChangeNotifier {
  SettingsUsernameCheck({required this.original, required this.exists});

  final String original;
  final Future<bool> Function(String) exists;
  Timer? _timer;
  int _revision = 0;
  bool _disposed = false;
  bool checking = false;
  String? error;

  void update(String value) {
    final revision = ++_revision;
    _timer?.cancel();
    final username = value.trim();
    checking = false;
    error = null;
    if (username != original) {
      if (username.length < 3) {
        error = 'At least 3 characters required';
      } else {
        checking = true;
        _timer = Timer(const Duration(milliseconds: 600), () async {
          try {
            final taken = await exists(username);
            if (_disposed || revision != _revision) return;
            error = taken ? 'Username already taken' : null;
          } catch (_) {
            if (_disposed || revision != _revision) return;
          }
          checking = false;
          notifyListeners();
        });
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    _timer?.cancel();
    super.dispose();
  }
}
