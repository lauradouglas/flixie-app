import 'dart:convert';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/popcorn_leaderboard.dart';
import '../models/popcorn_challenge.dart';

class PopcornService {
  static const path = '/games/popcorn-catch/v3';
  Future<PopcornRound> start() async {
    final json = await ApiClient.post('$path/rounds', body: <String, dynamic>{})
        as Map<String, dynamic>;
    if (![2, 3].contains(json['version']) || json['ticks'] != 600) {
      throw StateError('Update Flixie to play this round.');
    }
    return PopcornRound(json['id'] as String, json['seed'] as int,
        personalBest: json['personalBest'] as int?,
        version: json['version'] as int);
  }

  Future<PopcornRound> startGuest() async {
    final json = await ApiClient.post('/guest/games/popcorn-catch/rounds',
        body: <String, dynamic>{}) as Map<String, dynamic>;
    if (json['version'] != 3 || json['ticks'] != 600) {
      throw StateError('Update Flixie to play this round.');
    }
    return PopcornRound(json['id'] as String, json['seed'] as int,
        version: 3,
        guestToken: json['token'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String));
  }

  Future<PopcornRound> claimGuest(PopcornRound round) async {
    final json = await ApiClient.post('$path/guest-rounds/${round.id}/claim',
        body: {'token': round.guestToken}) as Map<String, dynamic>;
    if (json['id'] != round.id ||
        json['seed'] != round.seed ||
        json['version'] != 3) {
      throw StateError('Guest round mismatch');
    }
    return PopcornRound(round.id, round.seed, version: 3);
  }

  static const _guestScoreKey = 'popcorn.pendingGuestScore.v1';
  Future<void> rememberGuestScore(PopcornRound round, List<int> targets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _guestScoreKey,
        jsonEncode({
          'id': round.id,
          'seed': round.seed,
          'token': round.guestToken,
          'expiresAt': round.expiresAt?.toIso8601String(),
          'targets': targets
        }));
  }

  Future<(PopcornRound, List<int>)?> pendingGuestScore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_guestScoreKey);
    if (saved == null) return null;
    try {
      final json = jsonDecode(saved) as Map<String, dynamic>;
      final expiry = DateTime.parse(json['expiresAt'] as String);
      if (!expiry.isAfter(DateTime.now())) {
        await prefs.remove(_guestScoreKey);
        return null;
      }
      return (
        PopcornRound(json['id'] as String, json['seed'] as int,
            version: 3, guestToken: json['token'] as String, expiresAt: expiry),
        List<int>.from(json['targets'] as List)
      );
    } catch (_) {
      await prefs.remove(_guestScoreKey);
      return null;
    }
  }

  Future<void> clearGuestScore(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_guestScoreKey);
    if (saved != null &&
        (jsonDecode(saved) as Map<String, dynamic>)['id'] == id) {
      await prefs.remove(_guestScoreKey);
    }
  }

  String _pendingKey(String userId, String id) =>
      'popcorn.firstResult.$userId.$id';
  Future<void> rememberReply(
      String userId, String id, List<int> targets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _pendingKey(userId, id), targets.map((t) => '$t').toList());
  }

  Future<List<int>?> pendingReply(String userId, String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs
        .getStringList(_pendingKey(userId, id))
        ?.map(int.parse)
        .toList();
  }

  Future<void> clearReply(String userId, String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey(userId, id));
  }

  Future<int> verify(PopcornRound round, List<int> targets) async {
    final json = await ApiClient.post(
        '/games/popcorn-catch/v${round.version}/rounds/${round.id}/verify',
        body: {'targets': targets}) as Map<String, dynamic>;
    return json['score'] as int;
  }

  Future<PopcornChallenge> challenge(String id) async =>
      PopcornChallenge.fromJson(
          await ApiClient.get('$path/challenges/$id') as Map<String, dynamic>);
  Future<PopcornChallenge> share(
          String roundId, String recipientId, String requestKey) async =>
      PopcornChallenge.fromJson(await ApiClient.post('$path/challenges', body: {
        'roundId': roundId,
        'recipientId': recipientId,
        'requestKey': requestKey
      }) as Map<String, dynamic>);
  Future<PopcornRound> startChallenge(String id) async {
    final json = await ApiClient.post('$path/challenges/$id/start',
        body: <String, dynamic>{}) as Map<String, dynamic>;
    if (![2, 3].contains(json['version']) || json['ticks'] != 600) {
      throw StateError('Update Flixie to take this challenge.');
    }
    return PopcornRound(json['id'] as String, json['seed'] as int,
        personalBest: json['personalBest'] as int?,
        version: json['version'] as int);
  }

  Future<int> reply(String id, List<int> targets) async {
    final json = await ApiClient.post('$path/challenges/$id/score',
        body: {'targets': targets}) as Map<String, dynamic>;
    return json['score'] as int;
  }

  Future<int> submit(PopcornRound round, List<int> targets) async {
    final json = await ApiClient.post(
        '/games/popcorn-catch/v${round.version}/rounds/${round.id}/score',
        body: {'targets': targets}) as Map<String, dynamic>;
    return json['score'] as int;
  }

  Future<PopcornLeaderboard> leaderboard() async => PopcornLeaderboard.fromJson(
      await ApiClient.get('$path/leaderboard') as Map<String, dynamic>);
  Future<void> removeScore() async => ApiClient.delete('$path/leaderboard/me');
}
