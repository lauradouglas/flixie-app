enum ActivityReaction {
  love('❤️', 'Love this'),
  interested('👀', 'Interested / want to watch'),
  greatPick('🔥', 'Great pick'),
  laugh('😂', 'That made me laugh'),
  surprised('😮', 'Surprised'),
  agree('💯', 'Strongly agree'),
  dislike('👎', 'Not for me');

  const ActivityReaction(this.emoji, this.label);
  final String emoji, label;
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
