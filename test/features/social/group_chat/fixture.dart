import 'dart:async';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flutter/foundation.dart';
import 'package:flixie_app/features/social/data/group_chat_service.dart';
import 'package:flixie_app/models/conversation.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/group_member.dart';
import 'package:flixie_app/models/group_watch_request.dart';

class ChatFixtureAuth extends ChangeNotifier implements AuthProvider {
  String? id = 'viewer';
  @override
  User? get dbUser => id == null
      ? null
      : User(
          id: id!,
          username: 'OdysseyFan',
          email: '',
          iconColorId: 0,
          completedSetup: true,
          darkMode: true);
  void change(String? user) {
    id = user;
    notifyListeners();
  }

  void ping() => notifyListeners();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class ChatFixture extends GroupChatService {
  int groupReads = 0, memberReads = 0, creates = 0, requestReads = 0;
  int subscriptions = 0, cancellations = 0;
  bool fail = false;
  Completer<void>? gate;
  final channels = <StreamController<List<ChatMessage>>>[];
  @override
  Future<Group> group(String id) async {
    groupReads++;
    await gate?.future;
    if (fail) throw StateError('offline');
    return Group(id: id, name: 'Odyssey film club', ownerId: 'viewer');
  }

  @override
  Future<List<GroupMember>> members(String id) async {
    memberReads++;
    return [
      GroupMember(
          groupId: id,
          memberId: 'friend',
          role: 'MEMBER',
          username: 'AlienFan',
          profileBadges: const ['FOUNDER'])
    ];
  }

  @override
  Future<Conversation> conversation(
      String user, String group, String name, List<String> members) async {
    creates++;
    return Conversation(id: '$group-$user', type: 'group', memberIds: members);
  }

  @override
  Future<Map<String, String>> usernames(String id) async =>
      {'friend': 'AlienFan'};
  @override
  Future<List<GroupWatchRequest>> requests(String id, String user) async {
    requestReads++;
    return [];
  }

  @override
  Stream<List<ChatMessage>> messages(String id) {
    late StreamController<List<ChatMessage>> channel;
    channel = StreamController<List<ChatMessage>>(
      onListen: () {
        subscriptions++;
        channel.add(List.generate(
            50,
            (i) => ChatMessage(
                id: '$id-$i',
                senderId: i.isEven ? 'friend' : 'viewer',
                text: '$id: Alien, Spider-Man and The Odyssey ($i)',
                createdAt: DateTime(2026, 10, 9, 12, i))));
      },
      onCancel: () {
        cancellations++;
      },
    );
    channels.add(channel);
    return channel.stream;
  }

  void close() {
    for (final channel in channels) {
      channel.close();
    }
  }
}
