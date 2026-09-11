import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/friend_plan/friend_watch_plan_flow.dart';
import 'package:flixie_app/models/watch_request.dart';

WatchRequest fixture([Map<String, dynamic> changes = const {}]) => WatchRequest.fromJson({
  'id': 'plan', 'requesterId': 'laura', 'recipientId': 'me', 'status': 'ACCEPTED',
  'type': 'MOVIE_WATCH_REQUEST', 'message': 'Fancy a movie night?',
  'requester': {'id': 'laura', 'username': 'Laura'},
  'recipient': {'id': 'me', 'username': 'You'},
  'candidates': [
    {'id': 'moana', 'movieId': 1, 'movie': {'id': 1, 'title': 'Moana'}, 'addedByUserId': 'laura', 'choices': [{'userId': 'me'}, {'userId': 'laura'}]},
    {'id': 'pretty', 'movieId': 2, 'movie': {'id': 2, 'title': 'Pretty Woman'}, 'addedByUserId': 'me', 'choices': [{'userId': 'me'}]},
  ], ...changes,
});

void main() {
  setUpAll(() async {
    final font = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  Future<void> show(WidgetTester tester, WatchRequest request, {
    VoidCallback? accept, ValueChanged<String>? select,
    Future<bool> Function()? save, double width = 390, double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.darkTheme,
      home: MediaQuery(data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16),
          child: FriendWatchPlanFlow(request: request, myUserId: 'me', compact: false,
            scheduledLabel: '18 Sep, 21:30', onOpen: () {}, onAccept: accept ?? () {},
            onDecline: () {}, onSuggestSchedule: () {}, onRespondToProposal: (_, __) {},
            onConfirmWatched: () {}, onNotThisTime: () {}, onClosePlan: () {},
            onNewPlan: () {}, onCancelPlan: () {}, candidateChoiceDraft: const {'moana'},
            onToggleCandidateChoice: (_) {}, onSaveCandidateChoices: save ?? () async => true,
            onAddCandidate: () {}, onRemoveCandidate: (_) {},
            onSelectCandidate: select ?? (_) {}, onChangeMovie: () {},
          ),
        )),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('joining an invite does not select a movie', (tester) async {
    var accepted = 0;
    var selected = 0;
    await show(tester, fixture({'status': 'PENDING'}), accept: () => accepted++, select: (_) => selected++);
    expect(find.text('JOIN THE PLAN'), findsOneWidget);
    await tester.tap(find.text('I’m in'));
    expect(accepted, 1);
    expect(selected, 0);
  });

  testWidgets('movie interests advance only after a successful save', (tester) async {
    var succeeds = false;
    await show(tester, fixture(), save: () async => succeeds);
    await tester.ensureVisible(find.text('Save my picks'));
    await tester.tap(find.text('Save my picks'));
    await tester.pumpAndSettle();
    expect(find.text('PICK MOVIES'), findsOneWidget);
    succeeds = true;
    await tester.tap(find.text('Save my picks'));
    await tester.pumpAndSettle();
    expect(find.text('WAITING FOR CREATOR'), findsOneWidget);
    expect(find.text('Choose'), findsNothing);
  });

  testWidgets('only the creator sees final movie actions', (tester) async {
    await show(tester, fixture({'proposedCandidateId': 'moana', 'movieProposedById': 'laura'}));
    expect(find.text('Choose'), findsNothing);
    String? selected;
    await show(tester, fixture({'requesterId': 'me', 'recipientId': 'laura',
      }), select: (id) => selected = id);
    expect(find.text('Save my picks'), findsNothing);
    expect(find.text('Edit my picks'), findsNothing);
    expect(find.text('Choose'), findsNWidgets(2));
    await tester.tap(find.text('Choose').first);
    expect(selected, 'moana');
  });

  testWidgets('pending time agreement takes precedence over an older schedule', (tester) async {
    await show(tester, fixture({'selectedCandidateId': 'moana', 'scheduleStatus': 'AGREED',
      'scheduledFor': '2099-09-18T21:30:00Z', 'scheduleProposals': [
        {'id': 'time', 'proposerId': 'laura', 'status': 'PENDING', 'proposedFor': '2099-09-19T21:30:00Z'}
      ]}));
    expect(find.text('AGREE ON A TIME'), findsOneWidget);
    expect(find.text('Works for me'), findsWidgets);
    expect(find.text('Add to calendar'), findsNothing);
  });

  testWidgets('one person missing the watch does not block the other from logging', (tester) async {
    await show(tester, fixture({'selectedCandidateId': 'moana', 'scheduleStatus': 'AGREED',
      'scheduledFor': '2020-09-18T21:30:00Z', 'watchConfirmations': [
        {'userId': 'laura', 'watched': false}
      ]}));
    expect(find.text('AFTER THE WATCH'), findsOneWidget);
    expect(find.text('Log your watch'), findsOneWidget);
    expect(find.text('Didn’t make it'), findsOneWidget);
  });

  testWidgets('recap excludes missed attendance and does not infer recommendations from ratings', (tester) async {
    await show(tester, fixture({'status': 'COMPLETED', 'selectedCandidateId': 'moana', 'watchConfirmations': [
      {'userId': 'me', 'watched': true, 'rating': 9, 'recommended': false},
      {'userId': 'laura', 'watched': false, 'rating': 10, 'recommended': true},
    ]}));
    expect(find.text('9.0 / 10'), findsOneWidget);
    expect(find.text('1 rating'), findsOneWidget);
    expect(find.text('Both recommend it'), findsNothing);
    expect(find.text('1 recommends it'), findsNothing);
  });

  testWidgets('picking reflows on a small phone with large text and on tablet', (tester) async {
    for (final size in [(320.0, 2.0), (800.0, 1.0)]) {
      await show(tester, fixture(), width: size.$1, scale: size.$2);
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
