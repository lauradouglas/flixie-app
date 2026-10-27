import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../authentication/data/setup_service.dart';
import '../../../guest/presentation/guest_access.dart';
import '../../data/guest_watchlist_store.dart';

class GuestWatchlistPage extends StatefulWidget {
  const GuestWatchlistPage({super.key});
  @override
  State<GuestWatchlistPage> createState() => _GuestWatchlistPageState();
}

class _GuestWatchlistPageState extends State<GuestWatchlistPage> {
  late Future<List<SetupTitle>> _picks = GuestWatchlistStore.instance.read();
  String? _error;
  @override
  void initState() {
    super.initState();
    GuestWatchlistStore.instance.addListener(_reload);
  }

  void _reload() {
    if (mounted) {
      setState(() {
        _picks = GuestWatchlistStore.instance.read();
      });
    }
  }

  @override
  void dispose() {
    GuestWatchlistStore.instance.removeListener(_reload);
    super.dispose();
  }

  Future<void> _remove(SetupTitle pick) async {
    try {
      await GuestWatchlistStore.instance.remove(pick.key);
      if (mounted) {
        setState(() {
          _error = null;
          _picks = GuestWatchlistStore.instance.read();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Couldn’t remove that pick. Try again.');
      }
    }
  }

  void _keep(String method) {
    GuestAccess.clear();
    GuestAccess.action = 'guest-watchlist';
    GuestAccess.destination = '/guest-watchlist';
    GuestAccess.awaitingAccount = true;
    context.go('/auth/$method');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(title: const Text('Your watchlist')),
        body: FutureBuilder<List<SetupTitle>>(
            future: _picks,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                    child: TextButton(
                        onPressed: _reload,
                        child: const Text('Couldn’t load your picks. Retry')));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final picks = snapshot.data!;
              return ListView(padding: const EdgeInsets.all(24), children: [
                Text(
                    picks.isEmpty
                        ? 'What’s on your someday list?'
                        : 'Already feels like you.',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                const Text('Keep adding films and shows. No account needed.'),
                const SizedBox(height: 16),
                if (_error != null) Text(_error!),
                if (picks.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                      'Saved on this device. Want to keep them across devices?'),
                  OutlinedButton(
                      onPressed: () => _keep('signup'),
                      child: const Text('Create account & keep my picks')),
                  TextButton(
                      onPressed: () => _keep('login'),
                      child: const Text('Already have an account? Sign in')),
                ],
                const Text('Clearing app data removes device-only picks.',
                    style: TextStyle(fontSize: 13)),
                const SizedBox(height: 16),
                _posters(picks),
                TextButton(
                    onPressed: () => context.go('/search'),
                    child: const Text('Find more to watch')),
              ]);
            }),
      );
  Widget _posters(List<SetupTitle> picks) =>
      LayoutBuilder(builder: (context, box) {
        final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.5;
        final columns = largeText
            ? 1
            : box.maxWidth >= 700
                ? 4
                : 2;
        final width = (box.maxWidth - 16 * (columns - 1)) / columns;
        return Wrap(spacing: 16, runSpacing: 20, children: [
          for (final pick in picks)
            SizedBox(
                width: width,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                          onTap: () => _open(pick),
                          child: Semantics(
                              label: 'View ${pick.name}',
                              button: true,
                              child: SizedBox(
                                  width: width,
                                  height: largeText ? 180 : width * 1.5,
                                  child: pick.poster == null
                                      ? const Icon(Icons.movie_outlined)
                                      : Image.network(
                                          pick.poster!.startsWith('http')
                                              ? pick.poster!
                                              : 'https://image.tmdb.org/t/p/w342${pick.poster}',
                                          fit: BoxFit.contain,
                                          excludeFromSemantics: true,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                                  Icons.movie_outlined))))),
                      const SizedBox(height: 8),
                      TextButton(
                          onPressed: () => _open(pick),
                          style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              alignment: Alignment.centerLeft),
                          child: Text(pick.name)),
                      Row(children: [
                        Expanded(child: Text(pick.isShow ? 'TV show' : 'Film')),
                        IconButton(
                            tooltip: 'Remove ${pick.name}',
                            onPressed: () => _remove(pick),
                            icon: const Icon(Icons.bookmark_remove_outlined)),
                      ]),
                    ])),
        ]);
      });
  Future<void> _open(SetupTitle pick) async {
    await context.push('/${pick.isShow ? 'shows' : 'movies'}/${pick.id}');
    if (mounted) _reload();
  }
}
