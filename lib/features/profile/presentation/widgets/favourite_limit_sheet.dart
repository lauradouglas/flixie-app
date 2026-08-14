import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/utils/favourite_limits.dart';
import 'package:flixie_app/features/movies/data/show_service.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/models/favorite_movie.dart';

enum FavouriteLimitType { movie, show }

bool isFavouriteLimitError(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains('favourite up to 25') ||
      message.contains('maximum number of favorites') ||
      message.contains('max favorites reached');
}

void showFavouriteLimitPrompt(
  BuildContext context, {
  required FavouriteLimitType type,
  Future<void> Function()? onSpaceMade,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final label = type == FavouriteLimitType.movie ? 'movies' : 'shows';
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
      content: Row(
        children: [
          const Icon(Icons.favorite_rounded,
              color: FlixieColors.tertiary, size: 19),
          const SizedBox(width: 9),
          Expanded(child: Text('You already have 25 favourite $label.')),
          const SizedBox(width: 8),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: FlixieColors.white,
              backgroundColor: FlixieColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(0, 38),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
            onPressed: () async {
              messenger.hideCurrentSnackBar();
              final removed =
                  await showFavouriteManagerSheet(context, type: type);
              if (removed && context.mounted) await onSpaceMade?.call();
            },
            child: const Text('Manage'),
          ),
        ],
      ),
    ),
  );
}

Future<bool> showFavouriteManagerSheet(
  BuildContext context, {
  required FavouriteLimitType type,
}) async {
  final auth = context.read<AuthProvider>();
  final user = auth.dbUser;
  if (user == null) return false;

  final items = type == FavouriteLimitType.movie
      ? (user.favoriteMovies ?? const <FavoriteMovie>[])
          .where((item) => item.removed != true)
          .map(_FavouriteManagerItem.fromMovie)
          .toList(growable: false)
      : (user.favoriteShows ?? const <dynamic>[])
          .where(isActiveFavouriteShow)
          .map(_FavouriteManagerItem.fromShow)
          .where((item) => item.id > 0)
          .toList(growable: false);

  final removedIds = await showModalBottomSheet<Set<int>>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FavouriteManagerSheet(type: type, items: items),
  );
  if (removedIds == null || removedIds.isEmpty || !context.mounted) {
    return false;
  }

  if (type == FavouriteLimitType.movie) {
    auth.updateUserList(
      favoriteMovies: (user.favoriteMovies ?? const <FavoriteMovie>[])
          .where((item) => !removedIds.contains(item.movieId))
          .toList(growable: false),
    );
  } else {
    auth.updateUserList(
      favoriteShows: (user.favoriteShows ?? const <dynamic>[])
          .where((item) => !removedIds.contains(_showId(item)))
          .toList(growable: false),
    );
  }
  auth.markActivityChanged();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        removedIds.length == 1
            ? '1 favourite removed'
            : '${removedIds.length} favourites removed',
      ),
      duration: const Duration(seconds: 3),
    ),
  );
  return true;
}

class _FavouriteManagerSheet extends StatefulWidget {
  const _FavouriteManagerSheet({required this.type, required this.items});

  final FavouriteLimitType type;
  final List<_FavouriteManagerItem> items;

  @override
  State<_FavouriteManagerSheet> createState() => _FavouriteManagerSheetState();
}

class _FavouriteManagerSheetState extends State<_FavouriteManagerSheet> {
  final Set<int> _markedForRemoval = {};
  bool _saving = false;
  String? _error;

  Future<void> _removeSelected() async {
    if (_saving || _markedForRemoval.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) return;
    final removed = <int>{};
    for (final id in _markedForRemoval) {
      try {
        if (widget.type == FavouriteLimitType.movie) {
          await UserService.removeFromFavorites(userId, id);
        } else {
          await ShowService.removeFromFavourites(userId, id);
        }
        removed.add(id);
      } catch (_) {}
    }
    if (!mounted) return;
    if (removed.isNotEmpty) {
      Navigator.of(context).pop(removed);
      return;
    }
    setState(() {
      _saving = false;
      _error = 'Could not remove those favourites. Please try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.type == FavouriteLimitType.movie ? 'movies' : 'shows';
    return DraggableScrollableSheet(
      initialChildSize: .82,
      minChildSize: .55,
      maxChildSize: .94,
      expand: false,
      builder: (context, scrollController) => Material(
        color: FlixieColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: FlixieColors.medium.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 10, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manage favourite $label',
                            style: const TextStyle(
                              color: FlixieColors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${widget.items.length} of ${widget.type == FavouriteLimitType.movie ? maxFavouriteMovies : maxFavouriteShows} · Tap cards to remove',
                            style: const TextStyle(
                              color: FlixieColors.medium,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 12,
                    childAspectRatio: .59,
                  ),
                  itemCount: widget.items.length,
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    final marked = _markedForRemoval.contains(item.id);
                    return _FavouriteManagerCard(
                      item: item,
                      markedForRemoval: marked,
                      onTap: _saving
                          ? null
                          : () => setState(() {
                                marked
                                    ? _markedForRemoval.remove(item.id)
                                    : _markedForRemoval.add(item.id);
                              }),
                    );
                  },
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: FlixieColors.danger),
                    textAlign: TextAlign.center,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _markedForRemoval.isEmpty || _saving
                        ? null
                        : _removeSelected,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.remove_circle_outline_rounded),
                    label: Text(
                      _markedForRemoval.isEmpty
                          ? 'Select favourites to remove'
                          : 'Remove ${_markedForRemoval.length} selected',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavouriteManagerCard extends StatelessWidget {
  const _FavouriteManagerCard({
    required this.item,
    required this.markedForRemoval,
    required this.onTap,
  });

  final _FavouriteManagerItem item;
  final bool markedForRemoval;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: FlixieColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: markedForRemoval
                ? FlixieColors.danger
                : FlixieColors.primary.withValues(alpha: .22),
            width: markedForRemoval ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  item.posterUrl == null
                      ? const ColoredBox(
                          color: FlixieColors.surface,
                          child: Icon(Icons.movie_outlined,
                              color: FlixieColors.medium),
                        )
                      : CachedNetworkImage(
                          imageUrl: item.posterUrl!,
                          fit: BoxFit.cover,
                        ),
                  if (markedForRemoval)
                    ColoredBox(
                      color: FlixieColors.danger.withValues(alpha: .32),
                    ),
                  Positioned(
                    right: 7,
                    top: 7,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: markedForRemoval
                            ? FlixieColors.danger
                            : FlixieColors.background.withValues(alpha: .88),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        markedForRemoval
                            ? Icons.remove_rounded
                            : Icons.favorite_rounded,
                        size: 17,
                        color: markedForRemoval
                            ? FlixieColors.white
                            : FlixieColors.tertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(9),
              child: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: FlixieColors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavouriteManagerItem {
  const _FavouriteManagerItem({
    required this.id,
    required this.title,
    required this.posterUrl,
  });

  factory _FavouriteManagerItem.fromMovie(FavoriteMovie favorite) {
    final movie = favorite.movie ?? const <String, dynamic>{};
    return _FavouriteManagerItem(
      id: favorite.movieId,
      title: movie['title']?.toString() ?? 'Movie',
      posterUrl: _posterUrl(movie['posterPath']),
    );
  }

  factory _FavouriteManagerItem.fromShow(dynamic raw) {
    final outer = raw is Map ? raw : const <dynamic, dynamic>{};
    final show = outer['show'] is Map ? outer['show'] as Map : outer;
    return _FavouriteManagerItem(
      id: _showId(raw) ?? 0,
      title: (show['title'] ?? show['name'] ?? 'Show').toString(),
      posterUrl: _posterUrl(show['posterPath']),
    );
  }

  final int id;
  final String title;
  final String? posterUrl;
}

int? _showId(dynamic raw) {
  if (raw is int) return raw;
  if (raw is String) return int.tryParse(raw);
  if (raw is Map) {
    final nested = raw['show'];
    final value = raw['showId'] ?? (nested is Map ? nested['id'] : raw['id']);
    return value is int ? value : int.tryParse(value?.toString() ?? '');
  }
  return null;
}

String? _posterUrl(dynamic raw) {
  final path = raw?.toString().trim();
  if (path == null || path.isEmpty) return null;
  return path.startsWith('http')
      ? path
      : 'https://image.tmdb.org/t/p/w342$path';
}
