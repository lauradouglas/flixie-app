import 'dart:math';

class PopcornChallenge {
  const PopcornChallenge(
      {required this.id,
      required this.score,
      required this.senderId,
      required this.recipientId,
      required this.senderName,
      required this.recipientName,
      required this.sourceRoundId,
      this.attemptRoundId,
      this.resultScore,
      this.attemptStarted = false,
      this.expiresAt,
      this.version = 2,
      this.roundReached = 1,
      this.resultRoundReached});
  final String id,
      senderId,
      recipientId,
      senderName,
      recipientName,
      sourceRoundId;
  final String? attemptRoundId;
  final int score, version, roundReached;
  final int? resultRoundReached;
  final int? resultScore;
  final bool attemptStarted;
  final DateTime? expiresAt;
  factory PopcornChallenge.fromJson(Map<String, dynamic> j) => PopcornChallenge(
      id: j['id'] as String,
      version: j['version'] as int? ?? 2,
      roundReached: j['roundReached'] as int? ?? 1,
      resultRoundReached: j['resultRoundReached'] as int?,
      score: j['score'] as int,
      senderId: j['senderId'] as String,
      recipientId: j['recipientId'] as String,
      senderName: j['senderName'] as String,
      recipientName: j['recipientName'] as String,
      sourceRoundId: j['sourceRoundId'] as String,
      attemptRoundId: j['attemptRoundId'] as String?,
      resultScore: j['resultScore'] as int?,
      attemptStarted: j['attemptStarted'] == true,
      expiresAt: DateTime.tryParse(j['expiresAt'] as String? ?? ''));
  String get resultLabel => resultScore == null
      ? 'Beat my score'
      : resultScore! > score
          ? 'Beat you!'
          : resultScore == score
              ? 'Matched your score!'
              : 'Tried to beat you!';
}

String popcornRequestKey() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}
