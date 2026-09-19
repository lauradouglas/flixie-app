import 'package:flixie_app/core/widgets/flixie_toast.dart';
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
  return message.contains('favourite up to 10') ||
      message.contains('favourite up to 25') ||
      message.contains('maximum number of favorites') ||
      message.contains('max favorites reached');
}

Future<void> showFavouriteLimitPrompt(
  BuildContext context, {
  required FavouriteLimitType type,
  Future<void> Function()? onSpaceMade,
}) async {
  final removed =
      await showFavouriteManagerSheet(context, type: type, replacing: true);
  if (removed && context.mounted) await onSpaceMade?.call();
}

Future<bool> showFavouriteManagerSheet(
  BuildContext context, {
  required FavouriteLimitType type,
  bool replacing = false,
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
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _FavouriteManagerSheet(type: type, items: items, replacing: replacing),
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

  ScaffoldMessenger.of(context).showFlixieToast(
    FlixieToast(
      type: FlixieToastType.success,
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
  const _FavouriteManagerSheet(
      {required this.type, required this.items, this.replacing = false});
  final bool replacing;

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
        color: context.colors.background,
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
                  color: context.colors.medium.withValues(alpha: .55),
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
                            widget.replacing
                                ? 'Which favourite should make room?'
                                : 'Manage favourite $label',
                            style: TextStyle(
                              color: context.colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.replacing
                                ? 'Keep your top 10 $label. Choose ${widget.items.length > 10 ? widget.items.length - 9 : 1} to remove before adding this one.'
                                : '${widget.items.length} of 10 · Tap cards to remove',
                            style: TextStyle(
                              color: context.colors.medium,
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
                                if (marked) {
                                  _markedForRemoval.remove(item.id);
                                } else {
                                  if (widget.replacing &&
                                      widget.items.length <= 10) {
                                    _markedForRemoval.clear();
                                  }
                                  _markedForRemoval.add(item.id);
                                }
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
                    style: TextStyle(color: context.colors.danger),
                    textAlign: TextAlign.center,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _markedForRemoval.isEmpty ||
                            (widget.replacing &&
                                widget.items.length -
                                        _markedForRemoval.length >=
                                    10) ||
                            _saving
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
                          : widget.replacing
                              ? 'Remove selected and continue'
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
          color: context.colors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: markedForRemoval
                ? context.colors.danger
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
                      ? ColoredBox(
                          color: context.colors.surface,
                          child: Icon(Icons.movie_outlined,
                              color: context.colors.medium),
                        )
                      : CachedNetworkImage(
                          imageUrl: item.posterUrl!,
                          fit: BoxFit.cover,
                        ),
                  if (markedForRemoval)
                    ColoredBox(
                      color: context.colors.danger.withValues(alpha: .32),
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
                            ? context.colors.danger
                            : context.colors.background.withValues(alpha: .88),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        markedForRemoval
                            ? Icons.remove_rounded
                            : Icons.favorite_rounded,
                        size: 17,
                        color: markedForRemoval
                            ? context.colors.white
                            : context.colors.tertiary,
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
                style: TextStyle(
                  color: context.colors.white,
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
