import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/social/data/friend_service.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/features/social/data/chat_service.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/group.dart';

class ChatShareMedia {
  const ChatShareMedia(
      {required this.id,
      required this.title,
      this.posterPath,
      this.isShow = false});
  final int id;
  final String title;
  final String? posterPath;
  final bool isShow;
}

/// One picker and composer for movie and show recommendations.
class MediaChatShare {
  MediaChatShare(this.context);
  final BuildContext context;

  Future<void> _sheet(
      {required BuildContext context,
      required WidgetBuilder builder,
      ShapeBorder? shape,
      bool isScrollControlled = true}) async {
    await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        shape: shape,
        builder: (context) => ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .9),
            child: SingleChildScrollView(child: builder(context))));
  }

  String _movieDeepLink(ChatShareMedia movie) {
    return Uri(
      scheme: 'flixie',
      host: movie.isShow ? 'shows' : 'movies',
      pathSegments: [movie.id.toString()],
      queryParameters: const {'source': 'share'},
    ).toString();
  }

  Future<void> show(ChatShareMedia movie) async {
    await _sheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: FlixieColors.medium.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading:
                  const Icon(Icons.person_rounded, color: FlixieColors.light),
              title: const Text(
                'Share to friend',
                style: TextStyle(color: FlixieColors.light),
              ),
              subtitle: const Text(
                'Send directly to one friend',
                style: TextStyle(color: FlixieColors.medium, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showShareToFriendSheet(movie);
              },
            ),
            ListTile(
              leading: const Icon(Icons.groups_2_outlined,
                  color: FlixieColors.primary),
              title: const Text(
                'Share to group chat',
                style: TextStyle(color: FlixieColors.light),
              ),
              subtitle: const Text(
                'Post in one of your groups with a message',
                style: TextStyle(color: FlixieColors.medium, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showShareToGroupSheet(movie);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<List<Group>> _loadSharableGroups(String userId) async {
    final auth = context.read<AuthProvider>();
    final cached = auth.cachedGroups ?? const <Group>[];
    if (cached.isNotEmpty) {
      return cached.where((group) => group.id?.isNotEmpty == true).toList();
    }

    final fetched = await GroupService.getUserGroups(userId);
    auth.updateCachedGroups(fetched);
    return fetched.where((group) => group.id?.isNotEmpty == true).toList();
  }

  Future<List<Friendship>> _loadSharableFriends(String userId) async {
    final auth = context.read<AuthProvider>();
    final cached = auth.cachedFriends?.friendships ?? const <Friendship>[];
    if (cached.isNotEmpty) {
      return cached
          .where((friendship) => friendship.friendUser?.id.isNotEmpty == true)
          .toList();
    }

    final fetched = await FriendService.getFriends(userId);
    auth.updateCachedFriends(fetched);
    return fetched.friendships
        .where((friendship) => friendship.friendUser?.id.isNotEmpty == true)
        .toList();
  }

  Future<void> _showShareToFriendSheet(ChatShareMedia movie) async {
    final auth = context.read<AuthProvider>();
    final userId = auth.dbUser?.id;
    if (userId == null) return;

    List<Friendship> friends = const [];
    try {
      friends = await _loadSharableFriends(userId);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.error,
              content: const Text('Could not load your friends')),
        );
      }
      return;
    }

    if (!context.mounted) return;
    if (friends.isEmpty) {
      ScaffoldMessenger.of(context).showFlixieToast(
        FlixieToast(
            type: FlixieToastType.info,
            content: const Text('Add a friend to share there.')),
      );
      return;
    }

    String selectedFriendId = friends.first.friendUser!.id;
    final messageController =
        TextEditingController(text: 'You should watch this.');
    bool sending = false;

    await _sheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final selectedFriend = friends.firstWhere(
              (friendship) => friendship.friendUser?.id == selectedFriendId,
              orElse: () => friends.first,
            );
            final friendUser = selectedFriend.friendUser;

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: FlixieColors.medium.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Share to friend',
                    style: TextStyle(
                      color: FlixieColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    movie.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FlixieColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Choose a friend',
                    style: TextStyle(
                      color: FlixieColors.medium,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 228),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: friends.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final friendship = friends[index];
                        final friend = friendship.friendUser;
                        if (friend == null) return const SizedBox.shrink();
                        final isSelected = friend.id == selectedFriendId;
                        final avatar = friend.avatar;
                        final initials = friend.initials ??
                            (friend.username.isNotEmpty
                                ? friend.username[0].toUpperCase()
                                : '?');

                        return InkWell(
                          onTap: sending
                              ? null
                              : () => setSheetState(
                                  () => selectedFriendId = friend.id),
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? FlixieColors.primary.withValues(alpha: 0.14)
                                  : FlixieColors.tabBarBackgroundFocused,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? FlixieColors.primary
                                        .withValues(alpha: 0.45)
                                    : FlixieColors.tabBarBorder,
                              ),
                            ),
                            child: Row(
                              children: [
                                ProfileAvatarView(
                                  avatar: avatar,
                                  profileBadges: friend.profileBadges,
                                  fallbackText: initials,
                                  fallbackColor: FlixieColors.primary,
                                  size: 34,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    friend.displayName,
                                    style: const TextStyle(
                                      color: FlixieColors.light,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: FlixieColors.primary,
                                    size: 20,
                                  )
                                else
                                  const Icon(
                                    Icons.radio_button_unchecked_rounded,
                                    color: FlixieColors.medium,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: messageController,
                    minLines: 2,
                    maxLines: 3,
                    enabled: !sending,
                    style: const TextStyle(color: FlixieColors.light),
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      hintText: 'You should watch this.',
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: sending
                          ? null
                          : () async {
                              setSheetState(() => sending = true);
                              final navigator = Navigator.of(sheetContext);
                              final messenger = ScaffoldMessenger.of(context);
                              final customMessage =
                                  messageController.text.trim();

                              try {
                                await _shareMovieIntoDirectConversation(
                                  movie: movie,
                                  friend: selectedFriend,
                                  message: customMessage,
                                );
                                if (!context.mounted) return;
                                navigator.pop();
                                messenger.showFlixieToast(
                                  FlixieToast(
                                    type: FlixieToastType.success,
                                    content: Text(
                                        'Shared to ${friendUser?.displayName ?? 'friend'}'),
                                  ),
                                );
                              } catch (_) {
                                if (!context.mounted) return;
                                setSheetState(() => sending = false);
                                messenger.showFlixieToast(
                                  FlixieToast(
                                    type: FlixieToastType.error,
                                    content: const Text(
                                        'Could not share to that friend yet'),
                                  ),
                                );
                              }
                            },
                      icon: sending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      label:
                          Text(sending ? 'Sharing...' : 'Share in direct chat'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showShareToGroupSheet(ChatShareMedia movie) async {
    final auth = context.read<AuthProvider>();
    final userId = auth.dbUser?.id;
    if (userId == null) return;

    List<Group> groups = const [];
    try {
      groups = await _loadSharableGroups(userId);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.error,
              content: const Text('Could not load your groups')),
        );
      }
      return;
    }

    if (!context.mounted) return;
    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showFlixieToast(
        FlixieToast(
            type: FlixieToastType.info,
            content: const Text('Join or create a group to share there.')),
      );
      return;
    }

    String selectedGroupId = groups.first.id!;
    final messageController =
        TextEditingController(text: 'Has anyone ever seen this?');
    bool sending = false;

    await _sheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final selectedGroup = groups.firstWhere(
              (group) => group.id == selectedGroupId,
              orElse: () => groups.first,
            );

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: FlixieColors.medium.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Share to group chat',
                    style: TextStyle(
                      color: FlixieColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    movie.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FlixieColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Choose a group',
                    style: TextStyle(
                      color: FlixieColors.medium,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 228),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: groups.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final group = groups[index];
                        final isSelected = group.id == selectedGroupId;
                        return InkWell(
                          onTap: sending || group.id == null
                              ? null
                              : () => setSheetState(
                                  () => selectedGroupId = group.id!),
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? FlixieColors.primary.withValues(alpha: 0.14)
                                  : FlixieColors.tabBarBackgroundFocused,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? FlixieColors.primary
                                        .withValues(alpha: 0.45)
                                    : FlixieColors.tabBarBorder,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? FlixieColors.primary
                                            .withValues(alpha: 0.22)
                                        : FlixieColors.surfaceElevated,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    (group.abbreviation?.isNotEmpty == true
                                            ? group.abbreviation!
                                            : group.name)
                                        .trim()
                                        .characters
                                        .take(2)
                                        .toString()
                                        .toUpperCase(),
                                    style: TextStyle(
                                      color: isSelected
                                          ? FlixieColors.primary
                                          : FlixieColors.light,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        group.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: FlixieColors.light,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (group.abbreviation?.isNotEmpty ==
                                          true) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          group.abbreviation!.toUpperCase(),
                                          style: const TextStyle(
                                            color: FlixieColors.medium,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: FlixieColors.primary,
                                    size: 20,
                                  )
                                else
                                  const Icon(
                                    Icons.radio_button_unchecked_rounded,
                                    color: FlixieColors.medium,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: messageController,
                    minLines: 2,
                    maxLines: 3,
                    enabled: !sending,
                    style: const TextStyle(color: FlixieColors.light),
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      hintText: 'Has anyone ever seen this?',
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: sending
                          ? null
                          : () async {
                              setSheetState(() => sending = true);
                              final navigator = Navigator.of(sheetContext);
                              final messenger = ScaffoldMessenger.of(context);
                              final customMessage =
                                  messageController.text.trim();

                              try {
                                await _shareMovieIntoGroupConversation(
                                  movie: movie,
                                  group: selectedGroup,
                                  message: customMessage,
                                );
                                if (!context.mounted) return;
                                navigator.pop();
                                messenger.showFlixieToast(
                                  FlixieToast(
                                    type: FlixieToastType.success,
                                    content: Text(
                                        'Shared to ${selectedGroup.name} chat'),
                                  ),
                                );
                              } catch (_) {
                                if (!context.mounted) return;
                                setSheetState(() => sending = false);
                                messenger.showFlixieToast(
                                  FlixieToast(
                                    type: FlixieToastType.error,
                                    content: const Text(
                                        'Could not share to that group yet'),
                                  ),
                                );
                              }
                            },
                      icon: sending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      label:
                          Text(sending ? 'Sharing...' : 'Share in group chat'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _shareMovieIntoGroupConversation({
    required ChatShareMedia movie,
    required Group group,
    required String message,
  }) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    final groupId = group.id;
    if (userId == null || groupId == null || groupId.isEmpty) {
      throw StateError('Missing share context');
    }

    final members = await GroupService.getGroupMembers(groupId);
    final memberIds = members
        .where((member) => member.isAccepted)
        .map((member) => member.memberId)
        .toSet()
      ..add(userId);

    final conversation = await ChatService.getOrCreateGroupConversation(
      creatorId: userId,
      pgGroupId: groupId,
      name: group.name,
      memberIds: memberIds.toList(),
    );

    final prompt = message.isEmpty ? 'Has anyone ever seen this?' : message;
    final chatText = _buildMovieSharePayload(
      movie: movie,
      message: prompt,
    );

    await ChatService.sendMessage(
      conversationId: conversation.id,
      senderId: userId,
      text: chatText,
    );
  }

  Future<void> _shareMovieIntoDirectConversation({
    required ChatShareMedia movie,
    required Friendship friend,
    required String message,
  }) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    final friendUser = friend.friendUser;
    if (userId == null || friendUser == null || friendUser.id.isEmpty) {
      throw StateError('Missing share context');
    }

    final conversation = await ChatService.getOrCreateDirectConversation(
      userId: userId,
      otherUserId: friendUser.id,
    );

    final prompt = message.isEmpty ? 'You should watch this.' : message;
    final chatText = _buildMovieSharePayload(
      movie: movie,
      message: prompt,
    );

    await ChatService.sendMessage(
      conversationId: conversation.id,
      senderId: userId,
      text: chatText,
    );
  }

  String _buildMovieSharePayload({
    required ChatShareMedia movie,
    required String message,
  }) {
    final posterUrl = movie.posterPath == null
        ? ''
        : 'https://image.tmdb.org/t/p/w342${movie.posterPath}';
    final title = Uri.encodeComponent(movie.title);
    final deepLink = Uri.encodeComponent(_movieDeepLink(movie));
    final poster = Uri.encodeComponent(posterUrl);
    final prompt = Uri.encodeComponent(message.trim());

    final tag = movie.isShow ? 'FLIXIE_SHOW_SHARE' : 'FLIXIE_MOVIE_SHARE';
    return '[$tag]\n'
        'title=$title\n'
        'link=$deepLink\n'
        'poster=$poster\n'
        'message=$prompt\n'
        '[/$tag]';
  }
}
