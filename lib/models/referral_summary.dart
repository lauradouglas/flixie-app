class ReferralSummary {
  const ReferralSummary({
    required this.code,
    required this.referralCount,
    required this.qualifiedReferralCount,
    required this.inviteUrl,
  });

  final String code;
  final int referralCount;
  final int qualifiedReferralCount;
  final String inviteUrl;

  factory ReferralSummary.fromJson(Map<String, dynamic> json) {
    return ReferralSummary(
      code: json['code'] as String,
      referralCount: (json['referralCount'] as num?)?.toInt() ?? 0,
      qualifiedReferralCount:
          (json['qualifiedReferralCount'] as num?)?.toInt() ?? 0,
      inviteUrl: json['inviteUrl'] as String,
    );
  }
}
