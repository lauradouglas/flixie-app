import '../test/features/profile/profile_recovery_test.dart'
    show historyMediaJourney;
import 'package:patrol/patrol.dart';
import '../test/features/profile/featured_people_test.dart'
    show featuredPeopleJourney;

void main() {
  patrolTest('profile history opens watched shows', ($) async {
    await historyMediaJourney($.tester);
  });
  patrolTest('profile featured people choose clear and view all', ($) async {
    await featuredPeopleJourney($.tester);
  });
}
