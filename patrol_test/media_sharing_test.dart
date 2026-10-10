import 'package:patrol/patrol.dart';
import '../test/features/sharing/journey.dart';

void main() {
  patrolTest('Share movie to friend with retry and 100 recipients',
      ($) => sendJourney($.tester, group: false));
  patrolTest('Share show to group with retry and 100 recipients',
      ($) => sendJourney($.tester, group: true));
  patrolTest('Dismiss sharing while conversation creation is pending',
      ($) => dismissJourney($.tester));
}
