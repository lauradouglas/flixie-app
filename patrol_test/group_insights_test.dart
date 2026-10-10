import 'package:patrol/patrol.dart';
import 'support/group_insights_journeys.dart';

void main() =>
    groupInsightsJourneys((name, journey) => patrolTest(name, journey));
