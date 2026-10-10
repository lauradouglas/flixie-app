import 'package:patrol/patrol.dart';
import '../test/features/movies/add_to_list/journey.dart';

void main() {
  patrolTest('Add to List collaborator retry, create, save and undo',
      ($) async {
    await addToListJourney($.tester,
        retry: true, saveAndUndo: true, membershipRetry: true);
  });
}
