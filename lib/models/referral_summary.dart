class ReferralSummary {
  const ReferralSummary({
    required this.code,
    required this.referralCount,
    required this.qualifiedReferralCount,
    required this.inviteUrl,
    this.referrals = const [],
  });

  final List<ReferralPerson> referrals;
  final String code;
  final int referralCount;
  final int qualifiedReferralCount;
  final String inviteUrl;

  factory ReferralSummary.fromJson(Map<String, dynamic> json) {
    return ReferralSummary(
      referrals: (json['referrals'] as List? ?? [])
          .whereType<Map>()
          .map((p) => ReferralPerson.fromJson(Map<String, dynamic>.from(p)))
          .toList(),
      code: json['code'] as String,
      referralCount: (json['referralCount'] as num?)?.toInt() ?? 0,
      qualifiedReferralCount:
          (json['qualifiedReferralCount'] as num?)?.toInt() ?? 0,
      inviteUrl: json['inviteUrl'] as String,
    );
  }
}

class ReferralPerson {
  const ReferralPerson(this.displayName, this.qualified);
  final String displayName;
  final bool qualified;
  factory ReferralPerson.fromJson(Map<String, dynamic> json) => ReferralPerson(
      (json['displayName'] ?? json['username'] ?? 'Film friend') as String,
      json['qualified'] == true);
}
