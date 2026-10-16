enum ActivityReaction {
  love('❤️', 'Love', 'hand_heart'),
  like('👍', 'Thumbs up', 'thumbs_up'),
  dislike('👎', 'Thumbs down', 'thumbs_down'),
  angry('😡', 'Angry', 'angry'),
  hotTake('🌶️', 'Hot take', 'hot_take'),
  crying('😭', 'Crying', 'crying'),
  laugh('😂', 'Laughing', 'laughing'),
  sus('🤨', 'Sus', 'sus'),
  greatPick('🔥', 'Flames', 'flames'),
  agree('💯', '100%', '100_percent'),
  interested('👀', 'Interested / want to watch', 'interested'),
  surprised('😮', 'Surprised', 'surprised');

  const ActivityReaction(this.emoji, this.label, this.assetName);
  final String emoji, label, assetName;
  String get asset => 'assets/icon/pip_emote_$assetName.png';
  static const selectable = [
    love,
    like,
    dislike,
    angry,
    hotTake,
    crying,
    laugh,
    sus,
    greatPick,
    agree,
    interested,
    surprised,
  ];
  static ActivityReaction? fromEmoji(String value) {
    for (final reaction in values) {
      if (reaction.emoji == value) return reaction;
    }
    return null;
  }
}

class ActivityReactionSummary {
  const ActivityReactionSummary({this.counts = const {}, this.mine});
  final Map<String, int> counts;
  final String? mine;
  factory ActivityReactionSummary.fromJson(Map<String, dynamic> json) =>
      ActivityReactionSummary(
        counts: (json['counts'] as Map? ?? {}).map(
            (key, value) => MapEntry(key.toString(), (value as num).toInt())),
        mine: json['mine'] as String?,
      );
  ActivityReactionSummary selecting(String? emoji) {
    final updated = Map<String, int>.of(counts);
    if (mine != null) {
      updated[mine!] = ((updated[mine!] ?? 1) - 1).clamp(0, 999999);
    }
    if (emoji != null) updated[emoji] = (updated[emoji] ?? 0) + 1;
    return ActivityReactionSummary(counts: updated, mine: emoji);
  }
}

// Existing API values remain readable; no stored-reaction migration is needed.
const reviewActivityReactions = {
  'love': ActivityReaction.love,
  'like': ActivityReaction.like,
  'dislike': ActivityReaction.dislike,
  'angry': ActivityReaction.angry,
  'hot_take': ActivityReaction.hotTake,
  'crying': ActivityReaction.crying,
  'funny': ActivityReaction.laugh,
  'hmm': ActivityReaction.sus,
  'fire': ActivityReaction.greatPick,
  'agree': ActivityReaction.agree,
  'interested': ActivityReaction.interested,
  'surprised': ActivityReaction.surprised,
};

String reviewReactionEmoji(String key) =>
    reviewActivityReactions[key]?.emoji ?? key;
