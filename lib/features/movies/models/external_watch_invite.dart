class ExternalWatchCompanion {
  const ExternalWatchCompanion(this.name);
  final String name;
}

class ExternalWatchInvite {
  const ExternalWatchInvite(
      {required this.id,
      required this.displayName,
      this.claimed = false,
      this.expiresAt,
      this.revoked = false});
  final String id, displayName;
  final bool claimed, revoked;
  final DateTime? expiresAt;
  bool get available => !claimed && !revoked;
  factory ExternalWatchInvite.fromJson(Map<String, dynamic> json) =>
      ExternalWatchInvite(
          id: json['id'] as String,
          displayName: json['displayName'] as String,
          claimed: json['claimedById'] != null,
          expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ?? ''),
          revoked: json['revokedAt'] != null);
  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        if (claimed) 'claimedById': 'claimed',
        'expiresAt': expiresAt?.toIso8601String(),
        if (revoked) 'revokedAt': 'revoked'
      };
}
