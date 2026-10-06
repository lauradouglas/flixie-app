import 'package:patrol/patrol.dart';
import 'support/group_watch_plan_journeys.dart';

void main() {
  groupWatchPlanJourneys(
      (name, journey) => patrolTest(name, ($) => journey($)));
}
