import 'package:patrol/patrol.dart';
import '../test/features/referrals/referral_visibility_test.dart'
    show savedFilmInviteJourney;

void main() {
  patrolTest(
      'saved film invitation retains the companion and original entry through retry',
      ($) async {
    await savedFilmInviteJourney($.tester);
  });
}
