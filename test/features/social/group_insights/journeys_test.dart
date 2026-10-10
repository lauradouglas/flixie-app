import 'package:patrol/patrol.dart';
import '../../../../patrol_test/support/group_insights_journeys.dart';

void main() =>
    groupInsightsJourneys((name, journey) => patrolWidgetTest(name, journey));
