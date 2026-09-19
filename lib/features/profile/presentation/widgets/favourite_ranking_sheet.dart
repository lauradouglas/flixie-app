import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/models/favorite_movie.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';

Future<void> showFavouriteRankingSheet(BuildContext context,
    {required bool shows}) async {
  final user = context.read<AuthProvider>().dbUser;
  if (user == null) return;
  final items = shows
      ? (user.favoriteShows ?? [])
          .whereType<Map>()
          .where((e) => e['removed'] != true)
          .map((e) => Map<String, dynamic>.from(e))
          .toList()
      : (user.favoriteMovies ?? [])
          .where((e) => e.removed != true)
          .map((e) => e.toJson())
          .toList();
  items.sort((a, b) => ((a['rank'] as num?)?.toInt() ?? 999)
      .compareTo((b['rank'] as num?)?.toInt() ?? 999));
  final saved = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => _RankingSheet(items: items, shows: shows));
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(FlixieToast(
      content: Text('Favourite ${shows ? 'shows' : 'movies'} ranking saved'),
      type: FlixieToastType.success,
    ));
  }
}

class _RankingSheet extends StatefulWidget {
  const _RankingSheet({required this.items, required this.shows});
  final List<Map<String, dynamic>> items;
  final bool shows;
  @override
  State<_RankingSheet> createState() => _RankingSheetState();
}

class _RankingSheetState extends State<_RankingSheet> {
  bool saving = false;
  String? error;
  void move(int from, int to) => setState(() {
        final item = widget.items.removeAt(from);
        widget.items.insert(to, item);
      });
  Future<void> save() async {
    setState(() {
      saving = true;
      error = null;
    });
    final auth = context.read<AuthProvider>();
    final user = auth.dbUser;
    if (user == null) return;
    try {
      final kind = widget.shows ? 'show' : 'movie';
      final result = await ApiClient.put(
          '/users/${user.id}/$kind/favorites/update-rankings',
          body: {
            widget.shows ? 'shows' : 'movies':
                widget.items.map((e) => {'id': e['id']}).toList()
          });
      if (!mounted) return;
      if (widget.shows) {
        auth.updateUserList(favoriteShows: List<dynamic>.from(result as List));
      } else {
        auth.updateUserList(
            favoriteMovies: (result as List)
                .map(
                    (e) => FavoriteMovie.fromJson(Map<String, dynamic>.from(e)))
                .toList());
      }
      auth.markActivityChanged();
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = 'Couldn’t save your order. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * .8,
      child: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(children: [
              Expanded(
                  child: Text(
                      'Rank favourite ${widget.shows ? 'shows' : 'movies'}',
                      style: Theme.of(context).textTheme.titleLarge)),
              IconButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ])),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
                'Your number one goes at the top. Drag to reorder or use the arrows.')),
        Expanded(
            child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: widget.items.length,
                onReorderItem: (from, to) {
                  if (!saving) move(from, to);
                },
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  final media =
                      item[widget.shows ? 'show' : 'movie'] as Map? ?? item;
                  return ListTile(
                      key: ValueKey(item['id']),
                      leading: Text('${index + 1}',
                          style: TextStyle(
                              color: context.colors.primaryText,
                              fontWeight: FontWeight.bold)),
                      title: Text(
                          '${media['title'] ?? media['name'] ?? 'Untitled'}'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                            tooltip: 'Move up',
                            onPressed: saving || index == 0
                                ? null
                                : () => move(index, index - 1),
                            icon: const Icon(Icons.arrow_upward, size: 20)),
                        IconButton(
                            tooltip: 'Move down',
                            onPressed:
                                saving || index == widget.items.length - 1
                                    ? null
                                    : () => move(index, index + 1),
                            icon: const Icon(Icons.arrow_downward, size: 20)),
                        ReorderableDragStartListener(
                            index: index,
                            enabled: !saving,
                            child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.drag_handle))),
                      ]));
                })),
        if (error != null)
          Padding(
              padding: const EdgeInsets.all(12),
              child:
                  Text(error!, style: TextStyle(color: context.colors.danger))),
        SafeArea(
            top: false,
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                        onPressed: saving ? null : save,
                        child: Text(saving ? 'Saving…' : 'Save ranking'))))),
      ]));
}
