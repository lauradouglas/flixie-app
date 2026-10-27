import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/guest_diary_draft.dart';

/// Serialized read/modify/write operations keep rapid edits and auth claims safe.
class GuestDiaryStore {
  static GuestDiaryStore instance = GuestDiaryStore();
  static const key = 'guest_diary_v1';
  Future<void>? _tail;
  Future<T> _transaction<T>(
      Future<T> Function(SharedPreferences, Map<String, dynamic>) operation) {
    final result = (_tail ?? Future<void>.value()).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      final data = raw == null
          ? <String, dynamic>{'drafts': <String, dynamic>{}}
          : Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return operation(prefs, data);
    });
    late final Future<void> tail;
    void finished() {
      if (identical(_tail, tail)) _tail = null;
    }

    tail = result.then<void>((_) => finished(),
        onError: (Object _, StackTrace __) => finished());
    _tail = tail;
    return result;
  }

  Future<void> _write(
      SharedPreferences prefs, Map<String, dynamic> data) async {
    if (!await prefs.setString(key, jsonEncode(data))) {
      throw StateError('Draft storage unavailable');
    }
  }

  Future<List<GuestDiaryDraft>> list(String? user) =>
      _transaction((_, data) async => (data['drafts'] as Map)
          .values
          .map((j) =>
              GuestDiaryDraft.fromJson(Map<String, dynamic>.from(j as Map)))
          .where((d) => d.owner == null || d.owner == user)
          .toList());
  Future<GuestDiaryDraft?> read(String id, String? user) async =>
      (await list(user)).where((d) => d.id == id).firstOrNull;
  Future<void> save(GuestDiaryDraft draft) => _transaction((prefs, data) async {
        final drafts = data['drafts'] as Map;
        final old = drafts[draft.id];
        if (old != null && old['owner'] != draft.owner) {
          throw StateError('This draft belongs to another session');
        }
        drafts[draft.id] = {
          ...draft.toJson(),
          if (old?['watchRequestId'] != null)
            'watchRequestId': old['watchRequestId']
        };
        await _write(prefs, data);
      });
  Future<void> beginSignup(String id) => _transaction((prefs, data) async {
        if (!(data['drafts'] as Map).containsKey(id)) {
          throw StateError('Missing draft');
        }
        data['pending'] = id;
        await _write(prefs, data);
      });
  Future<GuestDiaryDraft?> claim(String user) =>
      _transaction((prefs, data) async {
        final raw = (data['drafts'] as Map)[data['pending']];
        if (raw == null) return null;
        final draft =
            GuestDiaryDraft.fromJson(Map<String, dynamic>.from(raw as Map));
        if (draft.owner != null && draft.owner != user) return null;
        final bound = draft.withOwner(user);
        (data['drafts'] as Map)[draft.id] = bound.toJson();
        if (draft.owner == null) await _write(prefs, data);
        return bound;
      });
  Future<void> finish(String id, String user) =>
      _transaction((prefs, data) async {
        final raw = (data['drafts'] as Map)[id];
        if (raw != null && raw['owner'] != user) {
          throw StateError('Account changed');
        }
        (data['drafts'] as Map).remove(id);
        if (data['pending'] == id) data.remove('pending');
        await _write(prefs, data);
      });
  Future<void> discard(String id, String? user) =>
      _transaction((prefs, data) async {
        final raw = (data['drafts'] as Map)[id];
        if (raw == null) return;
        if (raw['owner'] != null && raw['owner'] != user) {
          throw StateError('Account changed');
        }
        if (raw['submitted'] == true) {
          throw StateError('Retry this save before removing the draft');
        }
        (data['drafts'] as Map).remove(id);
        if (data['pending'] == id) data.remove('pending');
        await _write(prefs, data);
      });
  Future<void> pause(String id) => _transaction((prefs, data) async {
        if (data['pending'] == id) {
          data.remove('pending');
          await _write(prefs, data);
        }
      });
}
