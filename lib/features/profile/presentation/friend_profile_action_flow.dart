import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';

import 'package:flutter/material.dart';

import 'package:flixie_app/features/authentication/presentation/pages/auth_ui.dart';
import 'package:flixie_app/features/movies/data/search_service.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/features/movies/presentation/widgets/watch_request_sheet.dart';

import 'controllers/friend_profile_controller.dart';

class FriendProfileActionFlow {
  FriendProfileActionFlow(this.context, this.controller);
  final BuildContext context;
  final FriendProfileController controller;
  Future<void> sendFriendRequest() async {
    final generation = controller.generation,
        viewer = controller.auth.dbUser?.id;
    bool current() => context.mounted && controller.owns(generation, viewer);
    if (!current() || controller.actionLoading) return;
    final auth = controller.auth;
    final myId = auth.dbUser?.id;
    if (myId == null || controller.user == null) return;

    controller.change(() => controller.actionLoading = true);
    try {
      await controller.service.sendFriendRequest({
        'requesterId': myId,
        'recipientId': controller.subjectId,
        'responderUsername': controller.user!.username,
        'message': '',
        'type': 'FRIEND_REQUEST',
      });
      if (context.mounted && current()) {
        controller.change(() {
          controller.friendshipStatus = FriendshipStatus.requested;
          controller.actionLoading = false;
        });
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.success,
              content: Text(
                  'Friend request sent to ${controller.user?.username ?? 'user'}')),
        );
      }
    } catch (e) {
      logger.e('[FriendProfileScreen] send friend request error: $e');
      if (context.mounted && current()) {
        controller.change(() => controller.actionLoading = false);
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.error,
              content: const Text('Failed to send friend request')),
        );
      }
    }
  }

  Future<void> removeFriend() async {
    final generation = controller.generation,
        viewer = controller.auth.dbUser?.id;
    bool current() => context.mounted && controller.owns(generation, viewer);
    if (!current() || controller.actionLoading) return;
    if (!current()) return;
    final auth = controller.auth;
    final myId = auth.dbUser?.id;
    if (myId == null) return;

    final confirmed = await showFlixiePromptSheet<bool>(
      context: context,
      builder: (dialogContext) => FlixiePromptSheetContent(
        title: const Text('Remove Friend'),
        content: Text(
            'Remove ${controller.user?.username ?? 'this user'} from your friends?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child:
                Text('Remove', style: TextStyle(color: context.colors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!current()) return;

    controller.change(() => controller.actionLoading = true);
    try {
      await controller.service.removeFriend(myId, controller.subjectId);
      if (context.mounted && current()) {
        controller.change(() {
          controller.friendshipStatus = FriendshipStatus.none;
          controller.friendshipId = null;
          controller.actionLoading = false;
        });
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.success,
              content: Text(
                  '${controller.user?.username ?? 'User'} removed from friends')),
        );
      }
    } catch (e) {
      logger.e('[FriendProfileScreen] remove friend error: $e');
      if (context.mounted && current()) {
        controller.change(() => controller.actionLoading = false);
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.error,
              content: const Text('Failed to remove friend')),
        );
      }
    }
  }

  Future<List<MovieShort>> _searchMovies(String query) async {
    final results = await SearchService.search(query, type: 'movie');
    return results.results
        .where((item) => !item.isPerson && item.movie != null)
        .map((item) => item.movie!)
        .toList(growable: false);
  }

  Future<void> inviteToWatch() async {
    final generation = controller.generation,
        viewer = controller.auth.dbUser?.id;
    bool current() => context.mounted && controller.owns(generation, viewer);
    if (!current() || controller.actionLoading) return;
    final auth = controller.auth;
    final myId = auth.dbUser?.id;
    final user = controller.user;
    if (myId == null || user == null) return;

    final movie = await showModalBottomSheet<MovieShort>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: context.colors.surface,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: MovieSearchSheet(searchMovies: _searchMovies),
      ),
    );
    if (!context.mounted || !current() || movie == null) return;

    final selectedFriend = Friendship(
      id: 'friend:${user.id}',
      friend: FriendshipUser(
        id: user.id,
        username: user.username,
        firstName: user.firstName,
        lastName: user.lastName,
        initials: user.initials,
        iconColor: user.iconColor,
        avatar: user.avatar,
        profileBadges: user.profileBadges,
      ),
      createdAt: '',
      updatedAt: '',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ListenableBuilder(
          listenable: controller,
          builder: (_, __) {
            if (!current()) {
              return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('This profile changed. Close and reopen.'));
            }
            return MovieWatchRequestSheet(
              movieId: movie.id,
              movieTitle: movie.name,
              requesterId: myId,
              friends: [selectedFriend],
              initialFriendId: user.id,
              onSuccess: () {
                if (context.mounted && current()) {
                  ScaffoldMessenger.of(context).showFlixieToast(
                    FlixieToast(
                        type: FlixieToastType.success,
                        content: const Text('Watch invite sent!')),
                  );
                }
              },
              onError: () {
                if (context.mounted && current()) {
                  ScaffoldMessenger.of(context).showFlixieToast(
                    FlixieToast(
                        type: FlixieToastType.error,
                        content: const Text('Failed to send invite')),
                  );
                }
              },
            );
          }),
    );
  }

  Future<void> acceptRequest() async {
    final generation = controller.generation,
        viewer = controller.auth.dbUser?.id;
    bool current() => context.mounted && controller.owns(generation, viewer);
    if (!current() || controller.actionLoading) return;
    if (controller.friendshipId == null) return;
    controller.change(() => controller.actionLoading = true);
    try {
      await controller.service
          .updateRequest(controller.friendshipId!, 'ACCEPTED');
      if (context.mounted && current()) {
        controller.change(() {
          controller.friendshipStatus = FriendshipStatus.friends;
          controller.actionLoading = false;
        });
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.success,
              content: Text(
                  'You are now friends with ${controller.user?.username ?? 'this user'}')),
        );
      }
    } catch (e) {
      logger.e('[FriendProfileScreen] accept request error: $e');
      if (context.mounted && current()) {
        controller.change(() => controller.actionLoading = false);
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.error,
              content: const Text('Failed to accept friend request')),
        );
      }
    }
  }

  Future<void> declineRequest() async {
    final generation = controller.generation,
        viewer = controller.auth.dbUser?.id;
    bool current() => context.mounted && controller.owns(generation, viewer);
    if (!current() || controller.actionLoading) return;
    if (controller.friendshipId == null) return;
    controller.change(() => controller.actionLoading = true);
    try {
      await controller.service
          .updateRequest(controller.friendshipId!, 'DECLINED');
      if (context.mounted && current()) {
        controller.change(() {
          controller.friendshipStatus = FriendshipStatus.none;
          controller.friendshipId = null;
          controller.actionLoading = false;
        });
      }
    } catch (e) {
      logger.e('[FriendProfileScreen] decline request error: $e');
      if (context.mounted && current()) {
        controller.change(() => controller.actionLoading = false);
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.error,
              content: const Text('Failed to decline friend request')),
        );
      }
    }
  }
}
