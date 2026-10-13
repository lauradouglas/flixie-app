import 'package:patrol/patrol.dart';
import '../test/core/widgets/pip_reaction_test.dart' show pipReactionJourney;

void main() {
  patrolTest('Pip reactions and reply remain reachable on a small phone',
      ($) => pipReactionJourney($.tester));
}
