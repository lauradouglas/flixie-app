import 'package:patrol/patrol.dart';
import '../test/features/pick_for_us/people_baseline_test.dart'
    show viewerJourney;

void main() {
  patrolTest('Picker loads only selected viewers and reuses them', ($) async {
    await viewerJourney($.tester);
  });
}
