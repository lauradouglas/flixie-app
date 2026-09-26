import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/features/social/presentation/controllers/friend_actions_controller.dart';
import 'package:flixie_app/features/social/presentation/controllers/community_connections_controller.dart';
import 'package:flixie_app/features/social/presentation/widgets/community_friend_button.dart';

const author = FriendshipUser(id: 'author', username: 'Author');
const relationship =
    Friendship(id: 'request-1', friend: author, createdAt: '', updatedAt: '');
const empty =
    FriendsData(friendships: [], pendingFriends: [], requestedFriends: []);

class Actions extends FriendActionsController {
  FriendsData data = empty;
  bool fail = false, failRead = false;
  Completer<void>? pending;
  Completer<FriendsData>? delayedRead;
  final sent = <Map<String, dynamic>>[];
  final accepted = <String>[];
  @override
  Future<FriendsData> getFriends(String userId) async {
    if (delayedRead != null) return delayedRead!.future;
    if (failRead) throw Exception('offline');
    return data;
  }

  @override
  Future<void> sendFriendRequest(Map<String, dynamic> body) async {
    sent.add(body);
    if (pending != null) await pending!.future;
    if (fail) throw Exception('offline');
    data = const FriendsData(
        friendships: [], pendingFriends: [], requestedFriends: [relationship]);
  }

  @override
  Future<void> acceptRequest(String id) async {
    accepted.add(id);
    data = const FriendsData(
        friendships: [relationship], pendingFriends: [], requestedFriends: []);
  }
}

void main() {
  testWidgets('compact friendship status is readable without a disabled action',
      (tester) async {
    final actions = Actions()
      ..data = const FriendsData(
          friendships: [relationship],
          pendingFriends: [],
          requestedFriends: []);
    final controller =
        CommunityConnectionsController(userId: 'me', actions: actions);
    addTearDown(controller.dispose);
    await controller.refresh();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CommunityFriendButton(
                connections: controller, author: author, compact: true))));
    expect(find.text('Friends'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
    expect(tester.getSize(find.byType(CommunityFriendButton)).height,
        lessThan(40));
  });

  test('an older refresh cannot undo a successful friend request', () async {
    final actions = Actions();
    final controller =
        CommunityConnectionsController(userId: 'me', actions: actions);
    addTearDown(controller.dispose);
    await controller.refresh();
    final delayed = Completer<FriendsData>();
    actions.delayedRead = delayed;
    final oldRefresh = controller.refresh();
    actions.delayedRead = null;
    await controller.connect(author);
    delayed.complete(empty);
    await oldRefresh;
    expect(controller.stateFor('author'), CommunityConnection.outgoing);
    await controller.connect(const FriendshipUser(id: 'me', username: 'Me'));
    expect(actions.sent.length, 1);
  });

  testWidgets(
      'one request updates every post by the author and survives refresh',
      (tester) async {
    final actions = Actions()..pending = Completer<void>();
    final controller =
        CommunityConnectionsController(userId: 'me', actions: actions);
    addTearDown(controller.dispose);
    await controller.refresh();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Column(children: [
      for (var i = 0; i < 2; i++)
        CommunityFriendButton(connections: controller, author: author)
    ]))));
    await tester.tap(find.text('Add friend').first);
    await tester.pump();
    expect(find.text('Sending…'), findsNWidgets(2));
    await controller.connect(author);
    expect(actions.sent.length, 1);
    expect(actions.sent.single, containsPair('recipientId', 'author'));
    expect(actions.sent.single, containsPair('requesterId', 'me'));
    expect(actions.sent.single, containsPair('type', 'FRIEND_REQUEST'));
    actions.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Request sent'), findsNWidgets(2));
    await controller.refresh();
    await tester.pump();
    expect(find.text('Request sent'), findsNWidgets(2));
  });
  testWidgets('an incoming request can be accepted from the post',
      (tester) async {
    final actions = Actions()
      ..data = const FriendsData(
          friendships: [],
          pendingFriends: [relationship],
          requestedFriends: []);
    final controller =
        CommunityConnectionsController(userId: 'me', actions: actions);
    addTearDown(controller.dispose);
    await controller.refresh();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CommunityFriendButton(
                connections: controller, author: author))));
    await tester.tap(find.text('Accept request'));
    await tester.pumpAndSettle();
    expect(actions.accepted, ['request-1']);
    expect(find.text('Friends'), findsOneWidget);
  });
  testWidgets('failed requests can be retried and self has no add button',
      (tester) async {
    final actions = Actions()..fail = true;
    final controller =
        CommunityConnectionsController(userId: 'me', actions: actions);
    addTearDown(controller.dispose);
    await controller.refresh();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Column(children: [
      CommunityFriendButton(connections: controller, author: author),
      CommunityFriendButton(
          connections: controller,
          author: const FriendshipUser(id: 'me', username: 'Me'))
    ]))));
    expect(find.text('Add friend'), findsOneWidget);
    await tester.tap(find.text('Add friend'));
    await tester.pumpAndSettle();
    expect(find.text('Add friend'), findsOneWidget);
    expect(find.text('Couldn’t update the friend request. Please try again.'),
        findsOneWidget);
    actions.fail = false;
    await tester.tap(find.text('Add friend'));
    await tester.pumpAndSettle();
    expect(find.text('Request sent'), findsOneWidget);
  });
  test('confirmed send remains pending if reloading relationships fails',
      () async {
    final actions = Actions();
    final controller =
        CommunityConnectionsController(userId: 'me', actions: actions);
    addTearDown(controller.dispose);
    await controller.refresh();
    actions.failRead = true;
    await controller.connect(author);
    expect(controller.stateFor('author'), CommunityConnection.outgoing);
    await controller.connect(author);
    expect(actions.sent.length, 1);
  });
  testWidgets('unknown friend status fails closed and can be retried',
      (tester) async {
    final actions = Actions()..failRead = true;
    final controller =
        CommunityConnectionsController(userId: 'me', actions: actions);
    addTearDown(controller.dispose);
    await controller.refresh();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CommunityFriendButton(
                connections: controller, author: author))));
    expect(find.text('Add friend'), findsNothing);
    actions.failRead = false;
    await tester.tap(find.text('Retry friend status'));
    await tester.pumpAndSettle();
    expect(find.text('Add friend'), findsOneWidget);
  });
}
