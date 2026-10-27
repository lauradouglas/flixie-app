import 'package:patrol/patrol.dart';
import '../test/features/profile/diary/diary_editing_test.dart'
    show diaryMemoryJourney;

void main() {
  patrolTest(
      'diary memory adds a companion and retains edits through save retry',
      ($) async {
    await diaryMemoryJourney($.tester);
  });
}
