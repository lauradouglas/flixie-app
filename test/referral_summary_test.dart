import 'package:flutter_test/flutter_test.dart';

import 'package:flixie_app/models/referral_summary.dart';

void main() {
  test('ReferralSummary parses invite details', () {
    final summary = ReferralSummary.fromJson({
      'code': 'FLXABC123456',
      'referralCount': 2,
      'qualifiedReferralCount': 1,
      'inviteUrl': 'https://www.flixie.co.uk/invite?code=FLXABC123456',
    });

    expect(summary.code, 'FLXABC123456');
    expect(summary.referralCount, 2);
    expect(summary.qualifiedReferralCount, 1);
    expect(
      summary.inviteUrl,
      'https://www.flixie.co.uk/invite?code=FLXABC123456',
    );
  });
}
