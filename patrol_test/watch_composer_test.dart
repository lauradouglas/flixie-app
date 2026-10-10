import 'package:patrol/patrol.dart';
import 'support/watch_composer_journeys.dart';

void main() =>
    watchComposerJourneys((name, journey) => patrolTest(name, journey));
