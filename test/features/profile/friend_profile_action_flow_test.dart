import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/profile/presentation/controllers/friend_profile_controller.dart';
import 'package:flixie_app/features/profile/presentation/friend_profile_action_flow.dart';
import 'package:flixie_app/models/movie_rating.dart';
import 'package:flixie_app/features/profile/presentation/widgets/friend_shared_ratings_sheet.dart';
import 'profile_controller_test.dart' show ProfileAuth;
import 'friend_profile_controller_test.dart' show FriendData, friendUser;

class FriendWrites extends FriendData {
  Completer<void>? gate;
  int writes = 0;
  bool failed = false;
  String? lastStatus;
  Future<void> write() {
    writes++;
    return failed
        ? Future.error(StateError('offline'))
        : gate?.future ?? Future.value();
  }

  @override
  Future<void> sendFriendRequest(Map<String, dynamic> body) => write();
  @override
  Future<void> updateRequest(String id, String status) {
    lastStatus = status;
    return write();
  }

  @override
  Future<void> removeFriend(String viewer, String subject) => write();
}

void main() {
  testWidgets('open shared-ratings sheet clears after subject changes',
      (tester) async {
    final auth = ProfileAuth(), data = FriendWrites();
    final c =
        FriendProfileController(auth: auth, subjectId: 'old', service: data);
    addTearDown(c.dispose);
    addTearDown(auth.dispose);
    c.user = friendUser('old');
    c.sharedRatings = [
      const MovieRating(
          id: 'r',
          userId: 'old',
          movieId: 348,
          rating: 8,
          createdAt: '',
          updatedAt: '')
    ];
    c.myRatingValues = {348: 9};
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () =>
                        showFriendSharedRatings(context, controller: c),
                    child: const Text('Compare'))))));
    await tester.tap(find.text('Compare'));
    await tester.pumpAndSettle();
    expect(find.text('You both rated'), findsOneWidget);
    c.setSubject('new');
    await tester.pumpAndSettle();
    expect(find.text('You both rated'), findsNothing);
    expect(
        find.text('This profile changed. Close and reopen.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final action in ['send', 'accept', 'decline']) {
    testWidgets('$action publishes success and suppresses overlapping writes',
        (tester) async {
      final auth = ProfileAuth(),
          data = FriendWrites()..gate = Completer<void>();
      final c = FriendProfileController(
          auth: auth, subjectId: 'friend', service: data);
      addTearDown(c.dispose);
      addTearDown(auth.dispose);
      c.user = friendUser('friend');
      c.friendshipId = 'request';
      c.friendshipStatus = FriendshipStatus.pending;
      late FriendProfileActionFlow flow;
      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: Builder(builder: (context) {
        flow = FriendProfileActionFlow(context, c);
        return const SizedBox();
      }))));
      Future<void> invoke() => switch (action) {
            'send' => flow.sendFriendRequest(),
            'accept' => flow.acceptRequest(),
            _ => flow.declineRequest()
          };
      final pending = invoke();
      await invoke();
      expect(data.writes, 1);
      expect(c.actionLoading, true);
      data.gate!.complete();
      await pending;
      await tester.pumpAndSettle();
      expect(c.actionLoading, false);
      expect(
          c.friendshipStatus,
          switch (action) {
            'send' => FriendshipStatus.requested,
            'accept' => FriendshipStatus.friends,
            _ => FriendshipStatus.none
          });
    });
  }
  testWidgets('old viewer cannot publish a completed friend request',
      (tester) async {
    final auth = ProfileAuth(), data = FriendWrites()..gate = Completer<void>();
    final c =
        FriendProfileController(auth: auth, subjectId: 'friend', service: data);
    addTearDown(c.dispose);
    addTearDown(auth.dispose);
    c.user = friendUser('friend');
    late FriendProfileActionFlow flow;
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Builder(builder: (context) {
      flow = FriendProfileActionFlow(context, c);
      return const SizedBox();
    }))));
    final pending = flow.sendFriendRequest();
    auth.account = null;
    auth.notifyListeners();
    await tester.pumpAndSettle();
    data.gate!.complete();
    await pending;
    await tester.pumpAndSettle();
    expect(c.friendshipStatus, FriendshipStatus.none);
    expect(c.actionLoading, false);
    expect(find.textContaining('Friend request sent'), findsNothing);
  });
  testWidgets('failed request retains friendship and gives retry feedback',
      (tester) async {
    final auth = ProfileAuth(), data = FriendWrites()..failed = true;
    final c =
        FriendProfileController(auth: auth, subjectId: 'friend', service: data);
    addTearDown(c.dispose);
    addTearDown(auth.dispose);
    c.user = friendUser('friend');
    late FriendProfileActionFlow flow;
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Builder(builder: (context) {
      flow = FriendProfileActionFlow(context, c);
      return const SizedBox();
    }))));
    await flow.sendFriendRequest();
    await tester.pumpAndSettle();
    expect(c.friendshipStatus, FriendshipStatus.none);
    expect(c.actionLoading, false);
    expect(find.text('Failed to send friend request'), findsOneWidget);
  });
  testWidgets(
      'remove confirmation opened for old subject cannot remove new person',
      (tester) async {
    final auth = ProfileAuth(), data = FriendWrites();
    final c =
        FriendProfileController(auth: auth, subjectId: 'old', service: data);
    addTearDown(c.dispose);
    addTearDown(auth.dispose);
    c.user = friendUser('old');
    c.friendshipStatus = FriendshipStatus.friends;
    late FriendProfileActionFlow flow;
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Builder(builder: (context) {
      flow = FriendProfileActionFlow(context, c);
      return const SizedBox();
    }))));
    final pending = flow.removeFriend();
    await tester.pumpAndSettle();
    c.setSubject('new');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    await pending;
    expect(data.writes, 0);
    expect(c.user?.id, 'new');
  });
}
