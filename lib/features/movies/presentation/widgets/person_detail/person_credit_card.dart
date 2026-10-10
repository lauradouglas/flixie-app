import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/person.dart';
import '../../person_filmography_selection.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';

class PersonKnownForCard extends StatelessWidget {
  const PersonKnownForCard(
      {super.key,
      required this.item,
      required this.library,
      required this.onOpen,
      this.role});
  final PersonCreditItem item;
  final PersonLibraryStatus library;
  final VoidCallback onOpen;
  final String? role;
  @override
  Widget build(BuildContext context) {
    const posterBase = 'https://image.tmdb.org/t/p/w342';
    final statusBadges = _posterStatusBadges(context, item);

    return GestureDetector(
      onTap: onOpen,
      child: SizedBox(
        width: 126,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: item.posterPath != null
                        ? CachedNetworkImage(
                            imageUrl: '$posterBase${item.posterPath}',
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _posterFallback(
                              context,
                            ),
                          )
                        : _posterFallback(
                            context,
                          ),
                  ),
                ),
                if (statusBadges.isNotEmpty)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: statusBadges,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.colors.light,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
            if (_year(item.releaseDate) != null) ...[
              const SizedBox(height: 3),
              Text(
                '${_year(item.releaseDate)!} · ${item.type == 'tv' ? 'TV' : 'Movie'}',
                style: TextStyle(color: context.colors.medium, fontSize: 11),
              ),
            ],
            if (role != null) ...[
              const SizedBox(height: 3),
              Text(
                role!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.colors.primaryTint,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _posterStatusBadges(
      BuildContext context, PersonCreditItem item) {
    if (item.type != 'movie') return const [];
    final movieId = item.id;
    return [
      if (library.favourites.contains(movieId))
        _posterStatusBadge(
          context,
          icon: Icons.favorite_rounded,
          label: 'Favourite',
          color: context.colors.danger,
        ),
      if (library.watchlist.contains(movieId))
        _posterStatusBadge(
          context,
          icon: Icons.bookmark_rounded,
          label: 'On watchlist',
          color: context.colors.warning,
        ),
      if (library.watched.contains(movieId))
        _posterStatusBadge(
          context,
          icon: Icons.check_rounded,
          label: 'Watched',
          color: context.colors.success,
        ),
    ];
  }
}

class PersonCreditRow extends StatelessWidget {
  const PersonCreditRow(
      {super.key,
      required this.item,
      required this.library,
      required this.onOpen});
  final PersonFilmCredit item;
  final PersonLibraryStatus library;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    const thumbBase = 'https://image.tmdb.org/t/p/w185';
    final statusIcons = <Widget>[
      if (item.isMovie && library.watched.contains(item.id))
        Tooltip(
          message: 'Watched',
          child: Icon(
            Icons.check_circle_rounded,
            color: context.colors.success,
            size: 15,
          ),
        ),
      if (item.isMovie && library.watchlist.contains(item.id))
        Tooltip(
          message: 'Watchlist',
          child: Icon(
            Icons.bookmark_rounded,
            color: context.colors.warning,
            size: 15,
          ),
        ),
      if (item.isMovie && library.favourites.contains(item.id))
        Tooltip(
          message: 'Favourite',
          child: Icon(
            Icons.favorite_rounded,
            color: context.colors.danger,
            size: 15,
          ),
        ),
    ];

    return GestureDetector(
      onTap: onOpen,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 40,
                height: 60,
                child: item.posterPath != null
                    ? CachedNetworkImage(
                        imageUrl: '$thumbBase${item.posterPath}',
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _posterFallback(
                          context,
                        ),
                      )
                    : _posterFallback(
                        context,
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      color: context.colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    if (item.year != null)
                      Text('${item.year!} · ${item.isMovie ? 'Movie' : 'TV'}',
                          style: TextStyle(
                              color: context.colors.medium, fontSize: 11)),
                    ...statusIcons,
                  ]),
                  const SizedBox(height: 2),
                  Text(
                    item.roleLabel,
                    style: TextStyle(
                      color: context.colors.primaryTint,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (item.voteAverage > 0 &&
                !hideMovieRatings(context, item.id, isShow: !item.isMovie)) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.star_rounded,
                color: context.colors.warning,
                size: 16,
              ),
              const SizedBox(width: 3),
              Text(
                item.voteAverage.toStringAsFixed(1),
                style: TextStyle(
                  color: context.colors.warning,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                color: context.colors.medium, size: 20),
          ],
        ),
      ),
    );
  }
}

Widget _posterStatusBadge(
  BuildContext context, {
  required IconData icon,
  required String label,
  required Color color,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: context.colors.background.withValues(alpha: 0.92),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 5),
            ],
          ),
          child: Icon(icon, color: color, size: 17),
        ),
      ),
    ),
  );
}

Widget _posterFallback(
  BuildContext context,
) {
  return Container(
    color: context.colors.surfaceElevated,
    child: Icon(Icons.movie_outlined,
        color: context.colors.medium.withValues(alpha: 0.55), size: 24),
  );
}

String? _year(String? raw) {
  if (raw == null || raw.length < 4) return null;
  return raw.substring(0, 4);
}
