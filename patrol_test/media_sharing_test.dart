import '../test/features/sharing/external_share_test.dart'
    show externalShareJourney;
import 'package:patrol/patrol.dart';
import '../test/features/sharing/journey.dart';

void main() {
  patrolTest('External movie and show web links from guest and member sharing',
      ($) => externalShareJourney($.tester));
  patrolTest('Share movie to friend with retry and 100 recipients',
      ($) => sendJourney($.tester, group: false));
  patrolTest('Share show to group with retry and 100 recipients',
      ($) => sendJourney($.tester, group: true));
  patrolTest('Dismiss sharing while conversation creation is pending',
      ($) => dismissJourney($.tester));
}
