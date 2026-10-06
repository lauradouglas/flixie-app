import 'package:patrol/patrol.dart';
import '../patrol_test/support/group_watch_plan_journeys.dart';

// The same production UI journeys run headlessly for fast diagnosis and on
// the dedicated iOS simulator through patrol_test/group_watch_plans_test.dart.
void main() {
  groupWatchPlanJourneys((name, journey) => patrolWidgetTest(name, journey));
}
