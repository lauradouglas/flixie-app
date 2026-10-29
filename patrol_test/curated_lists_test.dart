import 'package:patrol/patrol.dart';
import '../test/features/curated_lists/curated_list_page_test.dart'
    show curatedWatchRewardJourney;

void main() {
  patrolTest(
      'curated list diary watch unlocks Pip and border; Pip selection remains explicit',
      ($) async {
    await curatedWatchRewardJourney($.tester);
  });
}
