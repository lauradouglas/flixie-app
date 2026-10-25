import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../../authentication/data/setup_service.dart';

/// Durable device-only picks. Mutations are serialized; failed writes retain data.
class GuestWatchlistStore extends ChangeNotifier {
  List<SetupTitle> _snapshot = [];
  Set<int> get homeKeys =>
      _snapshot.map((p) => p.isShow ? -p.id : p.id).toSet();
  static const storageKey = 'guest_watchlist_v1';
  static final instance = GuestWatchlistStore();
  Future<void>? _pending;
  Future<T> _serial<T>(Future<T> Function() task) async {
    final previous = _pending;
    final gate = Completer<void>();
    _pending = gate.future;
    try {
      if (previous != null) await previous;
      return await task();
    } finally {
      gate.complete();
      if (identical(_pending, gate.future)) _pending = null;
    }
  }

  Future<List<SetupTitle>> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null) {
      _snapshot = [];
      return [];
    }
    final picks = (jsonDecode(raw) as List)
        .map((e) => SetupTitle.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    _snapshot = picks;
    return picks;
  }

  Future<void> _write(List<SetupTitle> picks) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      if (!await prefs.setString(
          storageKey, jsonEncode(picks.map((e) => e.toJson()).toList()))) {
        throw StateError('Could not keep your picks on this device');
      }
    } catch (_) {
      // The legacy preferences API updates its memory cache before disk writes.
      // Reload it so a rejected removal cannot hide an unsaved pick on retry.
      try {
        await prefs.reload();
      } catch (_) {/* Preserve the original error. */}
      rethrow;
    }
    _snapshot = List.of(picks);
    notifyListeners();
  }

  Future<bool> toggle(SetupTitle title) => _serial(() async {
        final picks = await read();
        final added = !picks.any((e) => e.key == title.key);
        picks.removeWhere((e) => e.key == title.key);
        if (added) picks.add(title);
        await _write(picks);
        return added;
      });

  Future<void> remove(String key) => _serial(() async {
        final picks = await read();
        picks.removeWhere((p) => p.key == key);
        await _write(picks);
      });

  /// Remove only acknowledged picks, and stop immediately if the viewer changes.
  Future<List<SetupTitle>> merge(
          {required bool Function() active,
          required Future<void> Function(SetupTitle) save}) =>
      _serial(() async {
        final saved = <SetupTitle>[];
        final picks = await read();
        for (final pick in [...picks]) {
          if (!active()) throw StateError('Account changed');
          await save(pick);
          if (!active()) throw StateError('Account changed');
          picks.removeWhere((e) => e.key == pick.key);
          await _write(picks);
          saved.add(pick);
        }
        return saved;
      });
}
