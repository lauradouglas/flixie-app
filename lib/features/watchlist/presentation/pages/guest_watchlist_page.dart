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
                        : 'Good picks. Keep them together.',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                const Text(
                    'Your picks are saved on this device. Create an account to keep them in your Flixie watchlist. Clearing app data will remove device-only picks.'),
                if (_error != null) Text(_error!),
                for (final pick in picks)
                  ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      leading: SizedBox(
                          width: 44,
                          height: 66,
                          child: pick.poster == null
                              ? const Icon(Icons.movie_outlined)
                              : Image.network(
                                  pick.poster!.startsWith('http')
                                      ? pick.poster!
                                      : 'https://image.tmdb.org/t/p/w185${pick.poster}',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.movie_outlined))),
                      title: Text(pick.name),
                      subtitle: Text(pick.isShow ? 'TV show' : 'Film'),
                      onTap: () => context
                              .push(
                                  '/${pick.isShow ? 'shows' : 'movies'}/${pick.id}')
                              .then((_) {
                            if (mounted) {
                              _reload();
                            }
                          }),
                      trailing: IconButton(
                          tooltip: 'Remove ${pick.name}',
                          onPressed: () => _remove(pick),
                          icon: const Icon(Icons.bookmark_remove_outlined))),
                const SizedBox(height: 16),
                if (picks.isNotEmpty) ...[
                  FilledButton(
                      onPressed: () => _keep('signup'),
                      child: const Text('Create account & keep my picks')),
                  TextButton(
                      onPressed: () => _keep('login'),
                      child: const Text('Already have an account? Sign in')),
                ],
                TextButton(
                    onPressed: () => context.push('/search'),
                    child: const Text('Find more to watch')),
              ]);
            }),
      );
}
