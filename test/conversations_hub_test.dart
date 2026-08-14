import 'package:flutter_test/flutter_test.dart';

import 'package:flixie_app/features/social/presentation/utils/movie_share_payload.dart';
import 'package:flixie_app/features/social/presentation/widgets/conversations_hub.dart';
import 'package:flixie_app/models/conversation.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/group.dart';

void main() {
  test('conversation parses the backend last-message fields', () {
    final conversation = Conversation.fromMap({
      'id': 'conversation-1',
      'type': 'dm',
      'memberIds': ['me', 'friend'],
      'lastMessageText': 'Fancy watching this?',
      'lastMessageSenderId': 'friend',
      'lastMessageAt': '2026-08-14T12:00:00Z',
    });

    expect(conversation.lastMessage, 'Fancy watching this?');
    expect(conversation.lastMessageSenderId, 'friend');
  });

  test('direct conversation title uses the other friend username', () {
    const conversation = Conversation(
      id: 'conversation-1',
      type: 'dm',
      memberIds: ['me', 'friend'],
    );

    expect(
      conversationTitle(
        conversation,
        currentUserId: 'me',
        friends: const {
          'friend': FriendshipUser(id: 'friend', username: 'Amy'),
        },
        groups: const {},
      ),
      'Amy',
    );
  });

  test('group conversation title uses its linked group', () {
    const conversation = Conversation(
      id: 'conversation-2',
      type: 'group',
      memberIds: ['me', 'friend'],
      pgGroupId: 'group-1',
    );

    expect(
      conversationTitle(
        conversation,
        currentUserId: 'me',
        friends: const {},
        groups: const {
          'group-1': Group(
            id: 'group-1',
            name: 'Friday Movie Night',
            ownerId: 'me',
          ),
        },
      ),
      'Friday Movie Night',
    );
  });

  test('conversation timestamp is compact and readable', () {
    final now = DateTime(2026, 8, 14, 12);
    expect(
      conversationTimeLabel(DateTime(2026, 8, 14, 11, 58), now: now),
      '2m',
    );
    expect(
      conversationTimeLabel(DateTime(2026, 8, 14, 10), now: now),
      '2h',
    );
  });

  test('movie share payload has a human conversation preview', () {
    const message = '''[FLIXIE_MOVIE_SHARE]
title=Spider-Man%3A%20Brand%20New%20Day
link=flixie%3A%2F%2Fmovies%2F123
poster=https%3A%2F%2Fimage.example%2Fposter.jpg
message=You%20would%20love%20this
[/FLIXIE_MOVIE_SHARE]''';

    expect(
      conversationMessagePreview(message),
      '🎬 Shared Spider-Man: Brand New Day',
    );
  });

  test('ordinary messages remain unchanged in conversation previews', () {
    expect(conversationMessagePreview('Fancy watching this?'),
        'Fancy watching this?');
  });
}
