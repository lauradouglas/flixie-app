import 'package:patrol/patrol.dart';
import 'support/search_journeys.dart';

void main() => searchJourneys((name, journey) => patrolTest(name, journey));
