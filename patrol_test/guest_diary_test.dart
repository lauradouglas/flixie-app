import 'package:patrol/patrol.dart';
import '../test/features/guest/guest_diary_test.dart'
    show guestDiaryContinuation, guestDiaryDraftJourney;

void main() {
  patrolTest('guest writes and previews a film entry before signup', ($) async {
    await guestDiaryDraftJourney($.tester);
  });
  patrolTest(
      'guest diary survives signup and a failed save without duplicate logs',
      ($) async {
    await guestDiaryContinuation($.tester);
  });
}
