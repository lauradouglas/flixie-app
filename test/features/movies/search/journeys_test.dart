import 'package:patrol_finders/patrol_finders.dart';
import '../../../../patrol_test/support/search_journeys.dart';

void main() =>
    searchJourneys((name, journey) => patrolWidgetTest(name, journey));
