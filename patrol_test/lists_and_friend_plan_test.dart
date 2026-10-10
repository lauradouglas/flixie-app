import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/friend_plan/friend_watch_plan_flow.dart';
import '../test/friend_watch_plan_flow_test.dart' show fixture;
import '../test/features/movies/add_to_list/journey.dart' show addToListJourney;

void main() {
  patrolTest('TV lists retry, create, save and undo', ($) async {
    await addToListJourney($.tester,
        show: true, retry: true, membershipRetry: true, saveAndUndo: true);
  });
  patrolTest('Friend plan saves choices before review and edits its recap',
      ($) async {
    var saves = 0, edits = 0;
    Future<void> mount({bool recap = false}) async {
      final request = fixture(recap
          ? {
              'status': 'COMPLETED',
              'selectedCandidateId': 'moana',
              'watchConfirmations': [
                {'userId': 'me', 'watched': true, 'rating': 9},
                {'userId': 'laura', 'watched': true}
              ]
            }
          : {});
      await $.tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
              body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: FriendWatchPlanFlow(
                    request: request,
                    myUserId: 'me',
                    compact: false,
                    scheduledLabel: 'Tomorrow',
                    onOpen: () {},
                    onAccept: () {},
                    onDecline: () {},
                    onSuggestSchedule: () {},
                    onRespondToProposal: (_, __) {},
                    onConfirmWatched: () => edits++,
                    onNotThisTime: () {},
                    onClosePlan: () {},
                    onNewPlan: () {},
                    onCancelPlan: () {},
                    candidateChoiceDraft: const {'moana'},
                    onToggleCandidateChoice: (_) {},
                    onSaveCandidateChoices: () async => ++saves > 1,
                    onAddCandidate: () {},
                    onRemoveCandidate: (_) {},
                    onSelectCandidate: (_) {},
                    onChangeMovie: () {},
                  )))));
      await $.tester.pumpAndSettle();
    }

    await mount();
    await $.tester.ensureVisible(find.text('Save my picks'));
    await $.tester.tap(find.text('Save my picks'));
    await $.tester.pumpAndSettle();
    expect(find.text('Save my picks'), findsOneWidget);
    await $.tester.tap(find.text('Save my picks'));
    await $.tester.pumpAndSettle();
    expect(find.text('Your picks are saved. Laura will finalise the movie.'),
        findsOneWidget);
    await mount(recap: true);
    expect(find.text('2 watched'), findsOneWidget);
    await $.tester.ensureVisible(find.text('Add your thoughts'));
    await $.tester.tap(find.text('Add your thoughts'));
    await $.tester.pumpAndSettle();
    expect(edits, 1);
    expect(saves, 2);
    expect($.tester.takeException(), isNull);
  });
}
