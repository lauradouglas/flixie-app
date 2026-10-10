import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/person.dart';
import '../../person_filmography_selection.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';

class PersonCreditStats extends StatelessWidget {
  const PersonCreditStats(
      {super.key, required this.credits, required this.allCredits});
  final PersonCredits credits;
  final List<PersonFilmCredit> allCredits;
  @override
  Widget build(BuildContext context) {
    final topRated = allCredits.where((c) => c.voteCount >= 25).toList()
      ..sort((a, b) => b.voteAverage.compareTo(a.voteAverage));
    final knownForCount = credits.knownForCredits.length;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.tabBarBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _statTile(
              context,
              'Credits',
              allCredits.isEmpty ? '-' : '${allCredits.length}',
              Icons.local_movies_outlined,
            ),
          ),
          const _PersonStatDivider(),
          Expanded(
            child: _statTile(
              context,
              'Known for',
              knownForCount == 0 ? '-' : '$knownForCount',
              Icons.auto_awesome_outlined,
            ),
          ),
          const _PersonStatDivider(),
          Expanded(
            child: _statTile(
              context,
              'Top title',
              (topRated.isEmpty ||
                      hideMovieRatings(context, topRated.first.id,
                          isShow: !topRated.first.isMovie))
                  ? '-'
                  : topRated.first.voteAverage.toStringAsFixed(1),
              Icons.star_border_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile(
      BuildContext context, String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: const BoxDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: FlixieColors.primary, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.colors.medium, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _PersonStatDivider extends StatelessWidget {
  const _PersonStatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 42,
      color: context.colors.tabBarBorder,
    );
  }
}
