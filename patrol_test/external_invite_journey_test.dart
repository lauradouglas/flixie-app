import 'package:patrol/patrol.dart';
import '../test/features/movies/external_watch_invite_test.dart'
    show externalGuestJourney;

void main() {
  patrolTest(
      'external film invitation keeps an independent guest entry through signup and retry',
      ($) async {
    await externalGuestJourney($.tester);
  });
}
