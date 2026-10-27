import 'package:patrol/patrol.dart';
import '../test/features/pip/pip_collection_test.dart' show pipChoiceJourney;

void main() {
  patrolTest('Pip outfit and icon preserve choices through failed saves',
      ($) async {
    await pipChoiceJourney($.tester);
  });
}
