import 'package:patrol/patrol.dart';
import '../../../../patrol_test/support/watch_composer_journeys.dart';

void main() =>
    watchComposerJourneys((name, journey) => patrolWidgetTest(name, journey));
