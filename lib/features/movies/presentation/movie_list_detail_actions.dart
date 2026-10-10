import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/movie_list_movie.dart';
import 'package:flixie_app/models/movie_list_membership.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/features/social/data/friend_service.dart';
import 'package:flixie_app/features/movies/presentation/controllers/movie_lists_controller.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';

import 'package:flixie_app/features/movies/presentation/movie_list_selection.dart';
import 'controllers/movie_list_detail_controller.dart';
import 'widgets/movie_list_detail/add_movie_to_list_sheet.dart';
import 'widgets/movie_list_detail/add_list_member_sheet.dart';
import 'widgets/movie_list_detail/movie_list_members_sheet.dart';
import 'widgets/movie_list_detail/movie_list_account_sheet.dart';

class MovieListDetailActions {
  MovieListDetailActions(
      {required this.context,
      required this.listId,
      required this.listName,
      required this.ownerUserId,
      required this.controller,
      required this.refresh})
      : viewer = context.read<AuthProvider>().dbUser?.id;
  final BuildContext context;
  final String listId, listName, ownerUserId;
  final MovieListDetailController controller;
  final Future<void> Function() refresh;
  final String? viewer;
  final Set<String> _activeActions = {};
  Future<void> _once(String key, Future<void> Function() action) async {
    if (!isCurrent || !_activeActions.add(key)) return;
    try {
      await action();
    } finally {
      _activeActions.remove(key);
    }
  }

  bool get isCurrent =>
      context.mounted &&
      !controller.accessDenied &&
      context.read<AuthProvider>().dbUser?.id == viewer;
  Future<void> showAddMovies() => _once('picker', _showAddMovieSheet);
  Future<void> deleteList() => _once('delete', _deleteList);
  Future<void> leaveList() => _once('leave', _leaveList);
  Future<void> showMembers() => _showMembersSheet();
  Future<void> remove(MovieListsProvider provider, MovieListMovie entry) =>
      _once(
          'remove:${entry.id}', () => _confirmRemove(context, provider, entry));
  Future<void> _showAddMovieSheet() async {
    final provider = context.read<MovieListsProvider>();
    final added = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: context.colors.surfaceElevated,
      builder: (sheetContext) => MovieListAccountSheet(
          viewer: viewer,
          child: ChangeNotifierProvider<MovieListsProvider>.value(
            value: provider,
            child: AddMovieToListSheet(
              listId: listId,
              listName: listName,
            ),
          )),
    );
    if (added == true && context.mounted && isCurrent) {
      await refresh();
    }
  }

  Future<void> _deleteList() async {
    final confirmed = await showFlixiePromptSheet<bool>(
      context: context,
      builder: (dialogContext) => MovieListAccountSheet(
          viewer: viewer,
          child: FlixiePromptSheetContent(
            title: const Text('Delete this list?'),
            content: const Text(
              'The collection will be removed for everyone. This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Keep list'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.danger,
                ),
                child: const Text('Delete'),
              ),
            ],
          )),
    );
    if (confirmed != true || !context.mounted || !isCurrent) return;
    try {
      await UserService.deleteMovieList(ownerUserId, listId);
      if (context.mounted && isCurrent) context.go('/movie-lists');
    } catch (_) {
      if (context.mounted && isCurrent) {
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.error,
              content: const Text('Unable to delete this list.')),
        );
      }
    }
  }

  Future<void> _leaveList() async {
    final currentUserId = context.read<AuthProvider>().dbUser?.id;
    if (currentUserId == null) return;
    final confirmed = await showFlixiePromptSheet<bool>(
      context: context,
      builder: (dialogContext) => MovieListAccountSheet(
          viewer: viewer,
          child: FlixiePromptSheetContent(
            title: const Text('Leave this list?'),
            content: const Text(
              'It will disappear from your lists, but everyone else keeps access.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Leave'),
              ),
            ],
          )),
    );
    if (confirmed != true || !context.mounted || !isCurrent) return;
    try {
      await UserService.removeMovieListMember(
        currentUserId,
        listId,
        currentUserId,
      );
      if (context.mounted && isCurrent) context.go('/movie-lists');
    } catch (_) {
      if (context.mounted && isCurrent) {
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.error,
              content: const Text('Unable to leave this list.')),
        );
      }
    }
  }

  Future<void> _removeMember(
      MovieListMember member, BuildContext sheetContext) async {
    final currentUserId = context.read<AuthProvider>().dbUser?.id;
    if (currentUserId == null) return;
    try {
      await UserService.removeMovieListMember(
        currentUserId,
        listId,
        member.id,
      );
      if (!context.mounted || !isCurrent) return;
      await controller.refresh();
      if (context.mounted && isCurrent && sheetContext.mounted) {
        Navigator.of(sheetContext).pop();
      }
    } catch (_) {
      if (context.mounted && isCurrent) {
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.error,
              content: Text('Unable to remove @${member.username}.')),
        );
      }
    }
  }

  Future<void> _addMember(BuildContext sheetContext) async {
    final currentUserId = context.read<AuthProvider>().dbUser?.id;
    if (currentUserId == null) return;
    try {
      final friendsData = await FriendService.getFriends(currentUserId);
      if (!context.mounted || !isCurrent) return;
      final existingIds =
          controller.membership?.members.map((member) => member.id).toSet() ??
              <String>{};
      final available = friendsData.friendships
          .map((friendship) => friendship.friendUser)
          .whereType<FriendshipUser>()
          .where((friend) => !existingIds.contains(friend.id))
          .toList(growable: false);
      final selected = await showModalBottomSheet<FriendshipUser>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: context.colors.surfaceElevated,
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .9),
        builder: (_) => MovieListAccountSheet(
            viewer: viewer, child: AddListMemberSheet(friends: available)),
      );
      if (selected == null || !context.mounted || !isCurrent) return;
      await UserService.addMovieListMember(
        currentUserId,
        listId,
        selected.id,
      );
      if (!context.mounted || !isCurrent) return;
      await controller.refresh();
      if (context.mounted && isCurrent && sheetContext.mounted) {
        Navigator.of(sheetContext).pop();
      }
    } catch (_) {
      if (context.mounted && isCurrent) {
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.error,
              content: const Text('Unable to add a member.')),
        );
      }
    }
  }

  Future<void> _showMembersSheet() async {
    final membership = controller.membership;
    if (membership == null) return;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .9),
      backgroundColor: context.colors.surfaceElevated,
      showDragHandle: true,
      builder: (sheetContext) => MovieListAccountSheet(
          viewer: viewer,
          child: MovieListMembersSheet(
              membership: membership,
              onAdd: () => _once('member', () => _addMember(sheetContext)),
              onRemove: (member) =>
                  _once('member', () => _removeMember(member, sheetContext)),
              onLeave: leaveList)),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    MovieListsProvider provider,
    MovieListMovie entry,
  ) async {
    final movieId = entryMovieId(entry);
    final showId = entryShowId(entry);
    if (movieId <= 0 && showId <= 0) return;
    final title = entryTitle(entry);
    final confirmed = await showFlixiePromptSheet<bool>(
      context: context,
      builder: (dialogContext) => MovieListAccountSheet(
          viewer: viewer,
          child: FlixiePromptSheetContent(
            title: const Text('Remove from list?'),
            content: Text(
              entry.addedBy != null &&
                      entry.addedBy!.id !=
                          context.read<AuthProvider>().dbUser?.id
                  ? 'Remove $title, added by @${entry.addedBy!.username}, from $listName?'
                  : 'Remove $title from $listName?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Remove'),
              ),
            ],
          )),
    );
    if (confirmed != true || !context.mounted || !isCurrent) return;
    final analytics = context.read<AnalyticsController>();
    final ok = movieId > 0
        ? await provider.removeMovieFromList(listId, movieId)
        : await provider.removeShowFromList(listId, showId);
    if (ok) {
      await (movieId > 0
          ? analytics.movieRemovedFromList()
          : analytics.showRemovedFromList());
    }
    if (!context.mounted || !isCurrent) return;
    ScaffoldMessenger.of(context).showFlixieToast(
      FlixieToast(
        type: FlixieToastType.error,
        content: Text(
          ok
              ? 'Removed from list'
              : (provider.error ?? 'Unable to remove movie'),
        ),
      ),
    );
  }
}
