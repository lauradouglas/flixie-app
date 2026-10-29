import 'package:cached_network_image/cached_network_image.dart';
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
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, bounds) {
        return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: bounds.maxHeight),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                  child: Row(children: [
                    Expanded(
                        child: Text(
                            'Rank favourite ${widget.shows ? 'shows' : 'movies'}',
                            style: Theme.of(context).textTheme.titleLarge)),
                    IconButton(
                        onPressed: saving ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close)),
                  ])),
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Your favourites, in your order.',
                                style: TextStyle(fontSize: 14)),
                            const SizedBox(height: 2),
                            Text('Drag a handle or use the arrows.',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: context.colors.primaryText)),
                          ]))),
              Flexible(
                  fit: FlexFit.loose,
                  child: ReorderableListView.builder(
                      shrinkWrap: true,
                      buildDefaultDragHandles: false,
                      itemCount: widget.items.length,
                      onReorderItem: (from, to) {
                        if (!saving) move(from, to);
                      },
                      itemBuilder: (context, index) {
                        final item = widget.items[index];
                        final media =
                            item[widget.shows ? 'show' : 'movie'] as Map? ??
                                item;
                        final title =
                            '${media['title'] ?? media['name'] ?? 'Untitled'}';
                        final poster = (media['posterPath'] ??
                            media['poster_path']) as String?;
                        final date =
                            '${media['releaseDate'] ?? media['firstAirDate'] ?? media['first_air_date'] ?? ''}';
                        final year =
                            date.length >= 4 ? date.substring(0, 4) : '';
                        Widget arrow(bool up) => IconButton(
                            tooltip: up ? 'Move up' : 'Move down',
                            onPressed: saving ||
                                    (up
                                        ? index == 0
                                        : index == widget.items.length - 1)
                                ? null
                                : () => move(index, index + (up ? -1 : 1)),
                            style: IconButton.styleFrom(
                                minimumSize: const Size(44, 44),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                foregroundColor: context.colors.white,
                                side: BorderSide(
                                    color: context.colors.tabBarBorder),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8))),
                            icon: Icon(
                                up ? Icons.arrow_upward : Icons.arrow_downward,
                                size: 18));
                        return Padding(
                          key: ValueKey(item['id']),
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                          child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                  color: context.colors.surfaceElevated
                                      .withValues(alpha: .65),
                                  borderRadius: BorderRadius.circular(12)),
                              child: LayoutBuilder(builder: (context, box) {
                                final narrow = box.maxWidth < 270 ||
                                    MediaQuery.textScalerOf(context).scale(1) >
                                        1.3;
                                final controls = Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      arrow(true),
                                      const SizedBox(width: 6),
                                      arrow(false)
                                    ]);
                                return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                          width: 20,
                                          child: Text('${index + 1}',
                                              style: TextStyle(
                                                  color: context
                                                      .colors.primaryText,
                                                  fontSize: 13,
                                                  fontWeight:
                                                      FontWeight.w900))),
                                      const SizedBox(width: 8),
                                      ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          child: SizedBox(
                                              width: 40,
                                              height: 60,
                                              child: poster == null ||
                                                      poster.isEmpty
                                                  ? Icon(Icons.movie_outlined,
                                                      color:
                                                          context.colors.light)
                                                  : CachedNetworkImage(
                                                      imageUrl: poster
                                                              .startsWith(
                                                                  'http')
                                                          ? poster
                                                          : 'https://image.tmdb.org/t/p/w185$poster',
                                                      fit: BoxFit.contain,
                                                      errorWidget: (_, __,
                                                              ___) =>
                                                          const Icon(Icons
                                                              .movie_outlined)))),
                                      const SizedBox(width: 10),
                                      Expanded(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                            Text(title,
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            if (year.isNotEmpty)
                                              Text(year,
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: context
                                                          .colors.light)),
                                            if (narrow) controls,
                                          ])),
                                      if (!narrow) controls,
                                      ReorderableDragStartListener(
                                          index: index,
                                          enabled: !saving,
                                          child: Semantics(
                                              label: 'Drag to reorder $title',
                                              child: SizedBox(
                                                  width: 32,
                                                  height: 44,
                                                  child: Align(
                                                      alignment:
                                                          Alignment.centerRight,
                                                      child: Icon(
                                                          Icons.drag_handle,
                                                          size: 20,
                                                          color: context.colors
                                                              .light))))),
                                    ]);
                              })),
                        );
                      })),
              if (error != null)
                Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(error!,
                        style: TextStyle(color: context.colors.danger))),
              SafeArea(
                  top: false,
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                              onPressed: saving ? null : save,
                              child:
                                  Text(saving ? 'Saving…' : 'Save ranking'))))),
            ]));
      });
}
