import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../app/theme/app_theme.dart';
import '../../data/taste_setup_store.dart';

/// Only appears after a saved action. Dismissal never blocks Profile access.
class TasteHomeCard extends StatefulWidget {
  const TasteHomeCard({super.key, this.store = const TasteSetupStore()});
  final TasteSetupStore store;
  @override
  State<TasteHomeCard> createState() => _TasteHomeCardState();
}

class _TasteHomeCardState extends State<TasteHomeCard> {
  @override
  void initState() {
    super.initState();
    TasteSetupStore.changes.addListener(_progressChanged);
  }

  void _progressChanged() {
    if (mounted) {
      setState(() {
        _activity = -1;
      });
    }
  }

  @override
  void dispose() {
    TasteSetupStore.changes.removeListener(_progressChanged);
    super.dispose();
  }

  String? _owner;
  bool _dismissed = false;
  Future<bool>? _visible;
  int _activity = -1;
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.dbUser;
    if (user == null || !user.completedSetup) return const SizedBox.shrink();
    if (_owner != user.id || _activity != auth.activityVersion) {
      if (_owner != user.id) _dismissed = false;
      _owner = user.id;
      _activity = auth.activityVersion;
      final hasPicks =
          (user.movieWatchlist?.any((m) => m.removed != true) ?? false) ||
              (user.favoriteMovies?.any((m) => m.removed != true) ?? false) ||
              (user.watchedMovies?.any((m) => m.removed != true) ?? false) ||
              (user.showWatchlist?.isNotEmpty ?? false) ||
              (user.watchedShows?.isNotEmpty ?? false);
      _visible = Future.wait(
              [widget.store.hidden(user.id), widget.store.eligible(user.id)])
          .then((s) => !s[0] && (hasPicks || s[1]));
    }
    if (_dismissed) return const SizedBox.shrink();
    return FutureBuilder<bool>(
        future: _visible,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done ||
              snapshot.data != true) {
            return const SizedBox.shrink();
          }
          return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                    color: context.colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('More your kind of thing',
                              style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 10),
                          const Text(
                              'Your film ratings and favourites help shape your recommendations. Give Flixie a few clues.'),
                          const SizedBox(height: 16),
                          FilledButton(
                              onPressed: () async {
                                await context.push('/build-your-taste');
                                if (mounted) {
                                  setState(() {
                                    _activity = -1;
                                  });
                                }
                              },
                              child: const Text('Build my taste')),
                          TextButton(
                              onPressed: () async {
                                final id = user.id;
                                setState(() => _dismissed = true);
                                try {
                                  await widget.store.hide(id);
                                } catch (_) {
                                  /* Keep the current-session dismissal. */
                                }
                              },
                              child: const Text('Maybe later')),
                        ])),
              ));
        });
  }
}
