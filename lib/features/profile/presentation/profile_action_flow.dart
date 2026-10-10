import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/models/continue_watching_show.dart';
import 'package:flixie_app/features/settings/presentation/widgets/watch_providers_sheet.dart';
import 'widgets/ratings_section.dart';
import 'controllers/profile_controller.dart';

/// Profile sheets and delayed saves belong to the viewer that opened them.
class ProfileActionFlow {
  ProfileActionFlow({required this.context, required ProfileController data})
      : _data = data,
        _generation = data.generation,
        _viewer = data.auth.dbUser?.id;
  final BuildContext context;
  final ProfileController _data;
  final int _generation;
  final String? _viewer;
  bool get mounted => context.mounted && _data.owns(_generation, _viewer);
  Future<void> removeContinueWatching(ContinueWatchingShow show) async {
    if (!context.mounted || !mounted) return;
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) return;
    final index = _data.continueWatching.indexWhere(
      (item) => item.showId == show.showId,
    );
    if (index < 0) return;

    _data.change(() => _data.continueWatching = List.of(_data.continueWatching)
      ..removeAt(index));
    var undone = false;
    final notice = ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${show.name} removed from Continue watching'),
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            undone = true;
            if (mounted) {
              _data.change(() => _data
                  .continueWatching = List.of(_data.continueWatching)
                ..insert(index.clamp(0, _data.continueWatching.length), show));
            }
          }),
    ));
    await notice.closed;
    if (undone || !mounted) return;
    try {
      await _data.service.dismissContinueWatching(userId, show.showId);
      if (!context.mounted || !mounted) return;
    } catch (_) {
      if (!context.mounted || !mounted) return;
      _data.change(() {
        final restoredIndex = index.clamp(0, _data.continueWatching.length);
        _data.continueWatching = List.of(_data.continueWatching)
          ..insert(restoredIndex, show);
      });
      ScaffoldMessenger.of(context).showFlixieToast(
        FlixieToast(
            type: FlixieToastType.error,
            content: const Text('Could not remove that show right now')),
      );
    }
  }

  Future<void> openWatchProviders() async {
    if (!context.mounted || !mounted) return;
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) return;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WatchProvidersSheet(userId: userId),
    );
    if (context.mounted && mounted) await _data.loadProfileExtras();
  }

  void openRatings() {
    if (!mounted) return;
    unawaited(_data.loadRatings());
    showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (context) => ListenableBuilder(
            listenable: _data,
            builder: (context, _) {
              if (!mounted) return const SizedBox.shrink();
              return _data.ratingsLoading
                  ? SizedBox(
                      height: MediaQuery.sizeOf(context).height * .75,
                      child: const SingleChildScrollView(
                          padding: EdgeInsets.all(20),
                          child: ContentPlaceholder(label: 'Loading ratings')))
                  : AllRatingsSheet(ratings: _data.ratings);
            }));
  }
}
