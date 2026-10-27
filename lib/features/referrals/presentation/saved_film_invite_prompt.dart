import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../data/referral_prompt_store.dart';
import 'package:flixie_app/features/pip/presentation/controllers/pip_collection_controller.dart';
import 'package:flixie_app/features/social/data/friend_service.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/features/movies/models/external_watch_invite.dart';
import 'package:flixie_app/features/movies/presentation/widgets/watch_companion_picker.dart';
import 'package:flixie_app/features/movies/presentation/widgets/external_watch_invite_sheet.dart';

Future<bool> maybeOfferSavedFilmInvite(BuildContext context,
    {required MovieWatchEntry entry,
    required String title,
    required bool Function() isCurrent}) async {
  final pips = context.read<PipCollectionController?>();
  if (!isCurrent() ||
      pips?.userId != entry.userId ||
      pips?.verified != true ||
      pips!.collection.cinemaUnlocked) {
    return false;
  }
  if (entry.planId != null ||
      entry.externalInvite != null ||
      entry.allCompanions.isNotEmpty) {
    return false;
  }
  if (!await ReferralPromptStore.reserve(entry.userId) ||
      !context.mounted ||
      !isCurrent()) {
    return false;
  }
  final updated = await showModalBottomSheet<MovieWatchEntry>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
          maxWidth: 560, maxHeight: MediaQuery.sizeOf(context).height * .85),
      builder: (_) =>
          _SavedFilmInvite(entry: entry, title: title, isCurrent: isCurrent));
  if (context.mounted &&
      isCurrent() &&
      updated?.externalInvite?.available == true) {
    await showExternalWatchInviteSheet(
        context, updated!.externalInvite!, title);
  }
  return true;
}

class _SavedFilmInvite extends StatefulWidget {
  const _SavedFilmInvite(
      {required this.entry, required this.title, required this.isCurrent});
  final MovieWatchEntry entry;
  final String title;
  final bool Function() isCurrent;
  @override
  State<_SavedFilmInvite> createState() => _SavedFilmInviteState();
}

class _SavedFilmInviteState extends State<_SavedFilmInvite> {
  Object? _choice;
  bool _busy = false;
  String? _error;
  final _draftId = const Uuid().v4();
  Future<void> _add() async {
    if (_busy || !widget.isCurrent()) return;
    final entry = widget.entry;
    _choice ??= await showModalBottomSheet<Object>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        constraints: BoxConstraints(
            maxWidth: 560, maxHeight: MediaQuery.sizeOf(context).height * .85),
        builder: (_) => WatchCompanionPicker(
            loadFriends: () async =>
                (await FriendService.getFriends(entry.userId)).friendships));
    if (!mounted || _choice == null || !widget.isCurrent()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final people = _choice is List<FriendshipUser>
          ? _choice as List<FriendshipUser>
          : <FriendshipUser>[];
      final updated = await UserService.updateMovieWatch(
          entry.userId,
          entry.id,
          UpdateMovieWatchRequest(
              draftId: _draftId,
              movieId: entry.movieId,
              watchedAt: entry.watchedAt,
              rating: entry.rating,
              recommended: entry.recommended,
              notes: entry.notes,
              watchedAtCinema: entry.watchedAtCinema,
              containsSpoilers: entry.reviewContainsSpoilers,
              companionIds:
                  people.isEmpty ? null : people.map((p) => p.id).toList(),
              externalCompanionName: _choice is ExternalWatchCompanion
                  ? (_choice as ExternalWatchCompanion).name
                  : null));
      if (mounted && widget.isCurrent()) Navigator.pop(context, updated);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Your film is saved. Couldn’t add your companion; your choice is still here. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_busy,
      child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                    child: Image.asset(
                        'assets/icon/pip_cosmetics/cinema_club.png',
                        width: 88,
                        height: 88,
                        excludeFromSemantics: true)),
                const SizedBox(height: 16),
                Text('Watched ${widget.title} with someone?',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                const Text(
                    'Your film is saved. Add who you watched with and invite them to add their own take.'),
                const SizedBox(height: 12),
                const Text(
                    'Confirm your own logs of the shared film to unlock Cinema Club Pip and an app icon for both of you. Existing friends count too.'),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!, semanticsLabel: _error)),
                const SizedBox(height: 20),
                FilledButton(
                    onPressed: _busy ? null : _add,
                    child: Text(_busy
                        ? 'Adding…'
                        : _error != null
                            ? 'Try again'
                            : 'Add someone')),
                TextButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const Text('Not now')),
              ])));
}
