import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/movie_list.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/movies/presentation/controllers/movie_lists_controller.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/features/movies/presentation/widgets/list_picker_sheet.dart';
import 'create_media_list_sheet.dart';

class MediaListPicker extends StatelessWidget {
  const MediaListPicker(
      {super.key, required this.mediaId, this.isShow = false});
  final int mediaId;
  final bool isShow;
  @override
  Widget build(BuildContext context) {
    final userId =
        context.select<AuthProvider, String?>((auth) => auth.dbUser?.id);
    if (userId == null) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('Sign in to use lists')),
      );
    }
    return ChangeNotifierProvider(
      key: ValueKey((userId, mediaId, isShow)),
      create: (_) => MovieListsProvider(
        userId: userId,
      ),
      child: _MediaListPickerBody(mediaId: mediaId, isShow: isShow),
    );
  }
}

class _MediaListPickerBody extends StatefulWidget {
  const _MediaListPickerBody({required this.mediaId, required this.isShow});
  final int mediaId;
  final bool isShow;

  @override
  State<_MediaListPickerBody> createState() => _MediaListPickerBodyState();
}

class _MediaListPickerBodyState extends State<_MediaListPickerBody> {
  final Set<String> _selectedListIds = <String>{};
  final Set<String> _initialListIds = <String>{};
  final Set<String> _committedAddedIds = {};
  final Set<String> _committedRemovedIds = {};
  bool _saving = false;
  bool _loadingMembership = true;
  String? _membershipError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMembership());
  }

  Future<void> _loadMembership() async {
    if (!mounted) return;
    final provider = context.read<MovieListsProvider>();
    setState(() {
      _loadingMembership = true;
      _membershipError = null;
    });
    try {
      await provider.loadLists();
      if (!mounted) return;
      if (provider.error != null) throw StateError(provider.error!);
      final containing = await provider.getListsContainingMedia(widget.mediaId,
          isShow: widget.isShow);
      if (!mounted) return;
      setState(() {
        _initialListIds
          ..clear()
          ..addAll(containing.map((list) => list.id));
        _selectedListIds
          ..clear()
          ..addAll(_initialListIds);
        _loadingMembership = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMembership = false;
        _membershipError = 'Couldn’t check your lists. Please retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MovieListsProvider>();
    if (provider.isLoading || _loadingMembership) {
      return const ListPickerLoadingSplash(
        message: 'Checking your lists…',
      );
    }
    if (_membershipError != null) {
      return SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_membershipError!),
                TextButton(
                    onPressed: _loadMembership, child: const Text('Retry')),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
              ])));
    }
    return ListPickerSheet(
      items: provider.lists
          .map((list) => ListPickerItem(
                id: list.id,
                name: list.name,
                visibility: list.visibility,
                posterUrls: list.previewPosterUrls,
                countLabel: _listCountLabel(list),
                scope: list.scope,
                groupName: list.groupName,
                collaborators: list.participants.isNotEmpty
                    ? list.participants
                    : list.collaborators,
              ))
          .toList(growable: false),
      selectedIds: _selectedListIds,
      mediaLabel: widget.isShow ? 'show' : 'movie',
      saving: _saving,
      onToggle: (id) => setState(() {
        _selectedListIds.contains(id)
            ? _selectedListIds.remove(id)
            : _selectedListIds.add(id);
      }),
      onCreate: _openCreateListSheet,
      onDone: () => _applyChanges(provider),
      onCancel: () => Navigator.pop(context),
    );
  }

  Future<void> _applyChanges(MovieListsProvider provider) async {
    if (_saving || !mounted) return;
    final analytics = context.read<AnalyticsController>();
    setState(() => _saving = true);
    final toAdd = _selectedListIds.difference(_initialListIds).toList();
    final toRemove = _initialListIds.difference(_selectedListIds).toList();
    final failed = <String>[];

    for (final listId in toAdd) {
      if (!mounted) return;
      final ok = await (widget.isShow
          ? provider.addShowToList(listId, widget.mediaId)
          : provider.addMovieToList(listId, widget.mediaId));
      if (ok) {
        _initialListIds.add(listId);
        if (!_committedRemovedIds.remove(listId)) {
          _committedAddedIds.add(listId);
        }
        await (widget.isShow
            ? analytics.showAddedToList()
            : analytics.movieAddedToList());
      } else {
        failed.add(listId);
      }
    }
    for (final listId in toRemove) {
      if (!mounted) return;
      final ok = await (widget.isShow
          ? provider.removeShowFromList(listId, widget.mediaId)
          : provider.removeMovieFromList(listId, widget.mediaId));
      if (ok) {
        _initialListIds.remove(listId);
        if (!_committedAddedIds.remove(listId)) {
          _committedRemovedIds.add(listId);
        }
        await (widget.isShow
            ? analytics.showRemovedFromList()
            : analytics.movieRemovedFromList());
      } else {
        failed.add(listId);
      }
    }

    if (!mounted) return;
    setState(() => _saving = false);
    if (failed.isNotEmpty) {
      final listNames = failed
          .map(
            (id) => provider.lists
                .firstWhere(
                  (list) => list.id == id,
                  orElse: () => const MovieList(
                    id: '',
                    name: 'Unknown List',
                    removed: false,
                  ),
                )
                .name,
          )
          .toSet()
          .join(', ');
      ScaffoldMessenger.of(context).showFlixieToast(
        FlixieToast(
          type: FlixieToastType.error,
          content: Text(
            'Couldn’t update $listNames. Your selections are still here.',
          ),
          action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                if (mounted && !_saving) _applyChanges(provider);
              }),
        ),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthProvider>();
    final userId = provider.userId;
    final movieId = widget.mediaId;
    final restoreMembership = List<String>.of(_committedRemovedIds);
    final removeMembership = List<String>.of(_committedAddedIds);
    var undoRunning = false;
    Future<void> undo() async {
      if (undoRunning || auth.dbUser?.id != userId) return;
      undoRunning = true;
      try {
        for (final id in List<String>.of(restoreMembership)) {
          await (widget.isShow
              ? UserService.addShowToList(userId, id, movieId)
              : UserService.addMovieToList(userId, id, movieId));
          restoreMembership.remove(id);
        }
        for (final id in List<String>.of(removeMembership)) {
          await (widget.isShow
              ? UserService.removeShowFromList(userId, id, movieId)
              : UserService.removeMovieFromList(userId, id, movieId));
          removeMembership.remove(id);
        }
        auth.markActivityChanged();
        if (messenger.mounted) {
          messenger.showFlixieToast(FlixieToast(
              type: FlixieToastType.success,
              content: const Text('List changes undone')));
        }
      } catch (_) {
        if (messenger.mounted) {
          messenger.showFlixieToast(FlixieToast(
              type: FlixieToastType.error,
              content: const Text('Couldn’t undo all list changes'),
              action: SnackBarAction(label: 'Retry', onPressed: undo)));
        }
      } finally {
        undoRunning = false;
      }
    }

    Navigator.pop(context, true);
    messenger.showFlixieToast(FlixieToast(
      type: FlixieToastType.success,
      content: const Text('Lists updated'),
      action: restoreMembership.isEmpty && removeMembership.isEmpty
          ? null
          : SnackBarAction(label: 'Undo', onPressed: undo),
    ));
  }

  Future<void> _openCreateListSheet() async {
    final provider = context.read<MovieListsProvider>();
    final created = await showModalBottomSheet<MovieList>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.colors.background,
      builder: (_) => ChangeNotifierProvider<MovieListsProvider>.value(
        value: provider,
        child: const CreateMediaListSheet(),
      ),
    );
    if (!mounted || created == null) return;
    setState(() {
      _selectedListIds.add(created.id);
    });
  }
}

String _listCountLabel(MovieList list) {
  final movies = list.movieCount ?? 0;
  final shows = list.showCount ?? 0;
  final total = list.itemCount ?? movies + shows;
  if (movies > 0 && shows > 0) {
    return '$total items · $movies films · $shows shows';
  }
  if (movies > 0) return '$movies films';
  if (shows > 0) return '$shows shows';
  return '$total items';
}
