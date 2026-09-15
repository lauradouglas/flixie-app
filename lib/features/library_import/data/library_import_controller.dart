import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'library_import_models.dart';

typedef ImportRequest = Future<Map<String, dynamic>> Function(
    String action, Map<String, dynamic> body);

class LibraryImportController extends ChangeNotifier {
  LibraryImportController(
      {required this.userId,
      required this.isCurrentUser,
      ImportRequest? request})
      : _request = request ?? _send;
  final String userId;
  final bool Function() isCurrentUser;
  final ImportRequest _request;
  LibraryImportData? data;
  bool busy = false;
  bool paused = false;
  bool _disposed = false;
  String? error;
  String phase = '';
  bool includeRatings = true;
  bool includeWatchlist = true;
  String get _storageKey => 'library_import_v1_$userId';

  static Future<Map<String, dynamic>> _send(
          String action, Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(await ApiClient.post(
          '/users/me/library-import/$action',
          body: body,
          timeout: Duration(seconds: action == 'commit' ? 90 : 15),
          logRequestBody: false));

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey);
    if (_disposed) return;
    if (stored != null) {
      try {
        final json = jsonDecode(stored) as Map<String, dynamic>;
        data = LibraryImportData.fromJson(json);
        includeRatings = json['includeRatings'] ?? true;
        includeWatchlist = json['includeWatchlist'] ?? true;
      } catch (_) {
        error =
            'The saved preview could not be opened. Choose your export again; any items already imported are safe.';
      }
    }
    _notify();
  }

  Future<void> setData(LibraryImportData value) async {
    data = value;
    includeRatings = true;
    includeWatchlist = true;
    error = null;
    await save();
    _notify();
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    if (data != null) {
      final saved = await prefs.setString(
          _storageKey,
          jsonEncode({
            ...data!.toJson(),
            'includeRatings': includeRatings,
            'includeWatchlist': includeWatchlist
          }));
      if (!saved) throw StateError('Unable to save import progress.');
    }
  }

  Future<void> clear() async {
    if (busy) return;
    await (await SharedPreferences.getInstance()).remove(_storageKey);
    data = null;
    error = null;
    _notify();
  }

  void pause() {
    paused = true;
    _notify();
  }

  bool get _stop => paused || _disposed || !isCurrentUser();
  int get readyCount =>
      data?.rows
          .where((r) =>
              r.status == 'ready' &&
              ((includeRatings && r.rating != null) ||
                  (includeWatchlist && r.watchlist)))
          .length ??
      0;
  int get doneCount => data?.rows.where((r) => r.status == 'done').length ?? 0;
  int get pendingCount =>
      data?.rows.where((r) => r.status == 'pending').length ?? 0;

  Future<void> resolve() async {
    if (busy || data == null) return;
    busy = true;
    paused = false;
    error = null;
    phase = 'Finding your titles';
    _notify();
    try {
      for (final row in data!.rows.where((r) => r.status == 'pending')) {
        if (_stop) break;
        final result =
            await _request('resolve', {...row.lookup(), 'userId': userId});
        row.match = result['match'] == null
            ? null
            : Map<String, dynamic>.from(result['match']);
        row.candidates = (result['candidates'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        row.status = row.match == null ? 'review' : 'ready';
        await save();
        _notify();
      }
    } catch (exception) {
      error = exception is ApiException && exception.statusCode == 404
          ? 'Library matching is temporarily unavailable. Tap Find remaining titles to try again.'
          : exception is ApiException && exception.statusCode >= 500
              ? 'Flixie could not match titles right now. Tap Find remaining titles to try again.'
              : 'Matching paused. Check your connection and tap Find remaining titles to continue.';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> commit() async {
    if (busy || data == null || readyCount == 0) return;
    busy = true;
    paused = false;
    error = null;
    phase = 'Bringing your library over';
    _notify();
    try {
      await save();
      for (final row in data!.rows.where((r) => r.status == 'ready')) {
        if (_stop) break;
        if ((!includeRatings || row.rating == null) &&
            (!includeWatchlist || !row.watchlist)) {
          continue;
        }
        final result = await _request('commit', {
          'userId': userId,
          'id': row.match!['id'],
          'mediaType': row.match!['mediaType'],
          if (includeRatings && row.rating != null) 'rating': row.rating,
          if (includeRatings && row.rating != null && row.ratingDate != null)
            'ratingDate': row.ratingDate,
          'watchlist': includeWatchlist && row.watchlist,
        });
        row.result = result;
        row.status = 'done';
        await save();
        _notify();
      }
    } catch (exception) {
      error = exception is ApiException && exception.statusCode >= 500
          ? 'Import paused because Flixie is temporarily unavailable. Your saved items are safe. Tap Import remaining titles to retry.'
          : 'Import paused. Your saved items are safe. Check your connection and tap Import remaining titles to retry.';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<List<Map<String, dynamic>>> search(
      String title, String mediaType) async {
    if (!isCurrentUser()) throw StateError('Sign in to continue.');
    final result = await _request(
        'resolve', {'title': title, 'mediaType': mediaType, 'userId': userId});
    return (result['candidates'] as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> select(
      LibraryImportRow row, Map<String, dynamic>? candidate) async {
    row.match = candidate;
    row.status = candidate == null ? 'skipped' : 'ready';
    await save();
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    paused = true;
    super.dispose();
  }
}
